// Stats Screen

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../domain/stats_repository.dart';
import '../../../../core/models/photo_models.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _repository = StatsRepository();
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
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
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
                    _buildOverviewCards(),
                    const SizedBox(height: AppConstants.spacingLG),
                    _buildCategoryChart(),
                    const SizedBox(height: AppConstants.spacingLG),
                    _buildCategoryPieChart(),
                    const SizedBox(height: AppConstants.spacingLG),
                    _buildRecentPhotos(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    if (_stats == null) return const SizedBox();
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      crossAxisSpacing: AppConstants.spacingMD,
      mainAxisSpacing: AppConstants.spacingMD,
      children: [
        StatCard(title: 'Total Photos', value: _stats!.totalPhotos.toString(), icon: Icons.photo_library),
        StatCard(title: 'Known Faces', value: _stats!.knownFaces.toString(), icon: Icons.face, color: Colors.orange),
        StatCard(title: 'People Identified', value: _stats!.totalPersons.toString(), icon: Icons.people, color: Colors.blue),
        StatCard(title: 'Scene Types', value: _stats!.totalScenes.toString(), icon: Icons.landscape, color: Colors.green),
        StatCard(title: 'Total Faces', value: _stats!.totalFaces.toString(), icon: Icons.face, color: Colors.purple),
        StatCard(title: 'Categories', value: _stats!.categories.length.toString(), icon: Icons.category, color: Colors.teal),
      ],
    );
  }

  Widget _buildCategoryChart() {
    if (_stats == null || _stats!.categories.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart,
        title: 'No category data',
        message: 'Organize photos to see statistics',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Photos by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppConstants.spacingMD),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (_stats!.categories.values.reduce((a, b) => a > b ? a : b) * 1.2).toDouble(),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final keys = _stats!.categories.keys.toList();
                          if (value.toInt() < keys.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                keys[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _stats!.categories.entries.toList().asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          color: AppConstants.primaryColor,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    if (_stats == null || _stats!.categories.isEmpty) return const SizedBox();

    final colors = [
      AppConstants.primaryColor,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppConstants.spacingMD),
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: _stats!.categories.entries.toList().asMap().entries.map((entry) {
                    final color = colors[entry.key % colors.length];
                    return PieChartSectionData(
                      value: entry.value.value.toDouble(),
                      title: '${entry.value.value}',
                      color: color,
                      radius: 80,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingMD),
            Wrap(
              spacing: AppConstants.spacingMD,
              runSpacing: AppConstants.spacingSM,
              children: _stats!.categories.entries.toList().asMap().entries.map((entry) {
                final color = colors[entry.key % colors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(entry.value.key, style: const TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPhotos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recently Organized', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppConstants.spacingMD),
            FutureBuilder<List<Photo>>(
              future: _repository.getRecentPhotos(20),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final photos = snapshot.data!;
                if (photos.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history,
                    title: 'No recent photos',
                    message: 'Organize photos to see history',
                  );
                }
                
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return ListTile(
                      leading: PhotoThumbnail(path: photo.path, size: 50),
                      title: Text(photo.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${photo.category} • ${photo.dateTaken ?? 'Unknown date'}'),
                      trailing: Text(photo.category),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}