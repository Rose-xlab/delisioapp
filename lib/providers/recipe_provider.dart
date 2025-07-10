//delisio\lib\providers\recipe_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

import '../models/recipe.dart';
import '../models/recipe_category.dart';
import '../models/subscription.dart';
import '../services/recipe_service.dart';
import '../main.dart';
import '../providers/subscription_provider.dart';
import '../widgets/common/upgrade_prompt_dialog.dart';
import '../config/sentry_config.dart';

class RecipeProvider with ChangeNotifier {
  Recipe? _currentRecipe;
  Recipe? _partialRecipe;
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

  bool _isQueueActive = false;
  double _generationProgress = 0.0;
  Timer? _pollingTimer;
  int _pollingErrorCount = 0;

  bool _isCancelling = false;
  bool get isCancelling => _isCancelling;
  bool _wasCancelled = false;
  bool get wasCancelled => _wasCancelled;
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

  bool _mounted = true;

  @override
  void dispose() {
    _mounted = false;
    _pollingTimer?.cancel();
    // Cancel any other ongoing timers or stream subscriptions here
    super.dispose();
  }

  void _notifySafely() {
    if (!_mounted) return;

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle ||
        WidgetsBinding.instance.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mounted) notifyListeners();
      });
    }
  }

  void setCurrentRecipe(Recipe recipe) {
    if (kDebugMode) print("RecipeProvider: Setting current recipe: ${recipe.title} (ID: ${recipe.id})");
    _currentRecipe = recipe;
    _partialRecipe = null;
    _generationProgress = 1.0;
    _isLoading = false;
    _error = null;
    _resetCancellationState();
    _notifySafely();
  }

  Future<void> checkQueueStatus() async {
    try {
      addBreadcrumb(message: 'Checking recipe queue status', category: 'api');
      if (kDebugMode) print("RecipeProvider: Checking queue status...");
      _isQueueActive = await _recipeService.isUsingQueue();
      if (kDebugMode) print("RecipeProvider: Queue status check result: isQueueActive = $_isQueueActive");
    } catch (e, stackTrace) {
      if (kDebugMode) print("RecipeProvider: Error checking queue status: $e");
      captureException(e, stackTrace: stackTrace, hintText: "Error checking recipe queue status");
      _isQueueActive = false;
    }
    _notifySafely();
  }

  void _startPollingForStatus(String requestId, Completer<Recipe?> completer) {
    if (_pollingTimer?.isActive ?? false) {
      _pollingTimer!.cancel();
      if (kDebugMode) print("RecipeProvider: Cancelled existing polling timer.");
    }
    if (!_mounted) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    if (kDebugMode) print("RecipeProvider: Starting polling for requestId: $requestId");
    _pollingErrorCount = 0;
    addBreadcrumb(message: 'Starting recipe status polling', category: 'recipe', data: {'requestId': requestId});
    const duration = Duration(milliseconds: 5000);

    _pollingTimer = Timer.periodic(duration, (timer) async {
      if (!_mounted || _wasCancelled || !_isLoading) {
        if (kDebugMode) print("RecipeProvider: Stopping polling timer (mounted: $_mounted, wasCancelled: $_wasCancelled, isLoading: $_isLoading)");
        timer.cancel();
        _pollingTimer = null;
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      try {
        if (_pollingErrorCount > 0) {
          await Future.delayed(Duration(milliseconds: math.min(_pollingErrorCount * 2000, 10000)));
        }
        if (!_mounted) { timer.cancel(); _pollingTimer = null; if (!completer.isCompleted) completer.complete(null); return; }

        if (kDebugMode) print("RecipeProvider: Polling status for $requestId...");
        final statusResult = await _recipeService.checkRecipeStatus(requestId);
        _pollingErrorCount = 0;

        if (!_mounted) { timer.cancel(); _pollingTimer = null; if (!completer.isCompleted) completer.complete(null); return; }

        Future.microtask(() {
          if (!_mounted || _wasCancelled || !_isLoading) {
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
              captureException(parseError, stackTrace: stackTrace, hintText: 'Error parsing final recipe from polling');
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
                captureException(parseError, stackTrace: stackTrace, hintText: 'Error parsing partial recipe from polling');
              }
            }
            if (currentStatus == 'failed' || currentStatus == 'error') {
              isComplete = true; _error = statusResult['message'] as String? ?? 'Recipe generation failed on server.';
            }
          }

          if (isComplete) {
            timer.cancel(); _pollingTimer = null; _isLoading = false;
            if (!completer.isCompleted) completer.complete(finalRecipe);
          }
          _notifySafely();
        });
      } catch (e, stackTracePoller) {
        _pollingErrorCount++;
        if (!_mounted) { timer.cancel(); _pollingTimer = null; if (!completer.isCompleted) completer.complete(null); return; }

        Future.microtask(() {
          if (!_mounted || _wasCancelled || !_isLoading) { if (!completer.isCompleted) completer.complete(null); return; }
          bool shouldStopPolling = false; String? pollErrorMsg;
          if (e.toString().contains('Too many requests') || e.toString().contains('429')) {
            timer.cancel();
            final newDuration = Duration(milliseconds: math.min(5000 * math.pow(2, _pollingErrorCount).toInt(), 60000));
            _pollingTimer = Timer(newDuration, () { if(_mounted) _startPollingForStatus(requestId, completer); });
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
            captureException(e, stackTrace: stackTracePoller, hintText: _error);
            if (!completer.isCompleted) completer.complete(null);
            _notifySafely();
          }
        });
      }
    });
  }

  Future<void> cancelRecipeGeneration() async {
    if (!_isLoading || _currentRequestId == null) {
      if (kDebugMode) print("RecipeProvider: Cannot cancel - not loading or no requestId");
      return;
    }
    _isCancelling = true;
    _notifySafely();
    addBreadcrumb(message: 'Attempting to cancel recipe generation', category: 'recipe', data: {'requestId': _currentRequestId});
    final requestIdToCancel = _currentRequestId;

    if (_pollingTimer?.isActive ?? false) _pollingTimer!.cancel();
    _pollingTimer = null;
    _currentRequestId = null;

    try {
      bool success = requestIdToCancel != null ? await _recipeService.cancelRecipeGeneration(requestIdToCancel) : true;
      Future.microtask(() {
        if(!_mounted) return;
        _wasCancelled = true; _isLoading = false; _isCancelling = false;
        _generationProgress = 0.0; _partialRecipe = null;
        if (success) {
          _error = 'Recipe generation cancelled';
          addBreadcrumb(message: 'Recipe generation cancelled successfully', category: 'recipe');
        } else {
          _error = 'Recipe generation cancelled (server may still be processing)';
          addBreadcrumb(message: 'Cancellation API call failed', category: 'recipe', level: SentryLevel.warning);
        }
        _notifySafely();
      });
    } catch (e, stackTrace) {
      Future.microtask(() {
        if(!_mounted) return;
        _wasCancelled = true; _error = 'Error during cancellation request';
        _isLoading = false; _isCancelling = false; _generationProgress = 0.0; _partialRecipe = null;
        captureException(e, stackTrace: stackTrace, hintText: 'Error during recipe cancellation API call');
        _notifySafely();
      });
    }
  }

  void _resetCancellationState() {
    _isCancelling = false; _wasCancelled = false; _currentRequestId = null;
    _generationProgress = 0.0; _partialRecipe = null; _pollingErrorCount = 0;
    if (_pollingTimer?.isActive ?? false) _pollingTimer!.cancel();
    _pollingTimer = null;
  }

  Future<Recipe?> generateRecipe(
      String query, {
        bool save = false,
        String? token,
        String? conversationId,
      }) async {
    final BuildContext? context = navigatorKey.currentContext;
    final Completer<Recipe?> completer = Completer<Recipe?>();

    if (token != null && context != null && context.mounted) {
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      try {
        await subscriptionProvider.loadSubscriptionStatus(token);
        await subscriptionProvider.revenueCatSubscriptionStatus(token);
        final subscriptionInfo = subscriptionProvider.subscriptionInfo;
        final isProViaRevenueCat = subscriptionProvider.isProSubscriber;

        if (kDebugMode) { /* ... */ }

        if (!isProViaRevenueCat && subscriptionInfo != null && subscriptionInfo.recipeGenerationsRemaining <= 0) {
          if (kDebugMode) { /* ... */ }
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
          Future.microtask(() {
            if (!_mounted) return;
            _isLoading = false;
            _error = "Recipe generation limit reached.";
            _notifySafely();
          });
          if(!completer.isCompleted) completer.complete(null);
          return completer.future;
        }
      } catch (e, stackTrace) {
        if (kDebugMode) print("RecipeProvider: Error checking subscription status during generation: $e");
        captureException(e, stackTrace: stackTrace, hintText: 'Error checking subscription status before recipe generation');
      }
    }

    Future.microtask(() {
      if (!_mounted) return;
      _isLoading = true; _error = null; _resetCancellationState();
      _notifySafely();
    });

    addBreadcrumb(message: 'Starting recipe generation', category: 'recipe', data: {'query': query, 'save': save, 'conversationId': conversationId});

    try {
      await checkQueueStatus();
      if (!_mounted) { if(!completer.isCompleted) completer.complete(null); return completer.future; }

      if (_isQueueActive) {
        final requestResult = await _recipeService.startRecipeGeneration(query, save: save, token: token);
        Future.microtask(() {
          if(!_mounted) { if (!completer.isCompleted) completer.complete(null); return; }
          if(_wasCancelled && !completer.isCompleted) { completer.complete(null); return; }
          _currentRequestId = requestResult['requestId'];
          if (_currentRequestId != null) {
            if (_mounted) _startPollingForStatus(_currentRequestId!, completer);
          } else {
            _error = 'No request ID received for polling.'; _isLoading = false; _notifySafely();
            if (!completer.isCompleted) completer.complete(null);
          }
        });
      } else {
        final recipe = await _recipeService.generateRecipe(query, save: save, token: token);
        Future.microtask(() {
          if(!_mounted) { if (!completer.isCompleted) completer.complete(null); return; }
          if (_wasCancelled && !completer.isCompleted) { _error = 'Recipe generation cancelled.'; _isLoading = false; _notifySafely(); completer.complete(null); return; }
          _currentRecipe = recipe; _generationProgress = 1.0; _partialRecipe = null;
          _currentRequestId = recipe.requestId;
          if (save && token != null && recipe.id != null) {
            final existingIndex = _userRecipes.indexWhere((r) => r.id == recipe.id);
            if (existingIndex >= 0) _userRecipes[existingIndex] = recipe; else _userRecipes.add(recipe);
          }
          addBreadcrumb(message: 'Direct recipe generation complete', category: 'recipe', data: {'title': recipe.title});
          _isLoading = false; _notifySafely();
          if (!completer.isCompleted) completer.complete(recipe);
        });
      }
    } catch (e, stackTrace) {
      Future.microtask(() {
        if(!_mounted) { if (!completer.isCompleted) completer.complete(null); return; }
        String specificError = e.toString().replaceFirst("Exception: ", "");
        if (e.toString().contains('RECIPE_GENERATION_LIMIT_REACHED') || e.toString().contains('402')) {
          specificError = "You've reached your recipe generation limit for this period.";
        } else if (e.toString().contains('cancelled')) {
          _wasCancelled = true; specificError = 'Recipe generation cancelled';
        }
        _error = specificError;
        _isLoading = false;
        if (_pollingTimer?.isActive ?? false) _pollingTimer!.cancel(); _pollingTimer = null;
        captureException(e, stackTrace: stackTrace, hintText: 'Error in generateRecipe main call: $_error');
        _notifySafely();
        if (!completer.isCompleted) completer.complete(null);
      });
    } finally {
      completer.future.whenComplete(() {
        Future.microtask(() {
          if(!_mounted) return;
          _isCancelling = false;
          if (_isLoading && !(_pollingTimer?.isActive ?? false) && !completer.isCompleted) {
            _isLoading = false;
          }
          _notifySafely();
        });
      });
    }
    return completer.future;
  }

  Future<Recipe?> fetchAndSetCurrentRecipe(String recipeId, String? token) async {
    if (token == null) { _error = "Cannot load recipe details: Please log in."; _notifySafely(); return null; }
    if (_currentRecipe?.id == recipeId && !_isLoading) return _currentRecipe;
    _isLoading = true; _error = null; _notifySafely();
    try {
      final recipe = await _recipeService.getRecipeById(recipeId, token);
      setCurrentRecipe(recipe);
      return recipe;
    } catch (e, stackTrace) {
      _error = "Failed to load recipe details: ${e.toString().replaceFirst("Exception: ", "")}";
      _isLoading = false;
      captureException(e, stackTrace: stackTrace, hintText: 'Error fetching recipe by ID $recipeId for chat view');
      _notifySafely();
      return null;
    }
  }

  Future<void> getUserRecipes(String token) async {
    _isLoading = true; _error = null; _notifySafely();
    try {
      final recipes = await _recipeService.getUserRecipes(token);
      _userRecipes = recipes;
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      captureException(e, stackTrace: stackTrace, hintText: 'Error fetching user recipes');
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> getRecipeById(String id, String token) async {
    _isLoading = true; _error = null; _notifySafely();
    try {
      final recipe = await _recipeService.getRecipeById(id, token);
      _currentRecipe = recipe;
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      captureException(e, stackTrace: stackTrace, hintText: 'Error fetching recipe by ID');
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<bool> deleteRecipe(String recipeId, String token) async {
    _isLoading = true; _error = null; _notifySafely();
    bool success = false;
    try {
      success = await _recipeService.deleteRecipe(recipeId, token);
      if (success) {
        _userRecipes.removeWhere((recipe) => recipe.id == recipeId);
        _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId);
        if (_currentRecipe?.id == recipeId) _currentRecipe = null;
      }
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", ""); success = false;
      captureException(e, stackTrace: stackTrace, hintText: 'Error deleting recipe');
    } finally {
      _isLoading = false; _notifySafely();
    }
    return success;
  }

  Future<bool> toggleFavorite(String recipeId, String token) async {
    _isLoading = true; _error = null;
    bool success = false;
    bool isCurrentlyFavorite = _favoriteRecipes.any((r) => r.id == recipeId) || (_currentRecipe?.id == recipeId && _currentRecipe!.isFavorite);

    try {
      addBreadcrumb(message: isCurrentlyFavorite ? 'Removing recipe from favorites' : 'Adding recipe to favorites', category: 'recipe', data: {'recipeId': recipeId});
      if (isCurrentlyFavorite) {
        success = await _recipeService.removeFromFavorites(recipeId, token);
        if (success) {
          _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId);
          if (_currentRecipe?.id == recipeId) {
            _currentRecipe = _currentRecipe!.copyWith(isFavorite: false);
          }
          final userRecipeIndex = _userRecipes.indexWhere((recipe) => recipe.id == recipeId);
          if (userRecipeIndex != -1) {
            _userRecipes[userRecipeIndex] = _userRecipes[userRecipeIndex].copyWith(isFavorite: false);
          }
        }
      } else {
        success = await _recipeService.addToFavorites(recipeId, token);
        if (success) {
          Recipe? recipeToAdd;
          if (_currentRecipe?.id == recipeId) {
            recipeToAdd = _currentRecipe!.copyWith(isFavorite: true);
            _currentRecipe = recipeToAdd;
          } else {
            final userRecipeIndex = _userRecipes.indexWhere((recipe) => recipe.id == recipeId);
            if (userRecipeIndex != -1) {
              _userRecipes[userRecipeIndex] = _userRecipes[userRecipeIndex].copyWith(isFavorite: true);
              recipeToAdd = _userRecipes[userRecipeIndex];
            } else {
              try {
                recipeToAdd = await _recipeService.getRecipeById(recipeId, token);
                recipeToAdd = recipeToAdd.copyWith(isFavorite: true);
              } catch(e) {
                if(kDebugMode) print('RecipeProvider: Could not fetch recipe $recipeId to add to favorites.');
              }
            }
          }
          if (recipeToAdd != null && !_favoriteRecipes.any((r) => r.id == recipeId)) {
            _favoriteRecipes.add(recipeToAdd);
          }
        }
      }
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", ""); success = false;
      captureException(e, stackTrace: stackTrace, hintText: 'Error toggling recipe favorite status');
    } finally {
      _isLoading = false;
      _notifySafely();
    }
    return success;
  }

  Future<void> getFavoriteRecipes(String token) async {
    _isLoading = true; _error = null; _notifySafely();
    try {
      final recipes = await _recipeService.getFavoriteRecipes(token);
      _favoriteRecipes = recipes;
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      captureException(e, stackTrace: stackTrace, hintText: 'Error fetching favorite recipes');
    } finally {
      _isLoading = false; _notifySafely();
    }
  }

  Future<void> shareRecipe() async {
    if (_currentRecipe == null) { _error = "No recipe selected to share."; _notifySafely(); return; }
    _error = null;
    try {
      await _recipeService.shareRecipe(_currentRecipe!);
    } catch (e, stackTrace) {
      _error = "Could not share recipe: ${e.toString().replaceFirst("Exception: ", "")}";
      captureException(e, stackTrace: stackTrace, hintText: 'Error sharing recipe');
      _notifySafely();
    }
  }

  Future<void> getTrendingRecipes({String? token}) async {
    _isLoading = true; _error = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(_mounted) notifyListeners();
    });

    try {
      addBreadcrumb(message: 'Fetching trending recipes', category: 'recipe');
      _trendingRecipes = await _recipeService.getPopularRecipes(token: token);
      if (kDebugMode) print('RecipeProvider: Got ${_trendingRecipes.length} trending recipes');
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      _trendingRecipes = [];
      captureException(e, stackTrace: stackTrace, hintText: 'Error fetching trending recipes');
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mounted) notifyListeners();
      });
    }
  }

  Future<void> getAllCategories() async {
    _error = null;
    try {
      addBreadcrumb(message: 'Fetching recipe categories', category: 'recipe');
      final categoriesData = await _recipeService.getAllCategories();
      // Assuming categoriesData is List<Map<String, dynamic>>
      _categories = categoriesData.map((categoryData) {
        // Ensure the RecipeCategory constructor matches the parameters being passed.
        // The errors suggest a mismatch here or that the analyzer is mistaken.
        // Based on your RecipeCategory model, this call *should* be correct.
        // If errors persist after cleaning project, the issue might be subtle or elsewhere.
        return RecipeCategory(
          id: categoryData['id'] as String? ?? 'unknown',
          name: categoryData['name'] as String? ?? 'Unnamed Category',
          description: categoryData['description'] as String? ?? '',
          icon: RecipeCategory.getCategoryIcon(categoryData['id'] as String? ?? ''),
          color: RecipeCategory.getCategoryColor(categoryData['id'] as String? ?? ''),
          count: categoryData['count'] as int? ?? 0,
        );
      }).toList();
      if (kDebugMode) print('RecipeProvider: Got ${_categories.length} categories');
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      _categories = [];
      captureException(e, stackTrace: stackTrace, hintText: 'Error fetching recipe categories');
    }
    _notifySafely();
  }

  Future<void> getDiscoverRecipes({ String? category, String? query, String sort = 'recent', String? token }) async {
    _isLoading = true; _error = null; _currentPage = 0; _hasMoreRecipes = true; _discoverRecipes = [];
    _notifySafely();
    try {
      addBreadcrumb(message: 'Fetching discover recipes', category: 'recipe', data: {'category': category, 'query': query, 'sort': sort});
      List<String>? tags; String? processedQuery = query;
      if (processedQuery != null && processedQuery.contains('#')) { /* ... */ }
      final recipes = await _recipeService.getDiscoverRecipes(category: category, tags: tags, sort: sort, limit: 20, offset: 0, token: token, query: processedQuery);
      _discoverRecipes = recipes;
      _hasMoreRecipes = recipes.length == 20;
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      _discoverRecipes = []; _hasMoreRecipes = false;
      captureException(e, stackTrace: stackTrace, hintText: 'Error fetching discover recipes');
    } finally {
      _isLoading = false; _notifySafely();
    }
  }

  Future<void> loadMoreDiscoverRecipes({ String? category, String? query, String sort = 'recent', String? token }) async {
    if (_isLoadingMore || !_hasMoreRecipes) return;
    _isLoadingMore = true; _error = null;
    _notifySafely();
    try {
      _currentPage++;
      addBreadcrumb(message: 'Loading more discover recipes', category: 'recipe', data: {'page': _currentPage /*...*/});
      List<String>? tags; String? processedQuery = query;
      if (processedQuery != null && processedQuery.contains('#')) { /* ... */ }
      final recipes = await _recipeService.getDiscoverRecipes(category: category, tags:tags, sort: sort, limit: 20, offset: _currentPage * 20, token: token, query: processedQuery);
      if (recipes.isEmpty) _hasMoreRecipes = false;
      else { _discoverRecipes.addAll(recipes); _hasMoreRecipes = recipes.length == 20; }
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      captureException(e, stackTrace: stackTrace, hintText: 'Error loading more discover recipes');
    } finally {
      _isLoadingMore = false; _notifySafely();
    }
  }

  Future<void> resetAndReloadDiscoverRecipes({ String? category, String? query, String sort = 'recent', String? token }) async {
    await getDiscoverRecipes(category: category, query: query, sort: sort, token: token);
  }

  Future<List<Recipe>> getCategoryRecipes( String categoryId, { String sort = 'recent', int limit = 20, int offset = 0, String? token }) async {
    try {
      addBreadcrumb(message: 'Fetching category recipes', category: 'recipe', data: {'categoryId': categoryId /*...*/});
      final recipes = await _recipeService.getCategoryRecipes(categoryId, sort: sort, limit: limit, offset: offset, token: token);
      return recipes;
    } catch (e, stackTrace) {
      captureException(e, stackTrace: stackTrace, hintText: 'Error fetching category recipes for $categoryId');
      return [];
    }
  }

  void clearCurrentRecipe() {
    _currentRecipe = null;
    _partialRecipe = null;
    _resetCancellationState();
    _notifySafely();
  }
}