// lib/providers/recipe_provider.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/recipe_category.dart';
import '../models/subscription.dart'; // Import the new subscription model
import '../services/recipe_service.dart';
import '../main.dart'; // Import for navigatorKey
import '../providers/subscription_provider.dart'; // Import for subscription provider
import '../widgets/recipes/generation_limit_dialog.dart'; // Import for the limit dialog
import '../config/sentry_config.dart'; // Import the Sentry config

class RecipeProvider with ChangeNotifier {
  Recipe? _currentRecipe;
  Recipe? _partialRecipe;  // For storing partial recipe
  List<Recipe> _userRecipes = [];
  List<Recipe> _favoriteRecipes = [];
  List<Recipe> _trendingRecipes = [];
  List<Recipe> _discoverRecipes = [];
  List<RecipeCategory> _categories = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreRecipes = true;
  int _currentPage = 0;
  String? _error;

  // Added for queue-based generation status
  bool _isQueueActive = false;
  double _generationProgress = 0.0;
  Timer? _pollingTimer;  // Timer for polling recipe status
  int _pollingErrorCount = 0; // Track consecutive polling errors

  // Added to support cancellation
  bool _isCancelling = false;
  bool get isCancelling => _isCancelling;
  // Flag to track if generation was cancelled
  bool _wasCancelled = false;
  bool get wasCancelled => _wasCancelled;
  // Store the request ID for cancellation
  String? _currentRequestId;

  final RecipeService _recipeService = RecipeService();

  Recipe? get currentRecipe => _currentRecipe;
  Recipe? get partialRecipe => _partialRecipe;  // Getter for partial recipe
  List<Recipe> get userRecipes => _userRecipes;
  List<Recipe> get favoriteRecipes => _favoriteRecipes;
  List<Recipe> get trendingRecipes => _trendingRecipes;
  List<Recipe> get discoverRecipes => _discoverRecipes;
  List<RecipeCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreRecipes => _hasMoreRecipes;
  String? get error => _error;

  // Queue-related getters
  bool get isQueueActive => _isQueueActive;
  double get generationProgress => _generationProgress;

  // Method to directly set the current recipe
  void setCurrentRecipe(Recipe recipe) {
    print("RecipeProvider: Setting current recipe: ${recipe.title} (ID: ${recipe.id})");
    _currentRecipe = recipe;
    // If we just set a full recipe, clear any partial state/progress associated with generation
    _partialRecipe = null;
    _generationProgress = 1.0; // Assume 100% if setting directly
    _isLoading = false; // Assume not loading if setting directly (e.g., loading details, not generating)
    _error = null; // Clear any previous errors
    _resetCancellationState(); // Reset generation-related flags
    notifyListeners();
  }

  // Check if the backend is using a queue
  Future<void> checkQueueStatus() async {
    try {
      // Add breadcrumb for this operation
      addBreadcrumb(
        message: 'Checking queue status',
        category: 'api',
      );

      print("RecipeProvider: Checking queue status...");
      _isQueueActive = await _recipeService.isUsingQueue();
      print("RecipeProvider: Queue status check result: isQueueActive = $_isQueueActive");
      notifyListeners();
    } catch (e) {
      print("RecipeProvider: Error checking queue status: $e");
      // Log the error to Sentry
      captureException(e, stackTrace: StackTrace.current);
      _isQueueActive = false; // Default to not using queue if check fails
      notifyListeners();
    }
  }

  // --- MODIFIED: _startPollingForStatus accepts Completer ---
  void _startPollingForStatus(String requestId, Completer<Recipe?> completer) {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      print("RecipeProvider: Cancelled existing polling timer.");
    }

    print("RecipeProvider: Starting polling for requestId: $requestId");
    _pollingErrorCount = 0; // Reset error count

    addBreadcrumb(
      message: 'Starting recipe status polling',
      category: 'recipe',
      data: {'requestId': requestId},
    );

    const duration = Duration(milliseconds: 5000); // Polling interval

