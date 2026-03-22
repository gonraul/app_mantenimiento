import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class UploadContentScreen extends StatefulWidget {
  const UploadContentScreen({super.key});

  @override
  State<UploadContentScreen> createState() => _UploadContentScreenState();
}

class _UploadContentScreenState extends State<UploadContentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _newTopicOptionValue = '__create_new_topic__';

  // Solo para tema nuevo
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String _selectedTopicId = _newTopicOptionValue;

  bool get _isNewTopic => _selectedTopicId == _newTopicOptionValue;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  String _detectType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    const videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    return videoExtensions.contains(extension) ? 'video' : 'image';
  }

  InputDecoration _inputDecoration({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.backgroundWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _selectedTopicLabel(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (_selectedTopicId == _newTopicOptionValue) {
      return 'Nuevo tema';
    }

    for (final doc in docs) {
      if (doc.id == _selectedTopicId) {
        return (doc.data()['title'] as String?) ?? '(sin titulo)';
      }
    }

    return 'Nuevo tema';
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: true,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'mp4',
        'mov',
        'avi',
        'mkv',
        'webm',
      ],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    setState(() {
      _selectedFile = file;
    });
  }

  Future<void> _upload() async {
    if (_isUploading) return;

    final file = _selectedFile;
    if (file == null || file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un archivo primero')),
      );
      return;
    }

    if (_isNewTopic && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El titulo del tema es obligatorio')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final safeName = _sanitizeFileName(file.name);
      final docIdForPath = _isNewTopic ? 'nuevo_tema' : _selectedTopicId;
      final storagePath = 'mantenimiento/$docIdForPath/${now}_$safeName';
      final ref = _storage.ref(storagePath);

      await ref.putData(file.bytes!);
      final fileUrl = await ref.getDownloadURL();
      final fileType = _detectType(file.name);

      final fileEntry = {
        'url': fileUrl,
        'name': file.name,
        'type': fileType,
        'createdAt': Timestamp.now(),
      };

      if (_isNewTopic) {
        await _firestore.collection('mantenimiento').add({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'documents': [fileEntry],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore
            .collection('mantenimiento')
            .doc(_selectedTopicId)
            .update({
              'documents': FieldValue.arrayUnion([fileEntry]),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenido subido correctamente')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al subir contenido: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Subir contenido',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E3192), Color(0xFF00BF6F)],
            ),
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('mantenimiento').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final topicItems = <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: _newTopicOptionValue,
                  child: Text('+ Crear nuevo tema'),
                ),
                ...docs.map(
                  (doc) => DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(
                      (doc.data()['title'] as String?) ?? '(sin titulo)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ];

              final validValues = topicItems.map((e) => e.value).toSet();
              final currentValue = validValues.contains(_selectedTopicId)
                  ? _selectedTopicId
                  : _newTopicOptionValue;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 86),
                    DropdownButtonFormField<String>(
                      key: ValueKey(currentValue),
                      initialValue: currentValue,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      decoration: _inputDecoration(label: 'Seleccionar tema'),
                      items: topicItems,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedTopicId = value;
                        });
                      },
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'Tema actual: ${_selectedTopicLabel(docs)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'No hay temas cargados aun. Se creara uno nuevo.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),

                    if (_isNewTopic) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _titleController,
                        decoration: _inputDecoration(
                          label: 'Titulo del tema *',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: _inputDecoration(label: 'Descripcion'),
                      ),
                    ],

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(
                        _selectedFile == null
                            ? 'Seleccionar imagen / video'
                            : _selectedFile!.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.azulAustral,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isUploading ? null : _upload,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.cloud_upload_rounded,
                              color: Colors.white,
                            ),
                      label: const Text('Subir contenido'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.azulAustral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
