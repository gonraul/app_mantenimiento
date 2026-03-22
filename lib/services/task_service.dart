import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/task_model.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const List<String> _videoExtensions = <String>[
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
  ];

  // Obtiene temas desde 'pdfs' y toma el primer media por orden.
  Stream<List<TaskModel>> getTasks() async* {
    await for (final snapshot in _firestore.collection('pdfs').snapshots()) {
      final tasks = await Future.wait(
        snapshot.docs.map((doc) async {
          final mediaSnapshot = await doc.reference.collection('media').get();

          final orderedMedia = mediaSnapshot.docs.toList()
            ..sort((a, b) {
              final orderA = (a.data()['order'] as num?)?.toInt() ?? 0;
              final orderB = (b.data()['order'] as num?)?.toInt() ?? 0;
              return orderA.compareTo(orderB);
            });

          final firstMediaData =
              orderedMedia.isNotEmpty ? orderedMedia.first.data() : <String, dynamic>{};

          return TaskModel.fromFirestore(
            doc.data(),
            doc.id,
            mediaUrl: firstMediaData['url'] ?? '',
            mediaType: firstMediaData['type'] ?? 'image',
            mediaCaption: firstMediaData['caption'] ?? '',
            mediaOrder: (firstMediaData['order'] as num?)?.toInt() ?? 0,
          );
        }),
      );

      yield tasks;
    }
  }

  Reference _resolveStorageReference(String storagePath) {
    if (storagePath.startsWith('gs://') ||
        storagePath.startsWith('http://') ||
        storagePath.startsWith('https://')) {
      return _storage.refFromURL(storagePath);
    }
    return _storage.ref(storagePath);
  }

  // Obtiene URL usable. Si ya es http(s), retorna tal cual.
  Future<String> getMediaUrl(String storagePathOrUrl) async {
    if (storagePathOrUrl.startsWith('http://') ||
        storagePathOrUrl.startsWith('https://')) {
      return storagePathOrUrl;
    }

    try {
      final ref = _resolveStorageReference(storagePathOrUrl);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Error al obtener la URL de la imagen: $e');
      return '';
    }
  }

  // Compatibilidad con llamadas existentes que esperan una imagen.
  Future<String> getImageUrl(String storagePath) => getMediaUrl(storagePath);

  /// Retorna una lista simple [{id, title}] de todos los temas para usar en
  /// desplegables sin cargar subcolecciones.
  Future<List<({String id, String title})>> getTopicsList() async {
    final snapshot = await _firestore
        .collection('pdfs')
        .orderBy('title')
        .get();
    return snapshot.docs
        .map((doc) => (id: doc.id, title: (doc.data()['title'] as String?) ?? '(sin título)'))
        .toList();
  }

  String _detectMediaType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (_videoExtensions.contains(extension)) {
      return 'video';
    }
    return 'image';
  }

  String _buildStoragePath(String pdfId, String safeFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'pdfs/$pdfId/${timestamp}_$safeFileName';
  }

  String _sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  /// Crea un tema nuevo con su primer archivo de media.
  Future<void> createTopicWithMedia({
    required Uint8List bytes,
    required String originalFileName,
    required String title,
    required String description,
    required List<String> tags,
    required String caption,
    required int order,
  }) async {
    final normalizedTags = tags.map((tag) => tag.toLowerCase().trim()).toList();
    final safeFileName = _sanitizeFileName(originalFileName);
    final mediaType = _detectMediaType(originalFileName);

    final docRef = _firestore.collection('pdfs').doc();

    await docRef.set({
      'title': title,
      'description': description,
      'tags': normalizedTags,
      'status': 'pendiente',
      'priority': 'media',
      'location': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _uploadMediaToTopic(
      docRef: docRef,
      bytes: bytes,
      safeFileName: safeFileName,
      mediaType: mediaType,
      caption: caption,
      order: order,
    );
  }

  /// Agrega un archivo de media a un tema que ya existe en Firestore.
  /// No modifica ningún campo del documento principal.
  Future<void> addMediaToExistingTopic({
    required String pdfId,
    required Uint8List bytes,
    required String originalFileName,
    required String caption,
    required int order,
  }) async {
    final safeFileName = _sanitizeFileName(originalFileName);
    final mediaType = _detectMediaType(originalFileName);
    final docRef = _firestore.collection('pdfs').doc(pdfId);

    await _uploadMediaToTopic(
      docRef: docRef,
      bytes: bytes,
      safeFileName: safeFileName,
      mediaType: mediaType,
      caption: caption,
      order: order,
    );
  }

  Future<void> _uploadMediaToTopic({
    required DocumentReference docRef,
    required Uint8List bytes,
    required String safeFileName,
    required String mediaType,
    required String caption,
    required int order,
  }) async {
    final storagePath = _buildStoragePath(docRef.id, safeFileName);
    final ref = _storage.ref(storagePath);

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: mediaType == 'video' ? 'video/mp4' : 'image/jpeg',
      ),
    );

    final downloadUrl = await ref.getDownloadURL();

    await docRef.collection('media').add({
      'url': downloadUrl,
      'type': mediaType,
      'caption': caption,
      'order': order,
      'storagePath': storagePath,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Kept for backwards compatibility – should not be called by new code.
  Future<void> uploadContentAndCreateTask({
    required Uint8List bytes,
    required String originalFileName,
    required String title,
    required String description,
    required List<String> tags,
    required String caption,
    required int order,
    String? existingPdfId,
  }) async {
    if (existingPdfId != null && existingPdfId.trim().isNotEmpty) {
      return addMediaToExistingTopic(
        pdfId: existingPdfId.trim(),
        bytes: bytes,
        originalFileName: originalFileName,
        caption: caption,
        order: order,
      );
    }
    return createTopicWithMedia(
      bytes: bytes,
      originalFileName: originalFileName,
      title: title,
      description: description,
      tags: tags,
      caption: caption,
      order: order,
    );
  }

}
