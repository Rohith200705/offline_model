// Chat Repository

import 'package:get_it/get_it.dart';
import 'chatbot.dart';
import '../../../core/services/image_processor.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/photo_models.dart';

class ChatRepository {
  final PhotoChatbot _chatbot = GetIt.instance<PhotoChatbot>();
  final ImageProcessor _processor = GetIt.instance<ImageProcessor>();
  final DatabaseService _db = DatabaseService.instance;

  Future<String> chat(String message) async {
    return await _chatbot.chat(message);
  }

  Future<String> askAboutPhoto(String question, ImageAnalysis analysis) async {
    return await _chatbot.askAboutPhoto(question, analysis);
  }

  Future<ImageAnalysis> analyzePhoto(String imagePath) async {
    return await _processor.analyzeImage(imagePath);
  }

  Future<List<ChatMessage>> getChatHistory() async {
    try {
      final history = await _db.getChatHistory();
      if (history.isNotEmpty) return history;
    } catch (_) {}
    return _chatbot.conversationHistory;
  }

  Future<void> clearChatHistory() async {
    _chatbot.clearMemory();
  }
}