// lib/providers/recipe_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math; // For math.pow and math.min
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/recipe_category.dart';
import '../models/subscription.dart'; // Assuming this has SubscriptionInfo with recipeGenerationsRemaining
import '../services/recipe_service.dart';
import '../main.dart'; // Import for navigatorKey
import '../providers/subscription_provider.dart'; // Import for subscription provider
import '../widgets/common/upgrade_prompt_dialog.dart'; // NEW DIALOG
import '../config/sentry_config.dart'; // Import the Sentry config

class RecipeProvider with ChangeNotifier {
  Recipe? _currentRecipe;
  Recipe? _partialRecipe; // For storing partial recipe
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
  Timer? _pollingTimer; // Timer for polling recipe status
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
  Recipe? get partialRecipe => _partialRecipe;
  List<Recipe> get userRecipes => List.unmodifiable(_userRecipes);
  List<Recipe> get favoriteRecipes => List.unmodifiable(_favoriteRecipes);
  List<Recipe> get trendingRecipes => List.unmodifiable(_trendingRecipes);
  List<Recipe> get discoverRecipes => List.unmodifiable(_discoverRecipes);
  List<RecipeCategory> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreRecipes => _hasMoreRecipes;
  String? get error => _error;

  bool get isQueueActive => _isQueueActive;
  double get generationProgress => _generationProgress;

  void setCurrentRecipe(Recipe recipe) {
    if (kDebugMode) print("RecipeProvider: Setting current recipe: ${recipe.title} (ID: ${recipe.id})");
    _currentRecipe = recipe;
    _partialRecipe = null;
    _generationProgress = 1.0;
    _isLoading = false;
    _error = null;
    _resetCancellationState();
    notifyListeners();
  }

  Future<void> checkQueueStatus() async {
    try {
      addBreadcrumb(message: 'Checking recipe queue status', category: 'api');
      if (kDebugMode) print("RecipeProvider: Checking queue status...");
      _isQueueActive = await _recipeService.isUsingQueue();
      if (kDebugMode) print("RecipeProvider: Queue status check result: isQueueActive = $_isQueueActive");
    } catch (e, stackTrace) {
      if (kDebugMode) print("RecipeProvider: Error checking queue status: $e");
      captureException(e, stackTrace: stackTrace, hint: "Error checking recipe queue status");
      _isQueueActive = false;
    }
    notifyListeners();
  }

