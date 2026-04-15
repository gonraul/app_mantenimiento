import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  const CommentModel({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String text;
  final DateTime? createdAt;

  factory CommentModel.fromFirestore(String id, Map<String, dynamic> data) {
    final ts = data['createdAt'];
    return CommentModel(
      id: id,
      text: (data['text'] as String?) ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
