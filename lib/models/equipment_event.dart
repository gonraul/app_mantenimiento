import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentEvent {
  const EquipmentEvent({
    required this.id,
    required this.texto,
    required this.tipo,
    required this.tecnico,
    required this.canal,
    required this.timestamp,
  });

  final String id;
  final String texto;
  final String tipo;
  final String tecnico;
  final String canal;
  final DateTime? timestamp;

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory EquipmentEvent.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return EquipmentEvent(
      id: id,
      texto: (data['texto'] as String?)?.trim() ?? '',
      tipo: (data['tipo'] as String?)?.trim() ?? 'mantenimiento',
      tecnico: (data['tecnico'] as String?)?.trim() ?? 'desconocido',
      canal: (data['canal'] as String?)?.trim() ?? 'app',
      timestamp: _parseTimestamp(data['timestamp']),
    );
  }
}