  void _startPollingForStatus(String requestId, Completer<Recipe?> completer) {
    if (_pollingTimer?.isActive ?? false) {
      _pollingTimer!.cancel();
      if (kDebugMode) print("RecipeProvider: Cancelled existing polling timer.");
    }
    if (kDebugMode) print("RecipeProvider: Starting polling for requestId: $requestId");
    _pollingErrorCount = 0;
    addBreadcrumb(message: 'Starting recipe status polling', category: 'recipe', data: {'requestId': requestId});
    const duration = Duration(milliseconds: 5000);

    _pollingTimer = Timer.periodic(duration, (timer) async {
      if (_wasCancelled || !_isLoading) {
        if (kDebugMode) print("RecipeProvider: Stopping polling timer (wasCancelled: $_wasCancelled, isLoading: $_isLoading)");
        timer.cancel();
        _pollingTimer = null;
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      try {
        if (_pollingErrorCount > 0) {
          await Future.delayed(Duration(milliseconds: math.min(_pollingErrorCount * 2000, 10000)));
        }
        if (kDebugMode) print("RecipeProvider: Polling status for $requestId...");
        final statusResult = await _recipeService.checkRecipeStatus(requestId);
        _pollingErrorCount = 0;

        Future.microtask(() {
          if (_wasCancelled || !_isLoading) {
            if (!completer.isCompleted) completer.complete(null);
            return;
          }
          Recipe? finalRecipe;
          bool isComplete = false;
          if (statusResult['status'] == 'completed' || (statusResult['status'] == null && (statusResult['title'] != null || statusResult['id'] != null))) {
            if (kDebugMode) print("RecipeProvider: Polling detected 'completed' or direct response.");
            isComplete = true;
            try {
              finalRecipe = Recipe.fromJson(statusResult);
              _currentRecipe = finalRecipe; _partialRecipe = null; _generationProgress = 1.0;
              addBreadcrumb(message: 'Recipe generation complete', category: 'recipe', data: {'title': finalRecipe.title});
            } catch (parseError, stackTrace) {
              _error = 'Error parsing completed recipe data';
              captureException(parseError, stackTrace: stackTrace, hint: 'Error parsing final recipe from polling');
              isComplete = false; finalRecipe = null;
            }
          } else if (statusResult['status'] != null) {
            final currentStatus = statusResult['status'];
            _generationProgress = (statusResult['progress'] as num? ?? _generationProgress * 100).toDouble() / 100.0;
            if (statusResult['partialRecipe'] is Map<String, dynamic>) {
              try {
                _partialRecipe = Recipe.fromJson(statusResult['partialRecipe'] as Map<String, dynamic>);
              } catch (parseError, stackTrace) {
                _partialRecipe = null;
                captureException(parseError, stackTrace: stackTrace, hint: 'Error parsing partial recipe from polling');
              }
            }
            if (currentStatus == 'failed' || currentStatus == 'error') {
              isComplete = true; _error = statusResult['message'] as String? ?? 'Recipe generation failed on server.';
            }
          } else { /* Unexpected format */ }

          if (isComplete) {
            timer.cancel(); _pollingTimer = null; _isLoading = false;
            if (!completer.isCompleted) completer.complete(finalRecipe);
          }
          notifyListeners();
        });
      } catch (e, stackTracePoller) {
        _pollingErrorCount++;
        Future.microtask(() {
          if (_wasCancelled || !_isLoading) { if (!completer.isCompleted) completer.complete(null); return; }
          bool shouldStopPolling = false; String? pollErrorMsg;
          if (e.toString().contains('Too many requests') || e.toString().contains('429')) {
            timer.cancel();
            final newDuration = Duration(milliseconds: math.min(5000 * math.pow(2, _pollingErrorCount).toInt(), 60000));
            _pollingTimer = Timer(newDuration, () => _startPollingForStatus(requestId, completer));
            return;
          } else if (e.toString().contains('cancelled') || e.toString().contains('499')) {
            _wasCancelled = true; pollErrorMsg = 'Recipe generation cancelled'; shouldStopPolling = true;
          } else if (e.toString().contains('404') || e.toString().contains('job not found')) {
            if (_pollingErrorCount > 3) { pollErrorMsg = 'Recipe generation status not found'; shouldStopPolling = true; }
          } else {
            if (_pollingErrorCount > 5) {
              pollErrorMsg = 'Error checking recipe status: ${e.toString().replaceFirst("Exception: ", "")}';
              shouldStopPolling = true;
            }
          }
          if (shouldStopPolling) {
            timer.cancel(); _pollingTimer = null; _isLoading = false;
            _error = pollErrorMsg ?? 'Polling failed.';
            captureException(e, stackTrace: stackTracePoller, hint: _error);
            if (!completer.isCompleted) completer.complete(null);
            notifyListeners();
          }
        });
      }
    });
  }

  Future<void> cancelRecipeGeneration() async {
    // ... (This method was modified for cancellation logic, keeping it as it was in your last full version)
    if (!_isLoading || _currentRequestId == null) {
      if (kDebugMode) print("RecipeProvider: Cannot cancel - not loading or no requestId");
      return;
    }
    _isCancelling = true;
    notifyListeners();
    addBreadcrumb(message: 'Attempting to cancel recipe generation', category: 'recipe', data: {'requestId': _currentRequestId});
    final requestIdToCancel = _currentRequestId;

    if (_pollingTimer?.isActive ?? false) _pollingTimer!.cancel();
    _pollingTimer = null;
    _currentRequestId = null;

    try {
      bool success = requestIdToCancel != null ? await _recipeService.cancelRecipeGeneration(requestIdToCancel) : true;
      Future.microtask(() {
        _wasCancelled = true; _isLoading = false; _isCancelling = false;
        _generationProgress = 0.0; _partialRecipe = null;
        if (success) {
          _error = 'Recipe generation cancelled';
          addBreadcrumb(message: 'Recipe generation cancelled successfully', category: 'recipe');
        } else {
          _error = 'Recipe generation cancelled (server may still be processing)';
          addBreadcrumb(message: 'Cancellation API call failed', category: 'recipe', level: SentryLevel.warning);
        }
        notifyListeners();
      });
    } catch (e, stackTrace) {
      Future.microtask(() {
        _wasCancelled = true; _error = 'Error during cancellation request';
        _isLoading = false; _isCancelling = false; _generationProgress = 0.0; _partialRecipe = null;
        captureException(e, stackTrace: stackTrace, hint: 'Error during recipe cancellation API call');
        notifyListeners();
      });
    }
  }

  void _resetCancellationState() {
    // ... (This method was part of the cancellation logic, keeping it)
    _isCancelling = false; _wasCancelled = false; _currentRequestId = null;
    _generationProgress = 0.0; _partialRecipe = null; _pollingErrorCount = 0;
    if (_pollingTimer?.isActive ?? false) _pollingTimer!.cancel();
    _pollingTimer = null;
  }

  Future<Recipe?> generateRecipe(String query, {bool save = false, String? token}) async {
    final BuildContext? context = navigatorKey.currentContext;
    final Completer<Recipe?> completer = Completer<Recipe?>();

    // --- Subscription Check (Primary change in this method) ---
    if (token != null && context != null && context.mounted) {
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      try {
        await subscriptionProvider.loadSubscriptionStatus(token); // Fetches backend status (limits)
        await subscriptionProvider.revenueCatSubscriptionStatus(token); // Fetches RevenueCat status (isPro)

        final subscriptionInfo = subscriptionProvider.subscriptionInfo; // From your backend
        final isProViaRevenueCat = subscriptionProvider.isProSubscriber; // From RevenueCat

        if (kDebugMode) {
          print("RecipeProvider: Subscription Check for recipe generation:");
          print("  Backend Tier: ${subscriptionInfo?.tier}, Recipe Gens Remaining: ${subscriptionInfo?.recipeGenerationsRemaining}");
          print("  RevenueCat isProSubscriber: $isProViaRevenueCat");
        }

        if (!isProViaRevenueCat && subscriptionInfo != null && subscriptionInfo.recipeGenerationsRemaining <= 0) {
          if (kDebugMode) {
            print("RecipeProvider: Free user has reached recipe generation limit. Showing UpgradePromptDialog.");
          }
          // ***** MODIFIED DIALOG CALL *****
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (ctx) => UpgradePromptDialog(
                titleText: 'Recipe Limit Reached',
                messageText: "You've used all your free recipe generations for this period. Upgrade to Pro for unlimited recipes!",
              ),
              barrierDismissible: false,
            );
          }
          // Ensure loading state is reset and completer is handled
          Future.microtask(() {
            _isLoading = false;
            _error = "Recipe generation limit reached."; // Set an error message
            notifyListeners();
          });
          if(!completer.isCompleted) completer.complete(null); // Complete with null as generation is stopped
          return completer.future; // Return the future from the completer
        }
      } catch (e, stackTrace) {
        if (kDebugMode) print("RecipeProvider: Error checking subscription status during generation: $e");
        captureException(e, stackTrace: stackTrace, hint: 'Error checking subscription status before recipe generation');
      }
    }
    // --- End Subscription check ---

