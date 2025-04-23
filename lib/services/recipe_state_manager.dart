// lib/services/recipe_state_manager.dart
import 'dart:async';
import '../models/recipe.dart';

class RecipeGenerationState {
  final String requestId;
  double progress;
  Recipe? partialRecipe;
  Recipe? completeRecipe;
  String? error;
  bool cancelled;
  DateTime lastUpdated;
  int retryCount;
  bool completed;

  RecipeGenerationState({
    required this.requestId,
    this.progress = 0.0,
    this.partialRecipe,
    this.completeRecipe,
    this.error,
    this.cancelled = false,
    int retryCount = 0,
    bool completed = false,
  }) :
        lastUpdated = DateTime.now(),
        retryCount = retryCount,
        completed = completed;

  // Check if this state is recent enough to show instead of fetching new data
  bool get isRecent {
    final now = DateTime.now();
    final diff = now.difference(lastUpdated).inSeconds;
    // If completed or cancelled, it's always recent
    if (completed || cancelled) return true;
    // Otherwise, use a time-based freshness check
    // The higher the progress, the longer we can use cached data
    final maxAge = progress > 90 ? 30 : (progress > 50 ? 15 : 5);
    return diff < maxAge;
  }

  // Update progress and freshen timestamp
  void updateProgress(double newProgress) {
    progress = newProgress;
    lastUpdated = DateTime.now();
  }

  // Update with partial recipe
  void updatePartial(Recipe recipe) {
    partialRecipe = recipe;
    lastUpdated = DateTime.now();
  }

  // Mark as completed
  void markCompleted(Recipe recipe) {
    completeRecipe = recipe;
    progress = 100.0;
    completed = true;
    lastUpdated = DateTime.now();
  }
}

class RecipeStateManager {
  // In-memory cache of recipe generation states
  final Map<String, RecipeGenerationState> _states = {};

  // Stream controller for state updates that components can listen to
  final _stateStreamController = StreamController<RecipeGenerationState>.broadcast();
  Stream<RecipeGenerationState> get stateStream => _stateStreamController.stream;

  // Get the current state for a specific request
  RecipeGenerationState? getState(String requestId) {
    return _states[requestId];
  }

  // Initialize a new generation state
  RecipeGenerationState initializeState(String requestId) {
    final state = RecipeGenerationState(requestId: requestId);
    _states[requestId] = state;
    _stateStreamController.add(state);
    return state;
  }

  // Update the progress for a specific generation
  void updateProgress(String requestId, double progress) {
    if (!_states.containsKey(requestId)) {
      initializeState(requestId);
    }

    _states[requestId]!.updateProgress(progress);
    _stateStreamController.add(_states[requestId]!);
  }

  // Update with partial recipe data
  void updatePartialRecipe(String requestId, Recipe partialRecipe) {
    if (!_states.containsKey(requestId)) {
      initializeState(requestId);
    }

    _states[requestId]!.updatePartial(partialRecipe);
    _stateStreamController.add(_states[requestId]!);
  }

  // Mark a generation as completed
  void markCompleted(String requestId, Recipe completeRecipe) {
    if (!_states.containsKey(requestId)) {
      initializeState(requestId);
    }

    _states[requestId]!.markCompleted(completeRecipe);
    _stateStreamController.add(_states[requestId]!);

    // Cleanup after some time
    Timer(const Duration(minutes: 5), () {
      removeState(requestId);
    });
  }

  // Mark a generation as failed
  void markFailed(String requestId, String error) {
    if (!_states.containsKey(requestId)) {
      initializeState(requestId);
    }

    _states[requestId]!.error = error;
    _states[requestId]!.lastUpdated = DateTime.now();
    _stateStreamController.add(_states[requestId]!);

    // Cleanup after some time
    Timer(const Duration(minutes: 5), () {
      removeState(requestId);
    });
  }

  // Mark a generation as cancelled
  void markCancelled(String requestId) {
    if (!_states.containsKey(requestId)) {
      initializeState(requestId);
    }

    _states[requestId]!.cancelled = true;
    _states[requestId]!.lastUpdated = DateTime.now();
    _stateStreamController.add(_states[requestId]!);

    // Cleanup after some time
    Timer(const Duration(minutes: 5), () {
      removeState(requestId);
    });
  }

  // Increment retry count
  void incrementRetryCount(String requestId) {
    if (!_states.containsKey(requestId)) {
      initializeState(requestId);
    }

    _states[requestId]!.retryCount++;
    _states[requestId]!.lastUpdated = DateTime.now();
  }

  // Remove a state (for cleanup)
  void removeState(String requestId) {
    _states.remove(requestId);
  }

  // Clean up resources
  void dispose() {
    _stateStreamController.close();
  }
}