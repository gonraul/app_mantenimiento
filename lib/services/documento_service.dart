import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/documento_model.dart';

class DocumentoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> getMediaUrl(String storagePathOrUrl) async {
    if (storagePathOrUrl.startsWith('http://') ||
        storagePathOrUrl.startsWith('https://')) {
      return storagePathOrUrl;
    }

    try {
      final ref = storagePathOrUrl.startsWith('gs://')
          ? _storage.refFromURL(storagePathOrUrl)
          : _storage.ref(storagePathOrUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      return '';
    }
  }

  Future<String> getImageUrl(String storagePath) => getMediaUrl(storagePath);

  Stream<List<DocumentoModel>> buscarPorTag(String tag) async* {
    Query query;
    if (tag.isEmpty) {
      query = _firestore.collection('pdfs');
    } else {
      query = _firestore
          .collection('pdfs')
          .where('tags', arrayContains: tag.toLowerCase());
    }

    await for (final snapshot in query.snapshots()) {
      final documentos = await Future.wait(
        snapshot.docs.map((doc) async {
          final mediaSnapshot = await doc.reference.collection('media').get();
          final orderedMedia = mediaSnapshot.docs.toList()
            ..sort((a, b) {
              final orderA = (a.data()['order'] as num?)?.toInt() ?? 0;
              final orderB = (b.data()['order'] as num?)?.toInt() ?? 0;
              return orderA.compareTo(orderB);
            });

          final firstMedia =
              orderedMedia.isNotEmpty ? orderedMedia.first.data() : <String, dynamic>{};

          return DocumentoModel.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
            mediaUrl: firstMedia['url'] ?? '',
            mediaType: firstMedia['type'] ?? 'image',
            mediaCaption: firstMedia['caption'] ?? '',
            mediaOrder: (firstMedia['order'] as num?)?.toInt() ?? 0,
          );
        }),
      );

      yield documentos;
    }
  }
}
