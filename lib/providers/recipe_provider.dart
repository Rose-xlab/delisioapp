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
    _currentRecipe = recipe;
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

  // Start polling for recipe generation status with improved error handling
  // and fix for setState during build
  void _startPollingForStatus(String requestId) {
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

    const duration = Duration(milliseconds: 5000);

    _pollingTimer = Timer.periodic(duration, (timer) async {
      if (!_isLoading || _wasCancelled) {
        print("RecipeProvider: Stopping polling timer (isLoading: $_isLoading, wasCancelled: $_wasCancelled)");
        timer.cancel();
        _pollingTimer = null;
        return;
      }

      try {
        if (_pollingErrorCount > 0) {
          await Future.delayed(Duration(milliseconds: _pollingErrorCount * 2000));
        }

        print("RecipeProvider: Polling status for $requestId...");
        final statusResult = await _recipeService.checkRecipeStatus(requestId);

        _pollingErrorCount = 0; // Reset error count on success

        // --- Schedule state updates after build frame ---
        Future.microtask(() {
          // Check again if cancelled or not loading AFTER the await
          if (!_isLoading || _wasCancelled) {
            return; // Don't update state if cancelled/stopped during await
          }

          if (statusResult['status'] == 'completed') {
            print("RecipeProvider: Polling detected 'completed' status - Received final recipe");
            timer.cancel();
            _pollingTimer = null;
            _isLoading = false;
            _generationProgress = 1.0;
            try {
              final recipe = Recipe.fromJson(statusResult);
              _currentRecipe = recipe;
              _partialRecipe = null;
              print("RecipeProvider: Final recipe received with title: ${recipe.title}");
              addBreadcrumb(message: 'Recipe generation complete', category: 'recipe', data: {'title': recipe.title});
            } catch (parseError) {
              print("RecipeProvider: Error parsing final recipe: $parseError");
              _error = 'Error parsing recipe data';
              captureException(parseError, stackTrace: StackTrace.current, hint: 'Error parsing final recipe');
            }
          }
          else if (statusResult['status'] != null) { // Active states
            final currentStatus = statusResult['status'];
            final newProgress = (statusResult['progress'] as num? ?? 0).toDouble();
            print("RecipeProvider: Status update - Status: $currentStatus, Progress: $newProgress%");
            _generationProgress = newProgress / 100.0;
            if (statusResult['partialRecipe'] != null) {
              print("RecipeProvider: Received partial recipe data");
              try {
                _partialRecipe = Recipe.fromJson(statusResult['partialRecipe']);
                print("RecipeProvider: Partial recipe parsed: ${_partialRecipe?.title}");
              } catch (parseError) {
                print("RecipeProvider: Error parsing partial recipe: $parseError");
                captureException(parseError, stackTrace: StackTrace.current, hint: 'Error parsing partial recipe');
              }
            }
          }
          else { // Fallback: Status key missing, assume complete
            print("RecipeProvider: Polling complete (status key missing) - Received final recipe");
            timer.cancel();
            _pollingTimer = null;
            _isLoading = false;
            _generationProgress = 1.0;
            try {
              final recipe = Recipe.fromJson(statusResult);
              _currentRecipe = recipe;
              _partialRecipe = null;
              print("RecipeProvider: Final recipe received with title: ${recipe.title}");
              addBreadcrumb(message: 'Recipe generation complete (legacy)', category: 'recipe', data: {'title': recipe.title});
            } catch (parseError) {
              print("RecipeProvider: Error parsing final recipe (legacy): $parseError");
              _error = 'Error parsing recipe data';
              captureException(parseError, stackTrace: StackTrace.current, hint: 'Error parsing final recipe (legacy)');
            }
          }
          // Notify listeners inside the microtask, after state is updated
          notifyListeners();
        });
        // --- End scheduled state updates ---

      } catch (e) {
        print("RecipeProvider: Error during polling: $e");
        _pollingErrorCount++;

        // --- Schedule error state updates after build frame ---
        Future.microtask(() {
          // Check again if cancelled or not loading AFTER the await/catch
          if (!_isLoading || _wasCancelled) {
            return; // Don't update state if cancelled/stopped during await
          }

          // Handle specific error types
          if (e.toString().contains('Too many requests') || e.toString().contains('429')) {
            print("RecipeProvider: Rate limit hit (429). Slowing down polling rate.");
            addBreadcrumb(message: 'Rate limit hit during recipe polling', category: 'error', level: SentryLevel.warning);
            timer.cancel(); // Cancel the current timer
            // Recreate timer with longer duration (logic moved outside microtask for clarity)
          } else if (e.toString().contains('cancelled') || e.toString().contains('499')) {
            print("RecipeProvider: Generation was cancelled during polling");
            _wasCancelled = true;
            _error = 'Recipe generation cancelled';
            timer.cancel();
            _pollingTimer = null;
            _isLoading = false;
            addBreadcrumb(message: 'Recipe generation was cancelled', category: 'recipe');
            notifyListeners(); // Notify about cancellation state
          } else if (e.toString().contains('404')) {
            print("RecipeProvider: Recipe job not found (404)");
            if (_pollingErrorCount > 2) {
              _error = 'Recipe generation status not found';
              timer.cancel();
              _pollingTimer = null;
              _isLoading = false;
              captureException(e, stackTrace: StackTrace.current, hint: 'Recipe job not found after multiple attempts');
              notifyListeners(); // Notify about error state
            }
            // If error count is low, don't notify, just continue polling
          } else {
            if (_pollingErrorCount > 3) {
              print("RecipeProvider: Too many polling errors, stopping");
              _error = 'Error checking recipe status: ${e.toString().replaceFirst("Exception: ", "")}';
              timer.cancel();
              _pollingTimer = null;
              _isLoading = false;
              captureException(e, stackTrace: StackTrace.current, hint: 'Multiple polling errors');
              notifyListeners(); // Notify about error state
            }
            // If error count is low, don't notify, just continue polling
          }
        });
        // --- End scheduled error state updates ---

        // Handle timer recreation for rate limiting outside the microtask
        if (e.toString().contains('Too many requests') || e.toString().contains('429')) {
          final newDuration = Duration(milliseconds: 5000 * math.pow(2, _pollingErrorCount).toInt());
          print("RecipeProvider: Rate limit hit, increasing poll interval to ${newDuration.inMilliseconds}ms");
          // Ensure we pass the existing timer object if _doPollStatus expects it
          // Since _doPollStatus has identical logic, we can call _startPollingForStatus again
          // after a delay, ensuring we use the *new* _pollingErrorCount
          _pollingTimer = Timer(newDuration, () => _startPollingForStatus(requestId));
        }
      }
    });
  }

  // Helper method to extract the polling logic for reuse
  // THIS METHOD IS NOW REDUNDANT because the rate limit handling restarts the main timer
  // Keep it for now, but ensure its logic matches _startPollingForStatus if used.
  // Or refactor to have a single polling logic function called by the Timer.periodic.
  // For simplicity, let's ensure the logic here mirrors _startPollingForStatus.
  Future<void> _doPollStatus(String requestId, Timer timer) async {
    if (!_isLoading || _wasCancelled) {
      timer.cancel();
      _pollingTimer = null;
      return;
    }

    try {
      final statusResult = await _recipeService.checkRecipeStatus(requestId);
      _pollingErrorCount = 0; // Reset on success

      // --- Schedule state updates after build frame ---
      Future.microtask(() {
        // Check again if cancelled or not loading AFTER the await
        if (!_isLoading || _wasCancelled) {
          return;
        }

        if (statusResult['status'] == 'completed') {
          print("RecipeProvider (doPoll): Polling detected 'completed' status - Received final recipe");
          timer.cancel();
          _pollingTimer = null;
          _isLoading = false;
          _generationProgress = 1.0;
          try {
            final recipe = Recipe.fromJson(statusResult);
            _currentRecipe = recipe;
            _partialRecipe = null;
            print("RecipeProvider (doPoll): Final recipe received with title: ${recipe.title}");
            addBreadcrumb(message: 'Recipe generation complete (doPoll)', category: 'recipe', data: {'title': recipe.title});
          } catch (parseError) {
            print("RecipeProvider (doPoll): Error parsing final recipe: $parseError");
            _error = 'Error parsing recipe data';
            captureException(parseError, stackTrace: StackTrace.current, hint: 'Error parsing final recipe (doPoll)');
          }
        }
        else if (statusResult['status'] != null) {
          final currentStatus = statusResult['status'];
          final newProgress = (statusResult['progress'] as num? ?? 0).toDouble();
          print("RecipeProvider (doPoll): Status update - Status: $currentStatus, Progress: $newProgress%");
          _generationProgress = newProgress / 100.0;
          if (statusResult['partialRecipe'] != null) {
            print("RecipeProvider (doPoll): Received partial recipe data");
            try {
              _partialRecipe = Recipe.fromJson(statusResult['partialRecipe']);
            } catch (parseError) {
              print("RecipeProvider (doPoll): Error parsing partial recipe: $parseError");
              captureException(parseError, stackTrace: StackTrace.current, hint: 'Error parsing partial recipe (doPoll)');
            }
          }
        } else {
          print("RecipeProvider (doPoll): Polling complete (status key missing) - Received final recipe");
          timer.cancel();
          _pollingTimer = null;
          _isLoading = false;
          _generationProgress = 1.0;
          try {
            final recipe = Recipe.fromJson(statusResult);
            _currentRecipe = recipe;
            _partialRecipe = null;
            print("RecipeProvider (doPoll): Final recipe received with title: ${recipe.title}");
            addBreadcrumb(message: 'Recipe generation complete (doPoll/legacy)', category: 'recipe', data: {'title': recipe.title});
          } catch (parseError) {
            print("RecipeProvider (doPoll): Error parsing final recipe (legacy): $parseError");
            _error = 'Error parsing recipe data';
            captureException(parseError, stackTrace: StackTrace.current, hint: 'Error parsing final recipe (doPoll/legacy)');
          }
        }
        notifyListeners(); // Notify inside microtask
      });
      // --- End scheduled updates ---

    } catch (e) {
      print("RecipeProvider (doPoll): Error: $e");
      _pollingErrorCount++;
      // --- Schedule error state updates after build frame ---
      Future.microtask(() {
        if (!_isLoading || _wasCancelled) {
          return;
        }
        if (_pollingErrorCount > 5) { // Higher threshold
          _error = 'Error communicating with server';
          timer.cancel();
          _pollingTimer = null;
          _isLoading = false;
          captureException(e, stackTrace: StackTrace.current, hint: 'Multiple errors in _doPollStatus');
          notifyListeners(); // Notify inside microtask
        }
        // Don't notify for recoverable errors
      });
      // --- End scheduled error updates ---
    }
  }

  // Improved method to cancel recipe generation
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

    try {
      if (requestIdToCancel == null) {
        // Schedule state update
        Future.microtask(() {
          _wasCancelled = true;
          _error = 'Recipe generation cancelled (no request ID)';
          _isLoading = false;
          _isCancelling = false;
          notifyListeners();
        });
      } else {
        final success = await _recipeService.cancelRecipeGeneration(requestIdToCancel);
        // Schedule state update
        Future.microtask(() {
          if (success) {
            print('RecipeProvider: Cancellation successful');
            _wasCancelled = true;
            _error = 'Recipe generation cancelled';
            addBreadcrumb(message: 'Recipe generation cancelled successfully', category: 'recipe');
          } else {
            print('RecipeProvider: Cancellation API call failed, marking cancelled locally');
            _wasCancelled = true;
            _error = 'Recipe generation cancelled (server may still be processing)';
            addBreadcrumb(message: 'Cancellation API call failed, marked cancelled locally', category: 'recipe', level: SentryLevel.warning);
          }
          _isLoading = false;
          _isCancelling = false;
          notifyListeners();
        });
      }
    } catch (e) {
      print('RecipeProvider: Error during cancellation: $e');
      // Schedule state update
      Future.microtask(() {
        _wasCancelled = true;
        _error = 'Error during cancellation request';
        _isLoading = false;
        _isCancelling = false;
        captureException(e, stackTrace: StackTrace.current, hint: 'Error during recipe cancellation');
        notifyListeners();
      });
    } finally {
      // Always stop polling and reset request ID immediately
      if (_pollingTimer != null) {
        _pollingTimer!.cancel();
        _pollingTimer = null;
      }
      _currentRequestId = null;
      _generationProgress = 0.0;
      _partialRecipe = null;
      // Final state notification happens inside the microtasks above
    }
  }

  // Reset cancellation state
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

  // Generate a new recipe - enhanced for better queue handling and subscription checks
  Future<void> generateRecipe(String query, {bool save = false, String? token}) async {
    // Check subscription status first
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
            return; // Stop generation if limit reached
          }
        } catch (e) {
          print("RecipeProvider: Error checking subscription status: $e");
          captureException(e, stackTrace: StackTrace.current, hint: 'Error checking subscription status before recipe generation');
          // Allow continuing if check fails, but log it
        }
      }
    }

    // Schedule state updates after current build frame
    Future.microtask(() {
      _isLoading = true;
      _error = null;
      _resetCancellationState(); // Also resets partial recipe
      notifyListeners();
    });

    addBreadcrumb(
      message: 'Starting recipe generation',
      category: 'recipe',
      data: {'query': query, 'save': save},
    );

    try {
      print('RecipeProvider: Starting generateRecipe for query: $query');
      await checkQueueStatus(); // Await queue status check
      print("RecipeProvider: Queue status confirmed. isQueueActive = $_isQueueActive");

      if (_isQueueActive) {
        print("RecipeProvider: Using QUEUED generation path");
        final requestResult = await _recipeService.startRecipeGeneration(query, save: save, token: token);
        // Schedule state update
        Future.microtask(() {
          _currentRequestId = requestResult['requestId'];
          print('RecipeProvider: Received requestId for polling: $_currentRequestId');
          if (_currentRequestId != null) {
            _startPollingForStatus(_currentRequestId!);
          } else {
            _error = 'No request ID received for polling';
            _isLoading = false;
            notifyListeners();
          }
        });
      } else {
        print("RecipeProvider: Using DIRECT (non-queued) generation");
        final recipe = await _recipeService.generateRecipe(query, save: save, token: token);
        // Schedule state update
        Future.microtask(() {
          _currentRequestId = recipe.requestId; // Store even for direct for consistency
          print('RecipeProvider: Received direct recipe with ID: ${recipe.id}');
          if (_wasCancelled) {
            print('RecipeProvider: Generation was cancelled during API call');
            _error = 'Recipe generation cancelled';
          } else {
            _currentRecipe = recipe;
            _generationProgress = 1.0;
            if (save && token != null && recipe.id != null) {
              final existingIndex = _userRecipes.indexWhere((r) => r.id == recipe.id);
              if (existingIndex >= 0) _userRecipes[existingIndex] = recipe;
              else _userRecipes.add(recipe);
            }
            print('RecipeProvider: Direct recipe generation successful');
            addBreadcrumb(message: 'Direct recipe generation complete', category: 'recipe', data: {'title': recipe.title});
          }
          _isLoading = false; // Direct generation finishes here
          notifyListeners();
        });
      }
    } catch (e) {
      print("RecipeProvider: Error in generateRecipe: $e");
      // Schedule state update
      Future.microtask(() {
        if (e.toString().contains('cancelled')) {
          _wasCancelled = true;
          _error = 'Recipe generation cancelled';
        } else {
          _error = e.toString().replaceFirst("Exception: ", "");
        }
        _isLoading = false;
        if (_pollingTimer != null) {
          _pollingTimer!.cancel();
          _pollingTimer = null;
        }
        captureException(e, stackTrace: StackTrace.current, hint: 'Error in generateRecipe');
        notifyListeners();
      });
    } finally {
      // The isLoading = false and notifyListeners() for the success paths
      // are handled within the microtasks now.
      // The finally block might not be necessary for isLoading anymore,
      // but we keep the _isCancelling reset.
      Future.microtask(() {
        if (_pollingTimer == null && !_isLoading) {
          // Ensure loading is false if polling isn't running
          // This can happen if queue check fails or direct generation error occurs early
          _isLoading = false;
        }
        _isCancelling = false;
        // Avoid calling notifyListeners() directly in finally if it was already called
        // in the microtasks within try/catch. Redundant notifications are okay, but
        // calling here might still cause issues if try/catch didn't schedule one.
        // Let the scheduled microtasks handle final notification.
      });
    }
  }


  // --- Other methods remain unchanged ---

  Future<void> getUserRecipes(String token) async {
    // ... (existing code without microtask - likely safe as it's a simple fetch)
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      addBreadcrumb(message: 'Fetching user recipes', category: 'recipe');
      print('RecipeProvider: Fetching user recipes');
      final recipes = await _recipeService.getUserRecipes(token);
      _userRecipes = recipes;
      print('RecipeProvider: Got ${recipes.length} user recipes');
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching user recipes: $_error');
      captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching user recipes');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getRecipeById(String id, String token) async {
    // ... (existing code without microtask - likely safe as it's a simple fetch)
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      addBreadcrumb(message: 'Fetching recipe by ID', category: 'recipe', data: {'recipeId': id});
      print('RecipeProvider: Fetching recipe by ID: $id');
      final recipe = await _recipeService.getRecipeById(id, token);
      _currentRecipe = recipe;
      print('RecipeProvider: Successfully retrieved recipe: ${recipe.title}');
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching recipe by ID: $_error');
      captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching recipe by ID');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRecipe(String recipeId, String token) async {
    // ... (existing code without microtask - likely safe)
    _isLoading = true;
    _error = null;
    notifyListeners();
    bool success = false;
    try {
      addBreadcrumb(message: 'Deleting recipe', category: 'recipe', data: {'recipeId': recipeId});
      print('RecipeProvider: Deleting recipe ID: $recipeId');
      success = await _recipeService.deleteRecipe(recipeId, token);
      if (success) {
        _userRecipes.removeWhere((recipe) => recipe.id == recipeId);
        _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId);
        if (_currentRecipe?.id == recipeId) _currentRecipe = null;
        print('RecipeProvider: Recipe deleted successfully');
      }
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error deleting recipe: $_error');
      success = false;
      captureException(e, stackTrace: StackTrace.current, hint: 'Error deleting recipe');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> toggleFavorite(String recipeId, String token) async {
    // ... (existing code without microtask - likely safe)
    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify UI that action started
    bool success = false;
    bool isCurrentlyFavorite = _favoriteRecipes.any((r) => r.id == recipeId) ||
        (_currentRecipe?.id == recipeId && _currentRecipe!.isFavorite);

    try {
      addBreadcrumb(
        message: isCurrentlyFavorite ? 'Removing recipe from favorites' : 'Adding recipe to favorites',
        category: 'recipe',
        data: {'recipeId': recipeId},
      );

      if (isCurrentlyFavorite) {
        success = await _recipeService.removeFromFavorites(recipeId, token);
        if (success) {
          _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId);
          if (_currentRecipe?.id == recipeId) {
            _currentRecipe = _currentRecipe!.copyWith(isFavorite: false);
          }
          print('RecipeProvider: Recipe removed from favorites');
        }
      } else {
        success = await _recipeService.addToFavorites(recipeId, token);
        if (success) {
          // Fetch the recipe details to add it properly if it's not the current one
          final recipeToAdd = (_currentRecipe?.id == recipeId)
              ? _currentRecipe!.copyWith(isFavorite: true)
              : await _recipeService.getRecipeById(recipeId, token); // Fetch details if needed

          if (_currentRecipe?.id == recipeId) {
            _currentRecipe = _currentRecipe!.copyWith(isFavorite: true);
          }
          if (!_favoriteRecipes.any((r) => r.id == recipeId)) {
            _favoriteRecipes.add(recipeToAdd); // Add the fetched/updated recipe
          }

          print('RecipeProvider: Recipe added to favorites');
        }
      }

      // Update the recipe in user recipes list if it exists there
      final userRecipeIndex = _userRecipes.indexWhere((recipe) => recipe.id == recipeId);
      if (userRecipeIndex >= 0) {
        // If it's the current recipe, update with its new favorite status
        if (_currentRecipe?.id == recipeId) {
          _userRecipes[userRecipeIndex] = _currentRecipe!;
        } else {
          // Otherwise, update the favorite status on the existing user recipe instance
          _userRecipes[userRecipeIndex] = _userRecipes[userRecipeIndex].copyWith(isFavorite: !isCurrentlyFavorite);
        }
      }
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error toggling favorite: $_error');
      success = false;
      captureException(e, stackTrace: StackTrace.current, hint: 'Error toggling recipe favorite status');
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify UI that action ended
    }
    return success;
  }

  Future<void> getFavoriteRecipes(String token) async {
    // ... (existing code without microtask - likely safe)
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      addBreadcrumb(message: 'Fetching favorite recipes', category: 'recipe');
      print('RecipeProvider: Fetching favorite recipes');
      final recipes = await _recipeService.getFavoriteRecipes(token);
      _favoriteRecipes = recipes;
      print('RecipeProvider: Got ${recipes.length} favorite recipes');
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching favorite recipes: $_error');
      captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching favorite recipes');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> shareRecipe() async {
    // ... (existing code without microtask - likely safe)
    if (_currentRecipe == null) {
      print('RecipeProvider: Cannot share, current recipe is null');
      _error = "No recipe selected to share.";
      notifyListeners();
      return;
    }
    _error = null;
    // Don't set isLoading for share? Or maybe a specific shareLoading state?
    notifyListeners();
    try {
      addBreadcrumb(message: 'Sharing recipe', category: 'recipe', data: {'title': _currentRecipe!.title});
      await _recipeService.shareRecipe(_currentRecipe!);
      print('RecipeProvider: Share action initiated successfully');
    } catch (e) {
      _error = "Could not share recipe: ${e.toString().replaceFirst("Exception: ", "")}";
      print('RecipeProvider: Error sharing recipe: $_error');
      captureException(e, stackTrace: StackTrace.current, hint: 'Error sharing recipe');
      notifyListeners(); // Notify if error
    }
  }

  Future<void> getTrendingRecipes({String? token}) async {
    // ... (existing code without microtask - likely safe)
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      addBreadcrumb(message: 'Fetching trending recipes', category: 'recipe');
      print('RecipeProvider: Fetching trending recipes');
      final recipes = await _recipeService.getPopularRecipes(token: token);
      _trendingRecipes = recipes;
      print('RecipeProvider: Got ${recipes.length} trending recipes');
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching trending recipes: $_error');
      _trendingRecipes = [];
      captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching trending recipes');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getAllCategories() async {
    // ... (existing code without microtask - likely safe)
    _error = null; // Reset error before fetch
    // Optionally set a loading state if needed
    try {
      addBreadcrumb(message: 'Fetching recipe categories', category: 'recipe');
      print('RecipeProvider: Fetching all recipe categories');
      final categoriesData = await _recipeService.getAllCategories();
      _categories = categoriesData.map((categoryData) {
        return RecipeCategory(
          id: categoryData['id'] as String? ?? 'unknown',
          name: categoryData['name'] as String? ?? 'Unnamed Category',
          description: categoryData['description'] as String? ?? '',
          icon: RecipeCategory.getCategoryIcon(categoryData['id'] as String? ?? ''),
          color: RecipeCategory.getCategoryColor(categoryData['id'] as String? ?? ''),
          count: categoryData['count'] as int? ?? 0,
        );
      }).toList();
      print('RecipeProvider: Got ${_categories.length} categories');
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching categories: $_error');
      _categories = []; // Clear categories on error
      captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching recipe categories');
    }
    notifyListeners(); // Notify after fetch/error
  }

  Future<void> getDiscoverRecipes({
    String? category, String? query, String sort = 'recent', String? token,
  }) async {
    // ... (existing code without microtask - likely safe)
    _isLoading = true;
    _error = null;
    _currentPage = 0;
    _hasMoreRecipes = true;
    _discoverRecipes = [];
    notifyListeners();
    try {
      addBreadcrumb(message: 'Fetching discover recipes', category: 'recipe', data: {'category': category, 'query': query, 'sort': sort});
      print('RecipeProvider: Fetching discover recipes');
      print('RecipeProvider: Category: $category, Query: $query, Sort: $sort');
      List<String>? tags;
      String? processedQuery = query;
      if (processedQuery != null && processedQuery.contains('#')) {
        final RegExp tagRegex = RegExp(r'#(\w+)');
        final matches = tagRegex.allMatches(processedQuery);
        if (matches.isNotEmpty) {
          tags = matches.map((m) => m.group(1)!).toList();
          processedQuery = processedQuery.replaceAll(tagRegex, '').trim();
          if (processedQuery.isEmpty) processedQuery = null;
        }
      }
      final recipes = await _recipeService.getDiscoverRecipes(category: category, tags: tags, sort: sort, limit: 20, offset: 0, token: token, query: processedQuery);
      _discoverRecipes = recipes;
      _hasMoreRecipes = recipes.length == 20;
      print('RecipeProvider: Got ${recipes.length} discover recipes');
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching discover recipes: $_error');
      _discoverRecipes = [];
      _hasMoreRecipes = false;
      captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching discover recipes');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreDiscoverRecipes({
    String? category, String? query, String sort = 'recent', String? token,
  }) async {
    // ... (existing code without microtask - likely safe)
    if (_isLoadingMore || !_hasMoreRecipes) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      _currentPage++;
      print('RecipeProvider: Loading more discover recipes (page: $_currentPage)');
      addBreadcrumb(message: 'Loading more discover recipes', category: 'recipe', data: {'page': _currentPage, 'category': category, 'query': query, 'sort': sort});
      List<String>? tags;
      String? processedQuery = query;
      if (processedQuery != null && processedQuery.contains('#')) {
        final RegExp tagRegex = RegExp(r'#(\w+)');
        final matches = tagRegex.allMatches(processedQuery);
        if (matches.isNotEmpty) {
          tags = matches.map((m) => m.group(1)!).toList();
          processedQuery = processedQuery.replaceAll(tagRegex, '').trim();
          if (processedQuery.isEmpty) processedQuery = null;
        }
      }
      final recipes = await _recipeService.getDiscoverRecipes(category: category, tags: tags, sort: sort, limit: 20, offset: _currentPage * 20, token: token, query: processedQuery);
      if (recipes.isEmpty) {
        _hasMoreRecipes = false;
      } else {
        _discoverRecipes.addAll(recipes);
        _hasMoreRecipes = recipes.length == 20;
      }
      print('RecipeProvider: Loaded ${recipes.length} more discover recipes');
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error loading more discover recipes: $_error');
      captureException(e, stackTrace: StackTrace.current, hint: 'Error loading more discover recipes');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> resetAndReloadDiscoverRecipes({
    String? category, String? query, String sort = 'recent', String? token,
  }) async {
    // ... (existing code - just calls getDiscoverRecipes)
    return getDiscoverRecipes(
      category: category,
      query: query,
      sort: sort,
      token: token,
    );
  }

  Future<List<Recipe>> getCategoryRecipes(
      String categoryId, {
        String sort = 'recent',
        int limit = 20,
        int offset = 0,
        String? token,
      }
      ) async {
    // ... (existing code without microtask - likely safe)
    try {
      addBreadcrumb(message: 'Fetching category recipes', category: 'recipe', data: {'categoryId': categoryId, 'sort': sort, 'limit': limit, 'offset': offset});
      print('RecipeProvider: Fetching category recipes: $categoryId');
      final recipes = await _recipeService.getCategoryRecipes(categoryId, sort: sort, limit: limit, offset: offset, token: token);
      print('RecipeProvider: Got ${recipes.length} category recipes');
      return recipes;
    } catch (e) {
      print('RecipeProvider: Error fetching category recipes: $e');
      captureException(e, stackTrace: StackTrace.current, hint: 'Error fetching category recipes');
      return [];
    }
  }

  void clearCurrentRecipe() {
    // ... (existing code without microtask - safe)
    _currentRecipe = null;
    _partialRecipe = null;
    _resetCancellationState();
    notifyListeners();
  }
}