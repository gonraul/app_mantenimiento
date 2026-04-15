import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/comment_model.dart';
import '../models/equipment.dart';
import '../models/media_item.dart';
import '../models/task_model.dart';

class EquipmentRepository {
  EquipmentRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const List<String> _videoExtensions = <String>[
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
  ];

  Stream<List<Equipment>> getEquipments() async* {
    await for (final snapshot in _firestore.collection('pdfs').snapshots()) {
      final equipments = await Future.wait(
        snapshot.docs.map((doc) async {
          final mediaSnapshot = await doc.reference.collection('media').get();

          final mediaDocs = mediaSnapshot.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList();

          return Equipment.fromFirestore(
            id: doc.id,
            docData: doc.data(),
            mediaDocs: mediaDocs,
          );
        }),
      );

      yield equipments;
    }
  }

  Stream<List<TaskModel>> getTasks() async* {
    await for (final equipments in getEquipments()) {
      final tasks = equipments
          .map(
            (equipment) => TaskModel(
              id: equipment.id,
              title: equipment.title,
              description: equipment.description,
              mediaUrl: equipment.primaryMedia?.url ?? '',
              mediaType: switch (equipment.primaryMedia?.type) {
                MediaType.video => 'video',
                MediaType.file => 'file',
                _ => 'image',
              },
              mediaCaption: equipment.primaryMedia?.caption ?? '',
              mediaOrder: equipment.primaryMedia?.order ?? 0,
              status: equipment.status,
              priority: equipment.priority,
              location: equipment.location,
              piso: equipment.piso,
              area: equipment.area,
              areaTecnica: equipment.areaTecnica,
              tags: equipment.tags,
            ),
          )
          .toList();
      yield tasks;
    }
  }

  Stream<Equipment?> watchEquipmentById(String id) async* {
    final docRef = _firestore.collection('pdfs').doc(id);
    await for (final doc in docRef.snapshots()) {
      if (!doc.exists || doc.data() == null) {
        yield null;
        continue;
      }

      final mediaSnapshot = await docRef.collection('media').get();
      final mediaDocs = mediaSnapshot.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList();

      yield Equipment.fromFirestore(
        id: doc.id,
        docData: doc.data()!,
        mediaDocs: mediaDocs,
      );
    }
  }

  Stream<List<({String id, String title})>> watchTopicsList() {
    return _firestore.collection('pdfs').orderBy('title').snapshots().map((s) {
      return s.docs
          .map(
            (doc) => (
              id: doc.id,
              title: (doc.data()['title'] as String?) ?? '(sin título)',
            ),
          )
          .toList();
    });
  }

  Future<List<({String id, String title})>> getTopicsList() async {
    final snapshot = await _firestore.collection('pdfs').orderBy('title').get();
    return snapshot.docs
        .map(
          (doc) => (
            id: doc.id,
            title: (doc.data()['title'] as String?) ?? '(sin título)',
          ),
        )
        .toList();
  }

  Reference _resolveStorageReference(String storagePath) {
    if (storagePath.startsWith('gs://') ||
        storagePath.startsWith('http://') ||
        storagePath.startsWith('https://')) {
      return _storage.refFromURL(storagePath);
    }
    return _storage.ref(storagePath);
  }

