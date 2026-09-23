// Organize Screen

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get_it/get_it.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../domain/photo_organizer.dart';
import '../../domain/organize_repository.dart';

class OrganizeScreen extends StatefulWidget {
  const OrganizeScreen({super.key});

  @override
  State<OrganizeScreen> createState() => _OrganizeScreenState();
}

class _OrganizeScreenState extends State<OrganizeScreen> {
  final _repository = OrganizeRepository();
  final _pathController = TextEditingController();
  
  String _selectedCategory = AppConstants.organizeCategories[0];
  bool _moveFiles = false;
  bool _organizing = false;
  double _progress = 0.0;
  String _currentFile = '';
  OrganizeResult? _result;
  String? _error;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        setState(() {
          _pathController.text = result;
        });
      }
    } catch (e) {
      _showError('Failed to pick directory: $e');
    }
  }

  Future<void> _startOrganizing() async {
    if (_pathController.text.isEmpty) {
      _showError('Please select a directory');
      return;
    }

    final directory = Directory(_pathController.text);
    if (!await directory.exists()) {
      _showError('Directory does not exist');
      return;
    }

    setState(() {
      _organizing = true;
      _progress = 0.0;
      _currentFile = '';
      _result = null;
      _error = null;
    });

    try {
      final category = _mapCategory(_selectedCategory);
      final result = await _repository.organizePhotos(
        _pathController.text,
        category,
        moveFiles: _moveFiles,
        onProgress: (progress, file) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _currentFile = file;
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _organizing = false;
          _result = result;
        });
        
        if (result.errors > 0) {
          _showWarning('Completed with ${result.errors} errors');
        } else {
          _showSuccess('Organization complete! ${result.organized} photos organized.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _organizing = false);
        _showError('Organization failed: $e');
      }
    }
  }

  OrganizeCategory _mapCategory(String category) {
    switch (category) {
      case 'Persons': return OrganizeCategory.persons;
      case 'Locations': return OrganizeCategory.locations;
      case 'Objects': return OrganizeCategory.objects;
      case 'Events': return OrganizeCategory.events;
      case 'Date': return OrganizeCategory.date;
      default: return OrganizeCategory.auto;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppConstants.errorColor),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppConstants.successColor),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppConstants.warningColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organize Photos')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDirectoryInput(),
                const SizedBox(height: AppConstants.spacingLG),
                _buildOptions(),
                const SizedBox(height: AppConstants.spacingLG),
                _buildOrganizeButton(),
                const SizedBox(height: AppConstants.spacingLG),
                if (_result != null) _buildResults(),
                const SizedBox(height: AppConstants.spacingLG),
                _buildSortedDirectory(),
              ],
            ),
          ),
          if (_organizing) _buildProgressOverlay(),
        ],
      ),
    );
  }

  Widget _buildDirectoryInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Photo Directory',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppConstants.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSM),
            TextField(
              controller: _pathController,
              decoration: InputDecoration(
                hintText: 'Enter path to your photos directory',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _pickDirectory,
                ),
              ),
              readOnly: true,
              onTap: _pickDirectory,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Options',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppConstants.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMD),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Organize by',
                border: OutlineInputBorder(),
              ),
              items: AppConstants.organizeCategories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: AppConstants.spacingMD),
            SwitchListTile(
              title: const Text('Move files (instead of copy)'),
              subtitle: const Text('Warning: This will move files from their original location'),
              value: _moveFiles,
              onChanged: (value) => setState(() => _moveFiles = value),
              activeThumbColor: AppConstants.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Organizing'),
        onPressed: _organizing ? null : _startOrganizing,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMD),
        ),
      ),
    );
  }

  Widget _buildProgressOverlay() {
    return LoadingOverlay(
      message: 'Analyzing and organizing photos...',
      progress: _progress,
    );
  }

  Widget _buildResults() {
    if (_result == null) return const SizedBox();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _result!.errors > 0 ? Icons.warning : Icons.check_circle,
                  color: _result!.errors > 0 ? AppConstants.warningColor : AppConstants.successColor,
                ),
                const SizedBox(width: AppConstants.spacingSM),
                Text(
                  _result!.errors > 0 ? 'Completed with errors' : 'Organization Complete',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMD),
            Row(
              children: [
                Expanded(child: _buildResultStat('Total Found', _result!.total)),
                Expanded(child: _buildResultStat('Organized', _result!.organized, AppConstants.successColor)),
                Expanded(child: _buildResultStat('Skipped', _result!.skipped, Colors.orange)),
                Expanded(child: _buildResultStat('Errors', _result!.errors, AppConstants.errorColor)),
              ],
            ),
            if (_result!.details.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingMD),
              const Text(
                'Details',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppConstants.spacingSM),
              ...(_result!.details.take(20).map((detail) => _buildDetailItem(detail))),
              if (_result!.details.length > 20)
                Padding(
                  padding: const EdgeInsets.only(top: AppConstants.spacingSM),
                  child: Text(
                    '... and ${_result!.details.length - 20} more',
                    style: TextStyle(color: AppConstants.textSecondary),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultStat(String label, int value, [Color? color]) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color ?? AppConstants.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDetailItem(OrganizeDetail detail) {
    final hasError = detail.error != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            hasError ? Icons.error : Icons.check,
            size: 16,
            color: hasError ? AppConstants.errorColor : AppConstants.successColor,
          ),
          const SizedBox(width: AppConstants.spacingSM),
          Expanded(
            child: Text(
              detail.file,
              style: TextStyle(
                fontSize: 12,
                color: hasError ? AppConstants.errorColor : AppConstants.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (detail.category != null) ...[
            const SizedBox(width: AppConstants.spacingSM),
            Chip(
              label: Text(detail.category!, style: const TextStyle(fontSize: 10)),
              backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSortedDirectory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sorted Photos Directory',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimary,
          ),
        ),
        const SizedBox(height: AppConstants.spacingMD),
        FutureBuilder<Map<String, int>>(
          future: _repository.getCategoryCounts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final counts = snapshot.data!;
            if (counts.isEmpty) {
              return const EmptyState(
                icon: Icons.folder_off,
                title: 'No organized photos yet',
                message: 'Organize your photos to see them here',
              );
            }
            
            return Column(
              children: counts.entries.map((entry) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(entry.key),
                    trailing: Text('${entry.value} photos'),
                    onTap: () => _openCategoryFolder(entry.key),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _openCategoryFolder(String category) {
    // TODO: Implement folder opening
  }
}