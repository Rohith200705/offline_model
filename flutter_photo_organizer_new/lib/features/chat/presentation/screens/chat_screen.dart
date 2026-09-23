// Chat Screen

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/models/photo_models.dart';
import '../../domain/chat_repository.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repository = ChatRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  
  List<ChatMessage> _messages = [];
  bool _sending = false;
  ImageAnalysis? _currentPhotoAnalysis;
  String? _currentPhotoPath;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _repository.getChatHistory();
    if (mounted) {
      setState(() => _messages = history);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _sending = true);

    try {
      if (_currentPhotoAnalysis != null) {
        await _repository.askAboutPhoto(text, _currentPhotoAnalysis!);
      } else {
        await _repository.chat(text);
      }

      if (mounted) {
        await _loadHistory();
        setState(() {
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _showError('Failed to send message: $e');
      }
    }
  }

  Future<void> _pickAndAnalyzePhoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() {
        _currentPhotoPath = picked.path;
        _sending = true;
      });

      final analysis = await _repository.analyzePhoto(picked.path);
      
      if (mounted) {
        setState(() {
          _currentPhotoAnalysis = analysis;
          _sending = false;
        });
        
        _showPhotoAnalysisDialog(analysis);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _showError('Failed to analyze photo: $e');
      }
    }
  }

  void _clearPhotoAnalysis() {
    setState(() {
      _currentPhotoAnalysis = null;
      _currentPhotoPath = null;
    });
  }

  void _showPhotoAnalysisDialog(ImageAnalysis analysis) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildPhotoAnalysisSheet(analysis),
    );
  }

  Widget _buildPhotoAnalysisSheet(ImageAnalysis analysis) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(AppConstants.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Photo Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingMD),
              if (_currentPhotoPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  child: Image.file(
                    File(_currentPhotoPath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: AppConstants.spacingMD),
              _buildAnalysisSection('Faces', analysis.faces.map((f) => 
                '${f.name} (${(f.confidence * 100).toInt()}%)').toList()),
              _buildAnalysisSection('Scene', analysis.scenes.map((s) => 
                '${s.scene} (${(s.confidence * 100).toInt()}%)').toList()),
              _buildAnalysisSection('Objects', analysis.objects.map((o) => 
                '${o.label} (${(o.confidence * 100).toInt()}%)').toList()),
              if (analysis.metadata != null) ...[
                const SizedBox(height: AppConstants.spacingMD),
                _buildMetadataSection(analysis.metadata!),
              ],
              const SizedBox(height: AppConstants.spacingLG),
              const Divider(),
              const Text('Ask a question about this photo:'),
              const SizedBox(height: AppConstants.spacingSM),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'What is in this photo?',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalysisSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppConstants.spacingXS),
        Wrap(
          spacing: AppConstants.spacingSM,
          runSpacing: AppConstants.spacingXS,
          children: items.map((item) => Chip(
            label: Text(item, style: const TextStyle(fontSize: 12)),
            backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
          )).toList(),
        ),
        const SizedBox(height: AppConstants.spacingMD),
      ],
    );
  }

  Widget _buildMetadataSection(ImageMetadata metadata) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Metadata', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppConstants.spacingXS),
        if (metadata.date != null) Text('Date: ${metadata.date}'),
        if (metadata.camera != null) Text('Camera: ${metadata.camera}'),
        if (metadata.width != null && metadata.height != null) 
          Text('Dimensions: ${metadata.width}x${metadata.height}'),
        if (metadata.gpsLat != null && metadata.gpsLon != null) 
          Text('GPS: ${metadata.gpsLat!.toStringAsFixed(4)}, ${metadata.gpsLon!.toStringAsFixed(4)}'),
        const SizedBox(height: AppConstants.spacingMD),
      ],
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to clear all chat history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _repository.clearChatHistory();
              setState(() => _messages.clear());
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: AppConstants.errorColor)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppConstants.errorColor),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChat,
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_currentPhotoAnalysis != null) _buildPhotoPreview(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMD),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return ChatBubble(
                  message: msg.content,
                  isUser: msg.role == 'user',
                  time: _formatTime(msg.timestamp),
                );
              },
            ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.all(AppConstants.spacingMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppConstants.spacingSM),
                  Text('Thinking...'),
                ],
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMD),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (_currentPhotoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              child: Image.file(
                File(_currentPhotoPath!),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: AppConstants.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Analyzing photo...', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  _currentPhotoAnalysis!.filename,
                  style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _clearPhotoAnalysis,
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMD),
      decoration: BoxDecoration(
        color: AppConstants.cardColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _pickAndAnalyzePhoto,
            tooltip: 'Analyze Photo',
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Ask about your photos...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMD,
                  vertical: AppConstants.spacingSM,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: AppConstants.spacingSM),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sending ? null : _sendMessage,
            style: IconButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return '';
    }
  }
}