import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_error_mapper.dart';
import '../theme/app_theme.dart';
import '../view_models/upload_content_view_model.dart';

class UploadContentScreen extends StatefulWidget {
  const UploadContentScreen({super.key, this.initialTopicId});

  final String? initialTopicId;

  @override
  State<UploadContentScreen> createState() => _UploadContentScreenState();
}

class _UploadContentScreenState extends State<UploadContentScreen> {
  final UploadContentViewModel _viewModel = UploadContentViewModel();

  static const String _newTopicOptionValue = '__create_new_topic__';

  // Campos solo para documento nuevo
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _pisoController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _areaTecnicaController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();


  PlatformFile? _selectedFile;
  late String _selectedTopicId;

  bool get _topicLocked =>
      widget.initialTopicId != null && widget.initialTopicId!.trim().isNotEmpty;

  bool get _isNewTopic =>
      !_topicLocked && _selectedTopicId == _newTopicOptionValue;

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
    _noteController.dispose();
    _viewModel.dispose();
    super.dispose();
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

  String _selectedTopicLabel(List<({String id, String title})> topics) {
    if (_selectedTopicId == _newTopicOptionValue) {
      return 'Nuevo tema';
    }

    for (final topic in topics) {
      if (topic.id == _selectedTopicId) {
        return topic.title;
      }
    }

    return 'Nuevo tema';
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: false,
      withReadStream: true,
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
        'pdf',
        'txt',
        'doc',
        'docx',
      ],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    setState(() {
      _selectedFile = file;
    });
  }

  Future<void> _upload() async {
    if (_viewModel.isUploading) return;

    final file = _selectedFile;
    final noteText = _noteController.text.trim();
    if (file == null && noteText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un archivo o escribi una nota'),
        ),
      );
      return;
    }

    if (_isNewTopic && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El titulo del equipo es obligatorio')),
      );
      return;
    }

    try {
      final rawTags = _tagsController.text.trim();
      final tags = rawTags.isEmpty
          ? <String>[]
          : rawTags
                .split(',')
                .map((t) => t.trim().toLowerCase())
                .where((t) => t.isNotEmpty)
                .toList();

        final uploadFile = file == null
          ? _buildNotePlatformFile(noteText)
          : await _ensureFileBytes(file);

      await _viewModel.upload(
        file: uploadFile,
        isNewTopic: _isNewTopic,
        selectedTopicId: _selectedTopicId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        piso: _pisoController.text.trim(),
        area: _areaController.text.trim(),
        areaTecnica: _areaTecnicaController.text.trim(),
        tags: tags,
        caption: noteText,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenido subido correctamente')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = AppErrorMapper.toUserMessage(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  PlatformFile _buildNotePlatformFile(String noteText) {
    final bytes = Uint8List.fromList(utf8.encode(noteText));
    final now = DateTime.now();
    final name =
        'nota_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.txt';
    return PlatformFile(name: name, size: bytes.length, bytes: bytes);
  }

  Future<PlatformFile> _ensureFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file;

    final stream = file.readStream;
    if (stream == null) {
      throw Exception('No se pudo leer el archivo seleccionado');
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }

    final bytes = builder.takeBytes();
    return PlatformFile(
      name: file.name,
      size: bytes.length,
      bytes: bytes,
      path: file.path,
      identifier: file.identifier,
    );
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
          child: StreamBuilder<List<({String id, String title})>>(
            stream: _viewModel.watchTopics(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final topics = snapshot.data ?? [];

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
                          'Equipo: ${_selectedTopicLabel(topics)}',
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
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(
                        _selectedFile == null
                            ? 'Seleccionar imagen / video / pdf'
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

                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        label: 'Nota (opcional)',
                        hint: 'Si no adjuntas archivo, se sube como nota .txt',
                      ),
                    ),

                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _viewModel,
                      builder: (context, _) {
                        final isUploading = _viewModel.isUploading;
                        return FilledButton.icon(
                          onPressed: isUploading ? null : _upload,
                          icon: isUploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                        );
                      },
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