    _pollingTimer = Timer.periodic(duration, (timer) async {
      // Check if generation was cancelled FIRST
      if (_wasCancelled) {
        print("RecipeProvider: Stopping polling timer (wasCancelled is true)");
        timer.cancel();
        _pollingTimer = null;
        if (!completer.isCompleted) completer.complete(null); // Complete with null if cancelled
        return;
      }
      // Check if loading flag was turned off externally (e.g., error outside loop)
      if (!_isLoading) {
        print("RecipeProvider: Stopping polling timer (isLoading is false)");
        timer.cancel();
        _pollingTimer = null;
        if (!completer.isCompleted) completer.complete(null); // Complete with null if stopped unexpectedly
        return;
      }


      try {
        // Optional: Add delay for backoff after errors
        if (_pollingErrorCount > 0) {
          await Future.delayed(Duration(milliseconds: math.min(_pollingErrorCount * 2000, 10000))); // Max 10 sec delay
        }

        print("RecipeProvider: Polling status for $requestId...");
        final statusResult = await _recipeService.checkRecipeStatus(requestId);

        _pollingErrorCount = 0; // Reset error count on success

        // Schedule state updates after build frame using microtask
        Future.microtask(() {
          // Double-check state after await inside microtask
          if (_wasCancelled || !_isLoading) {
            if (!completer.isCompleted) completer.complete(null);
            return; // Don't update state if cancelled/stopped during await
          }

          Recipe? finalRecipe;
          bool isComplete = false;

          // Check for 'completed' status or legacy direct response (no status key)
          if (statusResult['status'] == 'completed' ||
              (statusResult['status'] == null && (statusResult['title'] != null || statusResult['id'] != null)) )
          {
            print("RecipeProvider: Polling detected 'completed' status or direct response.");
            isComplete = true;
            try {
              finalRecipe = Recipe.fromJson(statusResult);
              _currentRecipe = finalRecipe; // Update current recipe
              _partialRecipe = null; // Clear partial recipe
              _generationProgress = 1.0; // Set progress to 100%
              print("RecipeProvider: Final recipe parsed: ${finalRecipe.title}");
              addBreadcrumb(message: 'Recipe generation complete', category: 'recipe', data: {'title': finalRecipe.title});
            } catch (parseError) {
              print("RecipeProvider: Error parsing final recipe: $parseError");
              _error = 'Error parsing completed recipe data';
              captureException(parseError, stackTrace: StackTrace.current, hint: 'Error parsing final recipe');
              // Don't mark as complete if parsing failed
              isComplete = false;
              finalRecipe = null;
            }
          }
          else if (statusResult['status'] != null) { // Active states ('active', 'processing', 'waiting', etc.)
            final currentStatus = statusResult['status'];
            final newProgress = (statusResult['progress'] as num? ?? _generationProgress * 100).toDouble(); // Use current progress as fallback
            print("RecipeProvider: Status update - Status: $currentStatus, Progress: $newProgress%");
            _generationProgress = newProgress / 100.0;

            if (statusResult['partialRecipe'] != null && statusResult['partialRecipe'] is Map<String,dynamic>) {
              print("RecipeProvider: Received partial recipe data");
              try {
                _partialRecipe = Recipe.fromJson(statusResult['partialRecipe'] as Map<String, dynamic>);
                print("RecipeProvider: Partial recipe parsed: ${_partialRecipe?.title}");
                // Optionally cache this partial result in the service
                // _recipeService.cachePartialRecipe(requestId, statusResult['partialRecipe']);
              } catch (parseError) {
                print("RecipeProvider: Error parsing partial recipe: $parseError");
                _partialRecipe = null; // Clear partial if parsing fails
                captureException(parseError, stackTrace: StackTrace.current, hint: 'Error parsing partial recipe');
              }
            }
            // Check if status indicates an error state from the backend
            if (currentStatus == 'failed' || currentStatus == 'error') {
              print("RecipeProvider: Polling detected backend failure status: $currentStatus");
              isComplete = true; // Treat as complete (failed)
              _error = statusResult['message'] as String? ?? 'Recipe generation failed on server.';
            }

          }
          else {
            print("RecipeProvider: Polling received unexpected response format: $statusResult");
            // Keep polling unless error count threshold is met later
          }

          // Handle completion or error stopping
          if (isComplete) {
            timer.cancel();
            _pollingTimer = null;
            _isLoading = false; // Stop loading on completion/failure
            if (!completer.isCompleted) {
              completer.complete(finalRecipe); // Complete with recipe on success, null on failure/parseError
            }
          }
          // Notify listeners about progress/partial updates or final state change
          notifyListeners();
        });
        // --- End scheduled state updates ---

      } catch (e) {
        print("RecipeProvider: Error during polling HTTP request: $e");
        _pollingErrorCount++;

        // Schedule error state updates after build frame
        Future.microtask(() {
          // Double-check state after await/catch inside microtask
          if (_wasCancelled || !_isLoading) {
            if (!completer.isCompleted) completer.complete(null);
            return; // Don't update state if cancelled/stopped during await/catch
          }

          bool shouldStopPolling = false;
          String? pollErrorMsg;

          // Handle specific error types
          if (e.toString().contains('Too many requests') || e.toString().contains('429')) {
            print("RecipeProvider: Rate limit hit (429). Handling backoff.");
            addBreadcrumb(message: 'Rate limit hit during recipe polling', category: 'error', level: SentryLevel.warning);
            timer.cancel(); // Cancel the current timer
            // Recreate timer with longer duration using the current state
            final newDuration = Duration(milliseconds: math.min(5000 * math.pow(2, _pollingErrorCount).toInt(), 60000)); // Exponential backoff up to 60s
            print("RecipeProvider: Rate limit hit, increasing poll interval to ${newDuration.inMilliseconds}ms");
            // Restart polling with the same completer after the delay
            _pollingTimer = Timer(newDuration, () => _startPollingForStatus(requestId, completer));
            return; // Return from microtask, let the new timer take over
          } else if (e.toString().contains('cancelled') || e.toString().contains('499')) {
            print("RecipeProvider: Generation was cancelled detected during polling exception");
            _wasCancelled = true; // Ensure flag is set
            pollErrorMsg = 'Recipe generation cancelled';
            shouldStopPolling = true;
            addBreadcrumb(message: 'Recipe generation was cancelled', category: 'recipe');
          } else if (e.toString().contains('404') || e.toString().contains('job not found')) {
            print("RecipeProvider: Recipe job not found (404)");
            // Only stop after a few attempts, maybe it appears late
            if (_pollingErrorCount > 3) {
              pollErrorMsg = 'Recipe generation status not found';
              shouldStopPolling = true;
              captureException(e, stackTrace: StackTrace.current, hint: 'Recipe job not found after multiple attempts');
            }
          } else { // Generic error (network, parsing status response, etc.)
            // Stop after several consecutive errors
            if (_pollingErrorCount > 5) {
              print("RecipeProvider: Too many polling errors, stopping");
              pollErrorMsg = 'Error checking recipe status: ${e.toString().replaceFirst("Exception: ", "")}';
              shouldStopPolling = true;
              captureException(e, stackTrace: StackTrace.current, hint: 'Multiple polling errors');
            } else {
              print("RecipeProvider: Polling error attempt $_pollingErrorCount/5: $e");
            }
          }

          if (shouldStopPolling) {
            print("RecipeProvider: Stopping polling due to error/condition.");
            timer.cancel();
            _pollingTimer = null;
            _isLoading = false; // Stop loading on error
            _error = pollErrorMsg ?? 'Polling failed due to an unknown error.';
            if (!completer.isCompleted) {
              completer.complete(null); // Complete with null on error
            }
          }
          // Notify listeners if stopping polling or error occurred
          if (shouldStopPolling) {
            notifyListeners();
          }
        });
        // --- End scheduled error state updates ---
      }
    });
  }
  // --- END MODIFIED ---


  // --- MODIFIED: cancelRecipeGeneration ensures _wasCancelled is set ---
  Future<void> cancelRecipeGeneration() async {
    if (!_isLoading || _currentRequestId == null) {
      print("RecipeProvider: Cannot cancel - not loading or no requestId");
      return;
    }

    _isCancelling = true;
    notifyListeners(); // Notify UI about cancellation attempt START

    addBreadcrumb(
      message: 'Attempting to cancel recipe generation',
      category: 'recipe',
      data: {'requestId': _currentRequestId},
    );

    print('RecipeProvider: Attempting cancellation...');
    final requestIdToCancel = _currentRequestId;

    // Immediately stop polling if active
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
      print('RecipeProvider: Polling timer cancelled due to cancellation request.');
    }
    _currentRequestId = null; // Clear request ID early

    try {
      bool success = false;
      if (requestIdToCancel != null) {
        success = await _recipeService.cancelRecipeGeneration(requestIdToCancel);
      } else {
        // No request ID to cancel, assume local cancellation is enough
        success = true;
        print('RecipeProvider: Cancellation initiated without a server request ID.');
      }

      // Schedule state update using microtask AFTER the API call (or lack thereof)
      Future.microtask(() {
        _wasCancelled = true; // CRITICAL: Ensure this flag is set on any cancellation attempt outcome
        _isLoading = false; // Stop loading on cancellation
        _isCancelling = false; // Cancellation process finished
        _generationProgress = 0.0; // Reset progress
        _partialRecipe = null; // Clear partial recipe

        if (success) {
          print('RecipeProvider: Cancellation successful or no server ID needed.');
          _error = 'Recipe generation cancelled'; // User-friendly message
          addBreadcrumb(message: 'Recipe generation cancelled successfully', category: 'recipe');
        } else {
          print('RecipeProvider: Cancellation API call failed, marking cancelled locally');
          _error = 'Recipe generation cancelled (server may still be processing)';
          addBreadcrumb(message: 'Cancellation API call failed, marked cancelled locally', category: 'recipe', level: SentryLevel.warning);
        }
        notifyListeners(); // Notify about the final cancellation state
      });

    } catch (e) {
      print('RecipeProvider: Error during cancellation API call: $e');
      // Schedule state update using microtask for error case
      Future.microtask(() {
        _wasCancelled = true; // CRITICAL: Ensure this flag is set even on error
        _error = 'Error during cancellation request';
        _isLoading = false; // Stop loading
        _isCancelling = false; // Cancellation process finished (with error)
        _generationProgress = 0.0; // Reset progress
        _partialRecipe = null; // Clear partial recipe
        captureException(e, stackTrace: StackTrace.current, hint: 'Error during recipe cancellation');
        notifyListeners(); // Notify about the error state
      });
    }
    // No finally block needed, microtasks handle state updates and notification
  }
  // --- END MODIFIED ---


  void _resetCancellationState() {
    _isCancelling = false;
    _wasCancelled = false;
    _currentRequestId = null;
    _generationProgress = 0.0;
    _partialRecipe = null;
    _pollingErrorCount = 0;

    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
    }
  }

  // --- MODIFIED: generateRecipe returns Future<Recipe?> and uses Completer ---
  Future<Recipe?> generateRecipe(String query, {bool save = false, String? token}) async {
    // --- Subscription check logic (keep as is) ---
    if (token != null) {
      final BuildContext? context = navigatorKey.currentContext;
      if (context != null && context.mounted) { // Add mounted check
        final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
        try {
          await subscriptionProvider.loadSubscriptionStatus(token);
          final subscriptionInfo = subscriptionProvider.subscriptionInfo;
          if (subscriptionInfo != null &&
              subscriptionInfo.tier != SubscriptionTier.premium &&
              subscriptionInfo.recipeGenerationsRemaining <= 0) {
            if (context.mounted) { // Check mounted again before showing dialog
              showDialog(
                context: context,
                builder: (ctx) => GenerationLimitDialog(currentTier: subscriptionInfo.tier),
              );
            }
            return null; // Stop generation if limit reached
          }
        } catch (e) {
          print("RecipeProvider: Error checking subscription status: $e");
          captureException(e, stackTrace: StackTrace.current, hint: 'Error checking subscription status before recipe generation');
          // Allow continuing if check fails, but log it
        }
      }
    }
    // --- End Subscription check ---


    // Use Completer to manage the async result, especially needed for polling
    final Completer<Recipe?> completer = Completer<Recipe?>();

    // Schedule initial state updates after current build frame
    Future.microtask(() {
      _isLoading = true;
      _error = null;
      _resetCancellationState(); // Also resets partial recipe, progress, etc.
      notifyListeners();
    });

    addBreadcrumb(
      message: 'Starting recipe generation',
      category: 'recipe',
      data: {'query': query, 'save': save},
    );

    try {
      print('RecipeProvider: Starting generateRecipe for query: $query');
      // Await queue status check (might have been checked already, but ensure it's up-to-date)
      await checkQueueStatus();
      print("RecipeProvider: Queue status confirmed. isQueueActive = $_isQueueActive");

      if (_isQueueActive) {
        print("RecipeProvider: Using QUEUED generation path");
        final requestResult = await _recipeService.startRecipeGeneration(query, save: save, token: token);

        // Schedule state update and polling start within a microtask
        Future.microtask(() {
          _currentRequestId = requestResult['requestId'];
          print('RecipeProvider: Received requestId for polling: $_currentRequestId');
          if (_currentRequestId != null) {
            // Start polling and link its result (Recipe? or null) to the completer
            _startPollingForStatus(_currentRequestId!, completer);
          } else {
            _error = 'No request ID received for polling';
            _isLoading = false; // Stop loading if no request ID
            notifyListeners();
            if (!completer.isCompleted) completer.complete(null); // Complete with null on error
          }
        });
      } else {
        print("RecipeProvider: Using DIRECT (non-queued) generation");
        // Await the direct result
        final recipe = await _recipeService.generateRecipe(query, save: save, token: token);

        // Schedule state update within a microtask
        Future.microtask(() {
          _currentRequestId = recipe.requestId; // Store even for direct for consistency if available
          print('RecipeProvider: Received direct recipe with ID: ${recipe.id}');

          // Check if it was cancelled *during* the direct API call (less likely but possible)
          if (_wasCancelled) {
            print('RecipeProvider: Generation was cancelled during direct API call');
            _error = 'Recipe generation cancelled';
            _isLoading = false; // Stop loading
            notifyListeners();
            if (!completer.isCompleted) completer.complete(null); // Complete with null if cancelled
          } else {
            // Success
            _currentRecipe = recipe; // Set the generated recipe
            _generationProgress = 1.0; // Mark as complete
            _partialRecipe = null; // Clear any partial state
            // Update userRecipes list if saved
            if (save && token != null && recipe.id != null) {
              final existingIndex = _userRecipes.indexWhere((r) => r.id == recipe.id);
              if (existingIndex >= 0) _userRecipes[existingIndex] = recipe;
              else _userRecipes.add(recipe);
            }
            print('RecipeProvider: Direct recipe generation successful');
            addBreadcrumb(message: 'Direct recipe generation complete', category: 'recipe', data: {'title': recipe.title});
            _isLoading = false; // Stop loading
            notifyListeners();
            if (!completer.isCompleted) completer.complete(recipe); // Complete with the recipe
          }
        });
      }
    } catch (e) {
      print("RecipeProvider: Error caught in generateRecipe call: $e");
      // Schedule state update for error within a microtask
      Future.microtask(() {
        if (e.toString().contains('cancelled')) { // Check error message too
          _wasCancelled = true;
          _error = 'Recipe generation cancelled';
        } else {
          _error = e.toString().replaceFirst("Exception: ", "");
        }
        _isLoading = false; // Stop loading on error
        // Ensure polling is stopped if an error occurs before polling even starts
        if (_pollingTimer != null) {
          _pollingTimer!.cancel();
          _pollingTimer = null;
        }
        _resetCancellationState(); // Reset relevant flags on error too
        captureException(e, stackTrace: StackTrace.current, hint: 'Error in generateRecipe main try-catch');
        notifyListeners();
        if (!completer.isCompleted) completer.complete(null); // Complete with null on error
      });
    } finally {
      // The completer's future will eventually complete (either with Recipe? or null).
      // We add a cleanup step that runs *after* the completer finishes.
      completer.future.whenComplete(() {
        Future.microtask(() {
          _isCancelling = false; // Ensure cancelling flag is reset once the whole process is over
          // If still loading after completion (shouldn't happen normally), force it off
          if (_isLoading) {
            print("RecipeProvider: Forcing isLoading=false after generateRecipe completion.");
            _isLoading = false;
          }
          notifyListeners(); // Notify for isCancelling reset if needed
        });
      });
    }

    // Return the future from the completer, which will resolve with Recipe? or null.
    return completer.future;
  }
  // --- END MODIFIED ---


  // --- NEW: Helper to fetch and set recipe ---
  Future<Recipe?> fetchAndSetCurrentRecipe(String recipeId, String? token) async {
    if (token == null) {
      print("RecipeProvider: Cannot fetch recipe details - User not logged in.");
      _error = "Cannot load recipe details: Please log in.";
      // Don't set isLoading = true if not logged in
      notifyListeners();
      return null;
    }
    // If the current recipe is already the one we want, don't refetch
    if (_currentRecipe?.id == recipeId) {
      print("RecipeProvider: Recipe $recipeId already set as current.");
      // Ensure loading is false if we skip fetch
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
      return _currentRecipe;
    }


    print("RecipeProvider: Fetching and setting recipe by ID: $recipeId");
    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify UI that loading started

    try {
      final recipe = await _recipeService.getRecipeById(recipeId, token);
      // Use setCurrentRecipe to handle state updates and notifications
      setCurrentRecipe(recipe);
      return recipe; // Return the fetched recipe
    } catch (e) {
      print("RecipeProvider: Error fetching recipe by ID $recipeId: $e");
      _error = "Failed to load recipe details: ${e.toString().replaceFirst("Exception: ", "")}";
      _isLoading = false; // Ensure loading is stopped on error
      notifyListeners(); // Notify UI about the error
      captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching recipe by ID for chat view');
      return null; // Return null on failure
    }
    // isLoading state is managed by setCurrentRecipe on success or catch block on error
  }
  // --- END NEW ---


  // --- Other methods remain unchanged ---
  Future<void> getUserRecipes(String token) async { _isLoading = true; _error = null; notifyListeners(); try { addBreadcrumb(message: 'Fetching user recipes', category: 'recipe'); print('RecipeProvider: Fetching user recipes'); final recipes = await _recipeService.getUserRecipes(token); _userRecipes = recipes; print('RecipeProvider: Got ${recipes.length} user recipes'); } catch (e) { _error = e.toString().replaceFirst("Exception: ", ""); print('RecipeProvider: Error fetching user recipes: $_error'); captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching user recipes'); } finally { _isLoading = false; notifyListeners(); } }
  Future<void> getRecipeById(String id, String token) async { _isLoading = true; _error = null; notifyListeners(); try { addBreadcrumb(message: 'Fetching recipe by ID', category: 'recipe', data: {'recipeId': id}); print('RecipeProvider: Fetching recipe by ID: $id'); final recipe = await _recipeService.getRecipeById(id, token); _currentRecipe = recipe; print('RecipeProvider: Successfully retrieved recipe: ${recipe.title}'); } catch (e) { _error = e.toString().replaceFirst("Exception: ", ""); print('RecipeProvider: Error fetching recipe by ID: $_error'); captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching recipe by ID'); } finally { _isLoading = false; notifyListeners(); } }
  Future<bool> deleteRecipe(String recipeId, String token) async { _isLoading = true; _error = null; notifyListeners(); bool success = false; try { addBreadcrumb(message: 'Deleting recipe', category: 'recipe', data: {'recipeId': recipeId}); print('RecipeProvider: Deleting recipe ID: $recipeId'); success = await _recipeService.deleteRecipe(recipeId, token); if (success) { _userRecipes.removeWhere((recipe) => recipe.id == recipeId); _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId); if (_currentRecipe?.id == recipeId) _currentRecipe = null; print('RecipeProvider: Recipe deleted successfully'); } } catch (e) { _error = e.toString().replaceFirst("Exception: ", ""); print('RecipeProvider: Error deleting recipe: $_error'); success = false; captureException(e, stackTrace: StackTrace.current, hint: 'Error deleting recipe'); } finally { _isLoading = false; notifyListeners(); } return success; }
  Future<bool> toggleFavorite(String recipeId, String token) async { _isLoading = true; _error = null; notifyListeners(); bool success = false; bool isCurrentlyFavorite = _favoriteRecipes.any((r) => r.id == recipeId) || (_currentRecipe?.id == recipeId && _currentRecipe!.isFavorite); try { addBreadcrumb( message: isCurrentlyFavorite ? 'Removing recipe from favorites' : 'Adding recipe to favorites', category: 'recipe', data: {'recipeId': recipeId}, ); if (isCurrentlyFavorite) { success = await _recipeService.removeFromFavorites(recipeId, token); if (success) { _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId); if (_currentRecipe?.id == recipeId) { _currentRecipe = _currentRecipe!.copyWith(isFavorite: false); } print('RecipeProvider: Recipe removed from favorites'); } } else { success = await _recipeService.addToFavorites(recipeId, token); if (success) { final recipeToAdd = (_currentRecipe?.id == recipeId) ? _currentRecipe!.copyWith(isFavorite: true) : await _recipeService.getRecipeById(recipeId, token); if (_currentRecipe?.id == recipeId) { _currentRecipe = _currentRecipe!.copyWith(isFavorite: true); } if (!_favoriteRecipes.any((r) => r.id == recipeId)) { _favoriteRecipes.add(recipeToAdd); } print('RecipeProvider: Recipe added to favorites'); } } final userRecipeIndex = _userRecipes.indexWhere((recipe) => recipe.id == recipeId); if (userRecipeIndex >= 0) { if (_currentRecipe?.id == recipeId) { _userRecipes[userRecipeIndex] = _currentRecipe!; } else { _userRecipes[userRecipeIndex] = _userRecipes[userRecipeIndex].copyWith(isFavorite: !isCurrentlyFavorite); } } } catch (e) { _error = e.toString().replaceFirst("Exception: ", ""); print('RecipeProvider: Error toggling favorite: $_error'); success = false; captureException(e, stackTrace: StackTrace.current, hint: 'Error toggling recipe favorite status'); } finally { _isLoading = false; notifyListeners(); } return success; }
  Future<void> getFavoriteRecipes(String token) async { _isLoading = true; _error = null; notifyListeners(); try { addBreadcrumb(message: 'Fetching favorite recipes', category: 'recipe'); print('RecipeProvider: Fetching favorite recipes'); final recipes = await _recipeService.getFavoriteRecipes(token); _favoriteRecipes = recipes; print('RecipeProvider: Got ${recipes.length} favorite recipes'); } catch (e) { _error = e.toString().replaceFirst("Exception: ", ""); print('RecipeProvider: Error fetching favorite recipes: $_error'); captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching favorite recipes'); } finally { _isLoading = false; notifyListeners(); } }
  Future<void> shareRecipe() async { if (_currentRecipe == null) { print('RecipeProvider: Cannot share, current recipe is null'); _error = "No recipe selected to share."; notifyListeners(); return; } _error = null; notifyListeners(); try { addBreadcrumb(message: 'Sharing recipe', category: 'recipe', data: {'title': _currentRecipe!.title}); await _recipeService.shareRecipe(_currentRecipe!); print('RecipeProvider: Share action initiated successfully'); } catch (e) { _error = "Could not share recipe: ${e.toString().replaceFirst("Exception: ", "")}"; print('RecipeProvider: Error sharing recipe: $_error'); captureException(e, stackTrace: StackTrace.current, hint: 'Error sharing recipe'); notifyListeners(); } }
  Future<void> getTrendingRecipes({String? token}) async { _isLoading = true; _error = null; notifyListeners(); try { addBreadcrumb(message: 'Fetching trending recipes', category: 'recipe'); print('RecipeProvider: Fetching trending recipes'); final recipes = await _recipeService.getPopularRecipes(token: token); _trendingRecipes = recipes; print('RecipeProvider: Got ${recipes.length} trending recipes'); } catch (e) { _error = e.toString().replaceFirst("Exception: ", ""); print('RecipeProvider: Error fetching trending recipes: $_error'); _trendingRecipes = []; captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching trending recipes'); } finally { _isLoading = false; notifyListeners(); } }
  Future<void> getAllCategories() async { _error = null; try { addBreadcrumb(message: 'Fetching recipe categories', category: 'recipe'); print('RecipeProvider: Fetching all recipe categories'); final categoriesData = await _recipeService.getAllCategories(); _categories = categoriesData.map((categoryData) { return RecipeCategory( id: categoryData['id'] as String? ?? 'unknown', name: categoryData['name'] as String? ?? 'Unnamed Category', description: categoryData['description'] as String? ?? '', icon: RecipeCategory.getCategoryIcon(categoryData['id'] as String? ?? ''), color: RecipeCategory.getCategoryColor(categoryData['id'] as String? ?? ''), count: categoryData['count'] as int? ?? 0, ); }).toList(); print('RecipeProvider: Got ${_categories.length} categories'); } catch (e) { _error = e.toString().replaceFirst("Exception: ", ""); print('RecipeProvider: Error fetching categories: $_error'); _categories = []; captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching recipe categories'); } notifyListeners(); }
  Future<void> getDiscoverRecipes({ String? category, String? query, String sort = 'recent', String? token, }) async { _isLoading = true; _error = null; _currentPage = 0; _hasMoreRecipes = true; _discoverRecipes = []; notifyListeners(); try { addBreadcrumb(message: 'Fetching discover recipes', category: 'recipe', data: {'category': category, 'query': query, 'sort': sort}); print('RecipeProvider: Fetching discover recipes'); print('RecipeProvider: Category: $category, Query: $query, Sort: $sort'); List<String>? tags; String? processedQuery = query; if (processedQuery != null && processedQuery.contains('#')) { final RegExp tagRegex = RegExp(r'#(\w+)'); final matches = tagRegex.allMatches(processedQuery); if (matches.isNotEmpty) { tags = matches.map((m) => m.group(1)!).toList(); processedQuery = processedQuery.replaceAll(tagRegex, '').trim(); if (processedQuery.isEmpty) processedQuery = null; } } final recipes = await _recipeService.getDiscoverRecipes(category: category, tags: tags, sort: sort, limit: 20, offset: 0, token: token, query: processedQuery); _discoverRecipes = recipes; _hasMoreRecipes = recipes.length == 20; print('RecipeProvider: Got ${recipes.length} discover recipes'); } catch (e) { _error = e.toString().replaceFirst("Exception: ", ""); print('RecipeProvider: Error fetching discover recipes: $_error'); _discoverRecipes = []; _hasMoreRecipes = false; captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching discover recipes'); } finally { _isLoading = false; notifyListeners(); } }
  Future<void> loadMoreDiscoverRecipes({ String? category, String? query, String sort = 'recent', String? token, }) async { if (_isLoadingMore || !_hasMoreRecipes) return; _isLoadingMore = true; notifyListeners(); try { _currentPage++; print('RecipeProvider: Loading more discover recipes (page: $_currentPage)'); addBreadcrumb(message: 'Loading more discover recipes', category: 'recipe', data: {'page': _currentPage, 'category': category, 'query': query, 'sort': sort}); List<String>? tags; String? processedQuery = query; if (processedQuery != null && processedQuery.contains('#')) { final RegExp tagRegex = RegExp(r'#(\w+)'); final matches = tagRegex.allMatches(processedQuery); if (matches.isNotEmpty) { tags = matches.map((m) => m.group(1)!).toList(); processedQuery = processedQuery.replaceAll(tagRegex, '').trim(); if (processedQuery.isEmpty) processedQuery = null; } } final recipes = await _recipeService.getDiscoverRecipes(category: category, tags: tags, sort: sort, limit: 20, offset: _currentPage * 20, token: token, query: processedQuery); if (recipes.isEmpty) { _hasMoreRecipes = false; } else { _discoverRecipes.addAll(recipes); _hasMoreRecipes = recipes.length == 20; } print('RecipeProvider: Loaded ${recipes.length} more discover recipes'); } catch (e) { _error = e.toString().replaceFirst("Exception: ", ""); print('RecipeProvider: Error loading more discover recipes: $_error'); captureException(e, stackTrace: StackTrace.current, hint: 'Error loading more discover recipes'); } finally { _isLoadingMore = false; notifyListeners(); } }
  Future<void> resetAndReloadDiscoverRecipes({ String? category, String? query, String sort = 'recent', String? token, }) async { return getDiscoverRecipes( category: category, query: query, sort: sort, token: token, ); }
  Future<List<Recipe>> getCategoryRecipes( String categoryId, { String sort = 'recent', int limit = 20, int offset = 0, String? token, } ) async { try { addBreadcrumb(message: 'Fetching category recipes', category: 'recipe', data: {'categoryId': categoryId, 'sort': sort, 'limit': limit, 'offset': offset}); print('RecipeProvider: Fetching category recipes: $categoryId'); final recipes = await _recipeService.getCategoryRecipes(categoryId, sort: sort, limit: limit, offset: offset, token: token); print('RecipeProvider: Got ${recipes.length} category recipes'); return recipes; } catch (e) { print('RecipeProvider: Error fetching category recipes: $e'); captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching category recipes'); return []; } }
  void clearCurrentRecipe() { _currentRecipe = null; _partialRecipe = null; _resetCancellationState(); notifyListeners(); }
}