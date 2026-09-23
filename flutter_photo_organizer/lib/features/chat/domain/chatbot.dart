// Chatbot Service

import 'package:image/image.dart' as img;
import '../models/photo_models.dart';
import '../database/database_service.dart';
import 'image_processor.dart';

class PhotoChatbot {
  final DatabaseService _db;
  final ImageProcessor _processor;
  final List<ChatMessage> _conversationHistory = [];

  PhotoChatbot({
    DatabaseService? database,
    ImageProcessor? processor,
  }) : _db = database ?? DatabaseService.instance,
       _processor = processor ?? ImageProcessorImpl();

  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);

  Future<String> chat(String message) async {
    // Add user message to history
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: message,
      timestamp: DateTime.now().toIso8601String(),
    );
    _conversationHistory.add(userMsg);
    await _db.storeChatMessage(userMsg);

    // Generate response
    final response = await _generateResponse(message);

    // Add assistant message to history
    final assistantMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch + 1,
      role: 'assistant',
      content: response,
      timestamp: DateTime.now().toIso8601String(),
    );
    _conversationHistory.add(assistantMsg);
    await _db.storeChatMessage(assistantMsg);

    return response;
  }

  Future<String> askAboutPhoto(String question, ImageAnalysis analysis) async {
    final context = _buildPhotoContext(analysis);
    final prompt = 'Photo analysis: $context\n\nQuestion: $question';
    return await _generateResponse(prompt);
  }

  Future<String> _generateResponse(String message) async {
    final msg = message.toLowerCase();
    final now = DateTime.now();
    final totalPhotos = await _db.getTotalPhotoCount();

    // Greeting
    if (msg.startsWith('hello') || msg.startsWith('hi') || msg.startsWith('hey')) {
      return _buildGreeting(totalPhotos, now);
    }

    // Help
    if (msg.contains('help')) {
      return _buildHelp();
    }

    // Stats
    if (msg.contains('how many') || msg.contains('total') || msg.contains('count') || msg.contains('stats')) {
      return await _buildStatsResponse(totalPhotos);
    }

    // Recent photos
    if (msg.contains('recent') || msg.contains('latest') || msg.contains('newest')) {
      return await _buildRecentPhotosResponse();
    }

    // Scenes
    if (msg.contains('scene') || msg.contains('type') || msg.contains('category') || 
        msg.contains('indoor') || msg.contains('outdoor') || msg.contains('beach') || 
        msg.contains('mountain')) {
      return await _buildScenesResponse();
    }

    // Locations
    if (msg.contains('location') || msg.contains('place') || msg.contains('where') || 
        msg.contains('city') || msg.contains('country')) {
      return await _buildLocationsResponse();
    }

    // People
    if (msg.contains('person') || msg.contains('people') || msg.contains('face') || 
        msg.contains('who') || msg.contains('recognize')) {
      return await _buildPeopleResponse();
    }

    // Date/Time
    if (msg.contains('today') || msg.contains('date') || msg.contains('day') || msg.contains('time')) {
      return 'Today is ${_formatDate(now)} at ${_formatTime(now)}.';
    }

    // Organize
    if (msg.contains('sort') || msg.contains('organize')) {
      return 'I can help organize photos. Use the Organize screen to start sorting your photos by persons, locations, objects, or events.';
    }

    // Thanks
    if (msg.contains('thank') || msg.contains('thanks') || msg.contains('nice')) {
      return "You're welcome! Let me know if you need anything else with your photos.";
    }

    // Default response
    return _buildDefaultResponse(totalPhotos);
  }

  String _buildGreeting(int totalPhotos, DateTime now) {
    return 'Hello! I\'m your photo assistant. It\'s ${_formatDate(now)}. '
        'I can help you explore your $totalPhotos photos. '
        'Try asking about people, places, or specific photos. Type "help" to see what I can do.';
  }

  String _buildHelp() {
    return 'I can help you with:\n'
        '• Find photos by person: "Show me photos with [name]"\n'
        '• Find photos by place: "Show photos from [location]"\n'
        '• Find photos by time: "Show photos from last month"\n'
        '• Photo stats: "How many photos do I have?"\n'
        '• Organize photos: "Organize my photos"\n'
        '• Recent photos: "Show recent photos"\n'
        '• Scene info: "What scenes are in my photos?"';
  }

  Future<String> _buildStatsResponse(int totalPhotos) async {
    final locations = await _db.getAllLocations();
    final faces = await _db.getAllFaces();
    final scenes = await _db.getAllScenes();
    
    final parts = <String>['You have $totalPhotos photos in your library.'];
    if (locations.isNotEmpty) {
      parts.add('They span ${locations.length} different locations.');
    }
    if (faces.isNotEmpty) {
      final known = faces.where((f) => f.name != 'unknown').length;
      parts.add('I\'ve identified $known different people.');
    }
    if (scenes.isNotEmpty) {
      parts.add('There are ${scenes.length} different scene types.');
    }
    return parts.join(' ');
  }

  Future<String> _buildRecentPhotosResponse() async {
    final photos = await _db.searchPhotos('', limit: 5);
    if (photos.isEmpty) {
      return 'No photos found in the database yet.';
    }
    
    final lines = <String>['Here are your most recent photos:'];
    for (final photo in photos) {
      final name = photo.filename;
      final date = photo.dateTaken ?? 'unknown date';
      lines.add('• $name ($date)');
    }
    return lines.join('\n');
  }

  Future<String> _buildScenesResponse() async {
    final scenes = await _db.getAllScenes();
    if (scenes.isEmpty) {
      return 'No scenes analyzed yet. Run the organizer first.';
    }
    
    final lines = <String>['Here are the scene types in your photos:'];
    for (final scene in scenes) {
      final count = await _db.countPhotosByScene(scene['name'] as String);
      lines.add('• ${scene['name']}: $count photos');
    }
    return lines.join('\n');
  }

  Future<String> _buildLocationsResponse() async {
    final locations = await _db.getAllLocations();
    if (locations.isEmpty) {
      return 'No locations found yet. Run the organizer first.';
    }
    
    final lines = <String>['Here are the locations in your photos:'];
    for (final loc in locations) {
      lines.add('• ${loc['name']} (${loc['photo_count']} photos)');
    }
    return lines.join('\n');
  }

  Future<String> _buildPeopleResponse() async {
    final faces = await _db.getAllFaces();
    if (faces.isEmpty) {
      return 'No faces identified yet. Run the organizer first.';
    }
    
    final lines = <String>['Here are the people I\'ve identified:'];
    for (final face in faces) {
      lines.add('• ${face.name} (${face.embeddingPaths.length} samples)');
    }
    return lines.join('\n');
  }

  String _buildDefaultResponse(int totalPhotos) {
    return 'I understand you\'re asking about photos. '
        'You currently have $totalPhotos photos in your library. '
        'Try asking about people, locations, scenes, or specific photos. '
        'Type "help" for a list of things I can do.';
  }

  String _buildPhotoContext(ImageAnalysis analysis) {
    final parts = <String>[];
    
    if (analysis.faces.isNotEmpty) {
      final names = analysis.faces.map((f) => f.name).where((n) => n != 'unknown').toSet();
      if (names.isNotEmpty) {
        parts.add('People: ${names.join(", ")}');
      }
    }
    
    if (analysis.scenes.isNotEmpty) {
      final sceneNames = analysis.scenes.take(3).map((s) => s.scene).toList();
      parts.add('Scene: ${sceneNames.join(", ")}');
    }
    
    if (analysis.objects.isNotEmpty) {
      final objNames = analysis.objects.take(5).map((o) => o.label).toList();
      parts.add('Objects: ${objNames.join(", ")}');
    }
    
    if (analysis.metadata?.date != null) {
      parts.add('Date: ${analysis.metadata!.date}');
    }
    
    return parts.join('; ');
  }

  String _formatDate(DateTime dt) {
    return '${_weekday(dt.weekday)}, ${_month(dt.month)} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  String _weekday(int day) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[day - 1];
  }

  String _month(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

  void clearMemory() {
    _conversationHistory.clear();
    _db.clearChatHistory();
  }

  void dispose() {
    _processor.dispose();
  }
}