// providers/chat_provider.dart
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatProvider with ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  String? _suggestedRecipe;
  bool _canGenerateRecipe = false;

  final ChatService _chatService = ChatService();

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get suggestedRecipe => _suggestedRecipe;
  bool get canGenerateRecipe => _canGenerateRecipe;

  // Send a message to the AI chat assistant
  Future<void> sendMessage(String content) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Add user message immediately
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: MessageType.user,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    notifyListeners();

    try {
      final response = await _chatService.sendMessage(content);

      // Create AI message from response
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: response['reply'],
        type: MessageType.ai,
        timestamp: DateTime.now(),
        canGenerateRecipe: response['can_generate_recipe'],
        suggestedRecipe: response['suggested_recipe'],
      );

      _messages.add(aiMessage);
      _canGenerateRecipe = response['can_generate_recipe'];
      _suggestedRecipe = response['suggested_recipe'];
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear all messages
  void clearMessages() {
    _messages = [];
    _suggestedRecipe = null;
    _canGenerateRecipe = false;
    notifyListeners();
  }
}