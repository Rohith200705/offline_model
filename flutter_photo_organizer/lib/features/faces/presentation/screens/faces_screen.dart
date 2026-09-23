// Faces Screen

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_it/get_it.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../domain/faces_repository.dart';

class FacesScreen extends StatefulWidget {
  const FacesScreen({super.key});

  @override
  State<FacesScreen> createState() => _FacesScreenState();
}

class _FacesScreenState extends State<FacesScreen> {
  final _repository = FacesRepository();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  
  List<KnownFace> _knownFaces = [];
  bool _loading = true;
  bool _adding = false;
  String? _selectedPhotoPath;
  File? _testPhoto;

  @override
  void initState() {
    super.initState();
    _loadFaces();
  }

  Future<void> _loadFaces() async {
    setState(() => _loading = true);
    try {
      final faces = await _repository.getKnownFaces();
      if (mounted) {
        setState(() {
          _knownFaces = faces;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFacePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedPhotoPath = picked.path);
    }
  }

  Future<void> _addPerson() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter a name');
      return;
    }
    if (_selectedPhotoPath == null) {
      _showError('Please select a photo');
      return;
    }

    setState(() => _adding = true);
    try {
      await _repository.addKnownFace(name, _selectedPhotoPath!);
      _nameController.clear();
      setState(() => _selectedPhotoPath = null);
      await _loadFaces();
      _showSuccess('Added $name to known faces!');
    } catch (e) {
      _showError('Failed to add person: $e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removePerson(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Person'),
        content: Text('Are you sure you want to remove $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: AppConstants.errorColor))),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _repository.removeKnownFace(name);
        await _loadFaces();
        _showSuccess('Removed $name');
      } catch (e) {
        _showError('Failed to remove person: $e');
      }
    }
  }

  Future<void> _pickTestPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _testPhoto = File(picked.path));
      await _testRecognition();
    }
  }

  Future<void> _testRecognition() async {
    if (_testPhoto == null) return;
    
    try {
      final faces = await _repository.testFaceRecognition(_testPhoto!.path);
      if (mounted) {
        showModalBottomSheet(
          context: context,
          builder: (context) => _buildTestResultsSheet(faces),
        );
      }
    } catch (e) {
      _showError('Failed to test recognition: $e');
    }
  }

  Widget _buildTestResultsSheet(List<FaceDetection> faces) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMD),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Face Recognition Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          if (_testPhoto != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              child: Image.file(_testPhoto!, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: AppConstants.spacingMD),
          if (faces.isEmpty)
            const Text('No faces detected', style: TextStyle(color: AppConstants.textSecondary))
          else ...[
            Text('Found ${faces.length} face(s):', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppConstants.spacingSM),
            ...faces.map((face) => ListTile(
              leading: CircleAvatar(child: Text(face.name[0].toUpperCase())),
              title: Text(face.name),
              subtitle: Text('Confidence: ${(face.confidence * 100).toInt()}%'),
            )),
          ],
        ],
      ),
    );
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Faces')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAddPersonSection(),
                  const SizedBox(height: AppConstants.spacingLG),
                  _buildKnownFacesSection(),
                  const SizedBox(height: AppConstants.spacingLG),
                  _buildTestSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildAddPersonSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Person', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppConstants.spacingMD),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Person's name",
                hintText: 'Enter name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppConstants.spacingMD),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: Text(_selectedPhotoPath == null ? 'Select Photo' : 'Photo Selected'),
                    onPressed: _pickFacePhoto,
                  ),
                ),
                if (_selectedPhotoPath != null) ...[
                  const SizedBox(width: AppConstants.spacingSM),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _selectedPhotoPath = null),
                  ),
                ],
              ],
            ),
            if (_selectedPhotoPath != null) ...[
              const SizedBox(height: AppConstants.spacingSM),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                child: Image.file(
                  File(_selectedPhotoPath!),
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: AppConstants.spacingMD),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Add Person'),
                onPressed: _adding ? null : _addPerson,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKnownFacesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Known Faces', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: AppConstants.spacingMD),
        if (_knownFaces.isEmpty)
          const EmptyState(
            icon: Icons.face_off,
            title: 'No known faces yet',
            message: 'Add your first person above',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _knownFaces.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppConstants.spacingSM),
            itemBuilder: (context, index) {
              final face = _knownFaces[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppConstants.primaryColor,
                    child: Text(
                      face.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(face.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${face.embeddingPaths.length} samples'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppConstants.errorColor),
                    onPressed: () => _removePerson(face.name),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test Face Recognition', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppConstants.spacingMD),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_camera),
              label: const Text('Select Photo to Test'),
              onPressed: _pickTestPhoto,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            if (_testPhoto != null) ...[
              const SizedBox(height: AppConstants.spacingMD),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                child: Image.file(_testPhoto!, height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            ],
          ],
        ),
      ),
    );
  }
}