    Future.microtask(() {
      _isLoading = true; _error = null; _resetCancellationState();
      notifyListeners();
    });

    addBreadcrumb(message: 'Starting recipe generation', category: 'recipe', data: {'query': query, 'save': save});

    try {
      await checkQueueStatus();

      if (_isQueueActive) {
        // ... (Queued generation logic as in your original file / my previous updates) ...
        if (kDebugMode) print("RecipeProvider: Using QUEUED generation path for query: $query");
        final requestResult = await _recipeService.startRecipeGeneration(query, save: save, token: token);
        Future.microtask(() {
          if(_wasCancelled && !completer.isCompleted) { completer.complete(null); return; }
          _currentRequestId = requestResult['requestId'];
          if (kDebugMode) print('RecipeProvider: Received requestId for polling: $_currentRequestId');
          if (_currentRequestId != null) {
            _startPollingForStatus(_currentRequestId!, completer);
          } else {
            _error = 'No request ID received for polling.'; _isLoading = false; notifyListeners();
            if (!completer.isCompleted) completer.complete(null);
          }
        });
      } else {
        // ... (Direct generation logic as in your original file / my previous updates) ...
        if (kDebugMode) print("RecipeProvider: Using DIRECT (non-queued) generation for query: $query");
        final recipe = await _recipeService.generateRecipe(query, save: save, token: token);
        Future.microtask(() {
          if (_wasCancelled && !completer.isCompleted) {
            _error = 'Recipe generation cancelled.'; _isLoading = false; notifyListeners();
            completer.complete(null); return;
          }
          _currentRecipe = recipe; _generationProgress = 1.0; _partialRecipe = null;
          _currentRequestId = recipe.requestId;
          if (save && token != null && recipe.id != null) {
            final existingIndex = _userRecipes.indexWhere((r) => r.id == recipe.id);
            if (existingIndex >= 0) _userRecipes[existingIndex] = recipe; else _userRecipes.add(recipe);
          }
          addBreadcrumb(message: 'Direct recipe generation complete', category: 'recipe', data: {'title': recipe.title});
          _isLoading = false; notifyListeners();
          if (!completer.isCompleted) completer.complete(recipe);
        });
      }
    } catch (e, stackTrace) {
      Future.microtask(() {
        String specificError = e.toString().replaceFirst("Exception: ", "");
        if (e.toString().contains('RECIPE_GENERATION_LIMIT_REACHED') || e.toString().contains('402')) {
          specificError = "You've reached your recipe generation limit for this period.";
        } else if (e.toString().contains('cancelled')) {
          _wasCancelled = true; specificError = 'Recipe generation cancelled';
        }
        _error = specificError;
        _isLoading = false;
        if (_pollingTimer?.isActive ?? false) _pollingTimer!.cancel(); _pollingTimer = null;
        captureException(e, stackTrace: stackTrace, hint: 'Error in generateRecipe main call: $_error');
        notifyListeners();
        if (!completer.isCompleted) completer.complete(null);
      });
    } finally {
      completer.future.whenComplete(() {
        Future.microtask(() {
          _isCancelling = false;
          if (_isLoading && !(_pollingTimer?.isActive ?? false) && !completer.isCompleted) {
            if (kDebugMode) print("RecipeProvider: Forcing isLoading=false after generateRecipe completion logic.");
            _isLoading = false;
          }
          notifyListeners();
        });
      });
    }
    return completer.future;
  }

  Future<Recipe?> fetchAndSetCurrentRecipe(String recipeId, String? token) async {
    // ... (This method seems to be from your original structure, keeping it)
    if (token == null) {
      if (kDebugMode) print("RecipeProvider: Cannot fetch recipe details - User not logged in.");
      _error = "Cannot load recipe details: Please log in.";
      notifyListeners();
      return null;
    }
    if (_currentRecipe?.id == recipeId && !_isLoading) { // Added !_isLoading check
      if (kDebugMode) print("RecipeProvider: Recipe $recipeId already set as current.");
      return _currentRecipe;
    }
    if (kDebugMode) print("RecipeProvider: Fetching and setting recipe by ID: $recipeId");
    _isLoading = true; _error = null; notifyListeners();
    try {
      final recipe = await _recipeService.getRecipeById(recipeId, token);
      setCurrentRecipe(recipe); // This sets _isLoading to false and notifies
      return recipe;
    } catch (e, stackTrace) {
      if (kDebugMode) print("RecipeProvider: Error fetching recipe by ID $recipeId: $e");
      _error = "Failed to load recipe details: ${e.toString().replaceFirst("Exception: ", "")}";
      _isLoading = false;
      captureException(e, stackTrace: stackTrace, hint: 'Error fetching recipe by ID $recipeId for chat view');
      notifyListeners();
      return null;
    }
  }

  // --- Keeping your original methods for user recipes, favorites, etc. ---
  // These methods will be restored to their original form as you provided them.
  // I'm assuming the structure from the file you uploaded for `recipe_provider.dart` for these.

  Future<void> getUserRecipes(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      addBreadcrumb(message: 'Fetching user recipes', category: 'recipe');
      if (kDebugMode) print('RecipeProvider: Fetching user recipes');
      final recipes = await _recipeService.getUserRecipes(token);
      _userRecipes = recipes;
      if (kDebugMode) print('RecipeProvider: Got ${recipes.length} user recipes');
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      if (kDebugMode) print('RecipeProvider: Error fetching user recipes: $_error');
      captureException(e, stackTrace: stackTrace, hint: 'Error fetching user recipes');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getRecipeById(String id, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      addBreadcrumb(message: 'Fetching recipe by ID', category: 'recipe', data: {'recipeId': id});
      if (kDebugMode) print('RecipeProvider: Fetching recipe by ID: $id');
      final recipe = await _recipeService.getRecipeById(id, token);
      _currentRecipe = recipe;
      if (kDebugMode) print('RecipeProvider: Successfully retrieved recipe: ${recipe.title}');
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      if (kDebugMode) print('RecipeProvider: Error fetching recipe by ID: $_error');
      captureException(e, stackTrace: stackTrace, hint: 'Error fetching recipe by ID');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRecipe(String recipeId, String token) async {
    // --- Maintaining original structure for this method ---
    _isLoading = true;
    _error = null;
    notifyListeners();
    bool success = false;
    try {
      addBreadcrumb(message: 'Deleting recipe', category: 'recipe', data: {'recipeId': recipeId});
      if (kDebugMode) print('RecipeProvider: Deleting recipe ID: $recipeId');
      success = await _recipeService.deleteRecipe(recipeId, token);
      if (success) {
        _userRecipes.removeWhere((recipe) => recipe.id == recipeId);
        _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId);
        if (_currentRecipe?.id == recipeId) _currentRecipe = null;
        if (kDebugMode) print('RecipeProvider: Recipe deleted successfully');
      }
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      if (kDebugMode) print('RecipeProvider: Error deleting recipe: $_error');
      success = false;
      captureException(e, stackTrace: stackTrace, hint: 'Error deleting recipe');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> toggleFavorite(String recipeId, String token) async {
    // --- Maintaining original structure for this method ---
    _isLoading = true;
    _error = null;
    // No notifyListeners() at the start of this original version
    bool success = false;
    // Determine if currently favorite based on _favoriteRecipes list or _currentRecipe
    bool isCurrentlyFavorite = _favoriteRecipes.any((r) => r.id == recipeId) || (_currentRecipe?.id == recipeId && _currentRecipe!.isFavorite);

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
          // Update in userRecipes list if present
          final userRecipeIndex = _userRecipes.indexWhere((recipe) => recipe.id == recipeId);
          if (userRecipeIndex != -1) {
            _userRecipes[userRecipeIndex] = _userRecipes[userRecipeIndex].copyWith(isFavorite: false);
          }
          if (kDebugMode) print('RecipeProvider: Recipe removed from favorites');
        }
      } else {
        success = await _recipeService.addToFavorites(recipeId, token);
        if (success) {
          // Find the recipe from userRecipes or currentRecipe to add to favorites
          Recipe? recipeToAdd;
          if (_currentRecipe?.id == recipeId) {
            recipeToAdd = _currentRecipe!.copyWith(isFavorite: true);
            _currentRecipe = recipeToAdd; // Update current recipe
          } else {
            final userRecipeIndex = _userRecipes.indexWhere((recipe) => recipe.id == recipeId);
            if (userRecipeIndex != -1) {
              _userRecipes[userRecipeIndex] = _userRecipes[userRecipeIndex].copyWith(isFavorite: true);
              recipeToAdd = _userRecipes[userRecipeIndex];
            } else {
              // If not in userRecipes or current, fetch it to add (might be from discover/trending)
              // This part might need to be more robust if recipe details aren't locally available
              try {
                recipeToAdd = await _recipeService.getRecipeById(recipeId, token); // Fetch full recipe
                recipeToAdd = recipeToAdd.copyWith(isFavorite: true);
              } catch(e) {
                if(kDebugMode) print('RecipeProvider: Could not fetch recipe $recipeId to add to favorites.');
              }
            }
          }

          if (recipeToAdd != null && !_favoriteRecipes.any((r) => r.id == recipeId)) {
            _favoriteRecipes.add(recipeToAdd);
          }
          if (kDebugMode) print('RecipeProvider: Recipe added to favorites');
        }
      }
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      if (kDebugMode) print('RecipeProvider: Error toggling favorite: $_error');
      success = false;
      captureException(e, stackTrace: stackTrace, hint: 'Error toggling recipe favorite status');
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify at the end
    }
    return success;
  }

  Future<void> getFavoriteRecipes(String token) async {
    // ... (Original implementation)
    _isLoading = true; _error = null; notifyListeners();
    try {
      addBreadcrumb(message: 'Fetching favorite recipes', category: 'recipe');
      if (kDebugMode) print('RecipeProvider: Fetching favorite recipes');
      final recipes = await _recipeService.getFavoriteRecipes(token);
      _favoriteRecipes = recipes;
      if (kDebugMode) print('RecipeProvider: Got ${recipes.length} favorite recipes');
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      captureException(e, stackTrace: stackTrace, hint: 'Error fetching favorite recipes');
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> shareRecipe() async {
    // ... (Original implementation)
    if (_currentRecipe == null) {
      _error = "No recipe selected to share."; notifyListeners(); return;
    }
    _error = null;
    try {
      addBreadcrumb(message: 'Sharing recipe', category: 'recipe', data: {'title': _currentRecipe!.title});
      await _recipeService.shareRecipe(_currentRecipe!);
      if (kDebugMode) print('RecipeProvider: Share action initiated successfully');
    } catch (e, stackTrace) {
      _error = "Could not share recipe: ${e.toString().replaceFirst("Exception: ", "")}";
      captureException(e, stackTrace: stackTrace, hint: 'Error sharing recipe');
      notifyListeners();
    }
  }

  Future<void> getTrendingRecipes({String? token}) async {
    // ... (Original implementation)
    _isLoading = true; _error = null; notifyListeners();
    try {
      addBreadcrumb(message: 'Fetching trending recipes', category: 'recipe');
      _trendingRecipes = await _recipeService.getPopularRecipes(token: token);
      if (kDebugMode) print('RecipeProvider: Got ${_trendingRecipes.length} trending recipes');
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      _trendingRecipes = [];
      captureException(e, stackTrace: stackTrace, hint: 'Error fetching trending recipes');
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> getAllCategories() async {
    // ... (Original implementation)
    _error = null;
    // No isLoading for this typically light call in original
    // notifyListeners(); // Not at start in original
    try {
      addBreadcrumb(message: 'Fetching recipe categories', category: 'recipe');
      final categoriesData = await _recipeService.getAllCategories();
      _categories = categoriesData.map((categoryData) {
        return RecipeCategory( // Assuming RecipeCategory.fromJson or similar constructor exists
          id: categoryData['id'] as String? ?? 'unknown',
          name: categoryData['name'] as String? ?? 'Unnamed Category',
          description: categoryData['description'] as String? ?? '',
          icon: RecipeCategory.getCategoryIcon(categoryData['id'] as String? ?? ''), // Assuming static helper
          color: RecipeCategory.getCategoryColor(categoryData['id'] as String? ?? ''), // Assuming static helper
          count: categoryData['count'] as int? ?? 0,
        );
      }).toList();
      if (kDebugMode) print('RecipeProvider: Got ${_categories.length} categories');
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      _categories = [];
      captureException(e, stackTrace: stackTrace, hint: 'Error fetching recipe categories');
    }
    notifyListeners(); // Notify at the end
  }

  Future<void> getDiscoverRecipes({ String? category, String? query, String sort = 'recent', String? token }) async {
    // ... (Original implementation)
    _isLoading = true; _error = null; _currentPage = 0; _hasMoreRecipes = true; _discoverRecipes = [];
    notifyListeners();
    try {
      addBreadcrumb(message: 'Fetching discover recipes', category: 'recipe', data: {'category': category, 'query': query, 'sort': sort});
      List<String>? tags; String? processedQuery = query;
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
      if (kDebugMode) print('RecipeProvider: Got ${_discoverRecipes.length} discover recipes');
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      _discoverRecipes = []; _hasMoreRecipes = false;
      captureException(e, stackTrace: stackTrace, hint: 'Error fetching discover recipes');
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> loadMoreDiscoverRecipes({ String? category, String? query, String sort = 'recent', String? token }) async {
    // ... (Original implementation)
    if (_isLoadingMore || !_hasMoreRecipes) return;
    _isLoadingMore = true; _error = null;
    notifyListeners();
    try {
      _currentPage++;
      addBreadcrumb(message: 'Loading more discover recipes', category: 'recipe', data: {'page': _currentPage, 'category': category, 'query': query, 'sort': sort});
      List<String>? tags; String? processedQuery = query;
      if (processedQuery != null && processedQuery.contains('#')) { /* tag logic */
        final RegExp tagRegex = RegExp(r'#(\w+)');
        final matches = tagRegex.allMatches(processedQuery);
        if (matches.isNotEmpty) {
          tags = matches.map((m) => m.group(1)!).toList();
          processedQuery = processedQuery.replaceAll(tagRegex, '').trim();
          if (processedQuery.isEmpty) processedQuery = null;
        }
      }
      final recipes = await _recipeService.getDiscoverRecipes(category: category, tags:tags, sort: sort, limit: 20, offset: _currentPage * 20, token: token, query: processedQuery);
      if (recipes.isEmpty) _hasMoreRecipes = false;
      else { _discoverRecipes.addAll(recipes); _hasMoreRecipes = recipes.length == 20; }
      if (kDebugMode) print('RecipeProvider: Loaded ${recipes.length} more discover recipes');
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      captureException(e, stackTrace: stackTrace, hint: 'Error loading more discover recipes');
    } finally {
      _isLoadingMore = false; notifyListeners();
    }
  }

  Future<void> resetAndReloadDiscoverRecipes({ String? category, String? query, String sort = 'recent', String? token }) async {
    // ... (Original implementation)
    await getDiscoverRecipes(category: category, query: query, sort: sort, token: token);
  }

  Future<List<Recipe>> getCategoryRecipes( String categoryId, { String sort = 'recent', int limit = 20, int offset = 0, String? token }) async {
    // ... (Original implementation)
    try {
      addBreadcrumb(message: 'Fetching category recipes', category: 'recipe', data: {'categoryId': categoryId, 'sort': sort, 'limit': limit, 'offset': offset});
      if (kDebugMode) print('RecipeProvider: Fetching category recipes: $categoryId');
      final recipes = await _recipeService.getCategoryRecipes(categoryId, sort: sort, limit: limit, offset: offset, token: token);
      if (kDebugMode) print('RecipeProvider: Got ${recipes.length} category recipes for $categoryId');
      return recipes;
    } catch (e, stackTrace) {
      if (kDebugMode) print('RecipeProvider: Error fetching category recipes for $categoryId: $e');
      captureException(e, stackTrace: stackTrace, hint: 'Error fetching category recipes for $categoryId');
      return [];
    }
  }

  void clearCurrentRecipe() {
    // ... (Original implementation)
    _currentRecipe = null;
    _partialRecipe = null;
    _resetCancellationState();
    notifyListeners();
  }
}