  Future<String> getMediaUrl(String storagePathOrUrl) async {
    if (storagePathOrUrl.startsWith('http://') ||
        storagePathOrUrl.startsWith('https://')) {
      return storagePathOrUrl;
    }

    try {
      final ref = _resolveStorageReference(storagePathOrUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error al obtener URL de media: $e');
      return '';
    }
  }

  Future<String> getImageUrl(String storagePath) => getMediaUrl(storagePath);

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

  Future<void> createTopicWithMedia({
    required Uint8List bytes,
    required String originalFileName,
    required String title,
    required String description,
    required List<String> tags,
    required String caption,
    required int order,
    String piso = '',
    String area = '',
    String areaTecnica = '',
  }) async {
    final normalizedTags = tags.map((tag) => tag.toLowerCase().trim()).toList();
    final safeFileName = _sanitizeFileName(originalFileName);
    final mediaType = _detectMediaType(originalFileName);

    final docRef = _firestore.collection('pdfs').doc();

    await docRef.set({
      'title': title,
      'description': description,
      'piso': piso,
      'area': area,
      'areaTecnica': areaTecnica,
      'tags': normalizedTags,
      'status': 'pendiente',
      'priority': 'media',
      'location': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final downloadUrl = await _uploadMediaToTopic(
      docRef: docRef,
      bytes: bytes,
      safeFileName: safeFileName,
      mediaType: mediaType,
      caption: caption,
      order: order,
      originalFileName: originalFileName,
    );

    await docRef.update({
      'archivos': FieldValue.arrayUnion([downloadUrl]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

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

    final downloadUrl = await _uploadMediaToTopic(
      docRef: docRef,
      bytes: bytes,
      safeFileName: safeFileName,
      mediaType: mediaType,
      caption: caption,
      order: order,
      originalFileName: originalFileName,
    );

    await docRef.update({
      'archivos': FieldValue.arrayUnion([downloadUrl]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMediaFromEquipment({
    required String equipmentId,
    required String mediaSource,
  }) async {
    final docRef = _firestore.collection('pdfs').doc(equipmentId);

    // Borrado en Storage con tolerancia a rutas legacy/url.
    try {
      await _storage.refFromURL(mediaSource).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        final lower = mediaSource.toLowerCase();
        final isStoragePath =
            !lower.startsWith('http://') &&
            !lower.startsWith('https://') &&
            !lower.startsWith('gs://');
        if (isStoragePath) {
          await _storage.ref(mediaSource).delete();
        }
      }
    } catch (_) {
      final lower = mediaSource.toLowerCase();
      final isStoragePath =
          !lower.startsWith('http://') &&
          !lower.startsWith('https://') &&
          !lower.startsWith('gs://');
      if (isStoragePath) {
        await _storage.ref(mediaSource).delete();
      }
    }

    await docRef.update({
      'archivos': FieldValue.arrayRemove([mediaSource]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final mediaRef = docRef.collection('media');
    final byUrl = await mediaRef.where('url', isEqualTo: mediaSource).get();
    final byStoragePath = await mediaRef
        .where('storagePath', isEqualTo: mediaSource)
        .get();

    final mediaDocs = <String, DocumentReference<Map<String, dynamic>>>{};
    for (final doc in byUrl.docs) {
      mediaDocs[doc.id] = doc.reference;
    }
    for (final doc in byStoragePath.docs) {
      mediaDocs[doc.id] = doc.reference;
    }

    for (final ref in mediaDocs.values) {
      try {
        await ref.delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') {
          rethrow;
        }
      }
    }
  }

  Future<String> _uploadMediaToTopic({
    required DocumentReference docRef,
    required Uint8List bytes,
    required String safeFileName,
    required String mediaType,
    required String caption,
    required int order,
    required String originalFileName,
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
      'name': originalFileName,
      'type': mediaType,
      'caption': caption,
      'order': order,
      'storagePath': storagePath,
      'timestamp': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return downloadUrl;
  }

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

  // ── Comentarios ─────────────────────────────────────────────────────────────

  Stream<List<CommentModel>> watchComments({
    required String equipmentId,
    required String mediaDocId,
  }) {
    return _firestore
        .collection('pdfs')
        .doc(equipmentId)
        .collection('media')
        .doc(mediaDocId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => CommentModel.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> addComment({
    required String equipmentId,
    required String mediaDocId,
    required String text,
  }) {
    return _firestore
        .collection('pdfs')
        .doc(equipmentId)
        .collection('media')
        .doc(mediaDocId)
        .collection('comments')
        .add({
          'text': text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> deleteComment({
    required String equipmentId,
    required String mediaDocId,
    required String commentId,
  }) {
    return _firestore
        .collection('pdfs')
        .doc(equipmentId)
        .collection('media')
        .doc(mediaDocId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }
}
