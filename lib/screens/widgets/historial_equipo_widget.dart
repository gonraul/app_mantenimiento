import 'package:flutter/material.dart';

class HistorialEquipoWidget extends StatelessWidget {
  const HistorialEquipoWidget({
    super.key,
    required this.eventos,
    this.onTapDocumento,
  });

  final List<HistorialEvent> eventos;
  final ValueChanged<HistorialEvent>? onTapDocumento;

  @override
  Widget build(BuildContext context) {
    if (eventos.isEmpty) {
      return const Center(
        child: Text(
          'Todavia no hay eventos registrados.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: eventos.length,
      itemBuilder: (context, index) {
        final evento = eventos[index];
        final isLast = index == eventos.length - 1;
        final isDocumento = evento.tipo == 'documento';

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 42,
                child: Column(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _obtenerColorNodo(evento.tipo),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _obtenerColorNodo(evento.tipo).withValues(alpha: 0.30),
                            blurRadius: 9,
                          ),
                        ],
                      ),
                      child: Icon(
                        _obtenerIcono(evento.tipo),
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 1.6,
                          color: Colors.grey.withValues(alpha: 0.32),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: isDocumento && evento.url != null && onTapDocumento != null
                        ? () => onTapDocumento!(evento)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  evento.cabecera,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                evento.fechaLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            evento.descripcion,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                              height: 1.35,
                            ),
                          ),
                          if (isDocumento)
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.attach_file_rounded,
                                    size: 14,
                                    color: Color(0xFF005088),
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Tocar para abrir documento',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF005088),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _obtenerColorNodo(String tipo) {
    switch (tipo) {
      case 'chat':
        return const Color(0xFF11CAA0);
      case 'documento':
        return const Color(0xFF005088);
      case 'sistema':
        return const Color(0xFFE9A400);
      default:
        return Colors.grey;
    }
  }

  IconData _obtenerIcono(String tipo) {
    switch (tipo) {
      case 'chat':
        return Icons.comment_rounded;
      case 'documento':
        return Icons.attach_file_rounded;
      case 'sistema':
        return Icons.warning_amber_rounded;
      default:
        return Icons.circle;
    }
  }
}

class HistorialEvent {
  const HistorialEvent({
    required this.tipo,
    required this.cabecera,
    required this.descripcion,
    required this.fechaLabel,
    this.url,
    this.titulo,
    this.ext,
    this.fecha,
    this.id = '',
  });

  final String tipo;
  final String cabecera;
  final String descripcion;
  final String fechaLabel;
  final String? url;
  final String? titulo;
  final String? ext;
  final DateTime? fecha;
  final String id;
}
