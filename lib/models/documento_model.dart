class DocumentoModel {
  final String id;
  final String titulo;
  final String descripcion;
  final List<String> tags;
  final String mediaUrl;
  final String mediaType;
  final String mediaCaption;
  final int mediaOrder;

  DocumentoModel({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.tags,
    required this.mediaUrl,
    required this.mediaType,
    required this.mediaCaption,
    required this.mediaOrder,
  });

  // Método para crear una instancia desde un documento de Firestore
  factory DocumentoModel.fromFirestore(
    Map<String, dynamic> data,
    String id, {
    String mediaUrl = '',
    String mediaType = 'image',
    String mediaCaption = '',
    int mediaOrder = 0,
  }) {
    return DocumentoModel(
      id: id,
      titulo: data['title'] ?? '',
      descripcion: data['description'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      mediaCaption: mediaCaption,
      mediaOrder: mediaOrder,
    );
  }
}
