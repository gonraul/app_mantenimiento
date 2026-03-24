import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class UploadContentScreen extends StatefulWidget {
  const UploadContentScreen({
    super.key,
    this.initialTopicId,
  });

  final String? initialTopicId;

  @override
  State<UploadContentScreen> createState() => _UploadContentScreenState();
}

class _UploadContentScreenState extends State<UploadContentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _newTopicOptionValue = '__create_new_topic__';

  // Campos solo para documento nuevo
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _pisoController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _areaTecnicaController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  PlatformFile? _selectedFile;
  bool _isUploading = false;
  late String _selectedTopicId;

  bool get _topicLocked =>
      widget.initialTopicId != null && widget.initialTopicId!.trim().isNotEmpty;

  bool get _isNewTopic => !_topicLocked && _selectedTopicId == _newTopicOptionValue;

  @override
  void initState() {
    super.initState();
    _selectedTopicId = _topicLocked
        ? widget.initialTopicId!.trim()
        : _newTopicOptionValue;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pisoController.dispose();
    _areaController.dispose();
    _areaTecnicaController.dispose();
    _tagsController.dispose();
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
        const SnackBar(content: Text('El titulo del equipo es obligatorio')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final docRef = _isNewTopic
          ? _firestore.collection('pdfs').doc()
          : _firestore.collection('pdfs').doc(_selectedTopicId);

      final now = DateTime.now().millisecondsSinceEpoch;
      final safeName = _sanitizeFileName(file.name);
      final storagePath = 'pdfs/${docRef.id}/${now}_$safeName';
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
        final rawTags = _tagsController.text.trim();
        final tags = rawTags.isEmpty
            ? <String>[]
            : rawTags
                .split(',')
                .map((t) => t.trim().toLowerCase())
                .where((t) => t.isNotEmpty)
                .toList();

        await docRef.set({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'piso': _pisoController.text.trim(),
          'area': _areaController.text.trim(),
          'areaTecnica': _areaTecnicaController.text.trim(),
          'tags': tags,
          'status': 'pendiente',
          'priority': 'media',
          'location': '',
          'archivos': [fileUrl],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.update({
          'archivos': FieldValue.arrayUnion([fileUrl]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await docRef.collection('media').add({
        ...fileEntry,
        'storagePath': storagePath,
        'order': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });

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
        title: Text(
          _isNewTopic ? 'Nuevo equipo' : 'Agregar archivo',
          style: const TextStyle(color: Colors.white),
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
              colors: [AppColors.azulAustral, AppColors.verdeAustral],
            ),
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('pdfs').orderBy('title').snapshots(),
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

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 86),
                    if (_topicLocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Equipo: ${_selectedTopicLabel(docs)}',
                          style: const TextStyle(
                            color: AppColors.azulAustral,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    if (_isNewTopic) ...[
                      const SizedBox(height: 16),
                      _SectionLabel(label: 'Datos del equipo'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _titleController,
                        decoration: _inputDecoration(label: 'Titulo *'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: _inputDecoration(label: 'Descripcion'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pisoController,
                              decoration: _inputDecoration(label: 'Piso'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _areaController,
                              decoration: _inputDecoration(label: 'Area'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _areaTecnicaController,
                        decoration: _inputDecoration(label: 'Area tecnica'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _tagsController,
                        decoration: _inputDecoration(
                          label: 'Palabras clave',
                          hint: 'Ej: bomba, compresor, electrico',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Separa las palabras con comas.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
