// Home Screen

import 'package:flutter/material.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/models/photo_models.dart';
import '../../domain/home_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = HomeRepository();
  AppStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final stats = await _repository.getStats();
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(),
                    const SizedBox(height: AppConstants.spacingLG),
                    _buildFeaturesSection(),
                    const SizedBox(height: AppConstants.spacingLG),
                    _buildQuickStartSection(),
                    const SizedBox(height: AppConstants.spacingLG),
                    _buildPrivacyNotice(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    if (_stats == null) return const SizedBox();
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      crossAxisSpacing: AppConstants.spacingMD,
      mainAxisSpacing: AppConstants.spacingMD,
      children: [
        StatCard(
          title: 'Total Photos',
          value: _stats!.totalPhotos.toString(),
          icon: Icons.photo_library,
        ),
        StatCard(
          title: 'Known Faces',
          value: _stats!.knownFaces.toString(),
          icon: Icons.face,
          color: Colors.orange,
        ),
        StatCard(
          title: 'Categories',
          value: _stats!.categories.length.toString(),
          icon: Icons.category,
          color: Colors.green,
        ),
        StatCard(
          title: 'Storage',
          value: '~1-2 GB',
          icon: Icons.storage,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Features',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimary,
          ),
        ),
        const SizedBox(height: AppConstants.spacingMD),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          crossAxisSpacing: AppConstants.spacingMD,
          mainAxisSpacing: AppConstants.spacingMD,
          children: [
            FeatureCard(
              title: 'Auto-Organize',
              description: 'Sort by persons, locations, objects, or events',
              icon: Icons.auto_awesome,
              color: AppConstants.primaryColor,
              onTap: () => _navigateToTab(1),
            ),
            FeatureCard(
              title: 'Smart Detection',
              description: 'Face recognition, scene classification, object detection',
              icon: Icons.psychology,
              color: Colors.blue,
              onTap: () => _navigateToTab(1),
            ),
            FeatureCard(
              title: 'Chat Assistant',
              description: 'Ask questions about your photos',
              icon: Icons.chat,
              color: Colors.green,
              onTap: () => _navigateToTab(2),
            ),
            FeatureCard(
              title: 'Privacy First',
              description: '100% offline - your data never leaves your device',
              icon: Icons.security,
              color: Colors.purple,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Start',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimary,
          ),
        ),
        const SizedBox(height: AppConstants.spacingMD),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMD),
            child: Column(
              children: [
                _buildStep(1, 'Setup', 'Download required models on first run'),
                _buildDivider(),
                _buildStep(2, 'Organize', 'Go to Organize tab and select your photo directory'),
                _buildDivider(),
                _buildStep(3, 'Chat', 'Use Chat tab to ask questions about your photos'),
                _buildDivider(),
                _buildStep(4, 'Manage', 'Add known faces in the Faces tab'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(int number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppConstants.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Container(
        height: 20,
        width: 1,
        color: Colors.grey.shade300,
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Card(
      color: AppConstants.primaryColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMD),
        child: Row(
          children: [
            const Icon(Icons.lock, color: AppConstants.primaryColor, size: 28),
            const SizedBox(width: AppConstants.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '100% Offline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                  Text(
                    'All processing happens locally on your device. No internet connection required. Your photos and data stay private.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTab(int index) {
    // This would be handled by the parent MainNavigationScreen
    // For now, we'll use a callback or state management
  }
}