class TaskModel {
  final String id;
  final String title;
  final String description;
  final String mediaUrl;
  final String mediaType; // image o video
  final String mediaCaption;
  final int mediaOrder;
  final String status; // pendiente, en_progreso, completado
  final String priority; // alta, media, baja
  final String location;
  final String piso;
  final String area;
  final String areaTecnica;
  final List<String> tags; // Lista de etiquetas para búsqueda

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.mediaUrl,
    required this.mediaType,
    required this.mediaCaption,
    required this.mediaOrder,
    required this.status,
    required this.priority,
    required this.location,
    required this.piso,
    required this.area,
    required this.areaTecnica,
    required this.tags,
  });

  factory TaskModel.fromFirestore(
    Map<String, dynamic> data,
    String id, {
    String mediaUrl = '',
    String mediaType = 'image',
    String mediaCaption = '',
    int mediaOrder = 0,
  }) {
    return TaskModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      mediaCaption: mediaCaption,
      mediaOrder: mediaOrder,
      status: data['status'] ?? 'pendiente',
      priority: data['priority'] ?? 'media',
      location: data['location'] ?? '',
      piso: data['piso'] ?? '',
      area: data['area'] ?? '',
      areaTecnica: data['areaTecnica'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
    );
  }
}
