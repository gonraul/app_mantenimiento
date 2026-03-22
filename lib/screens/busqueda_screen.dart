import 'package:flutter/material.dart';

import '../services/documento_service.dart';
import '../models/documento_model.dart';
import 'visor_imagen_screen.dart';
import 'visor_video_screen.dart';

class BusquedaScreen extends StatefulWidget {
  const BusquedaScreen({super.key});

  @override
  State<BusquedaScreen> createState() => _BusquedaScreenState();
}

class _BusquedaScreenState extends State<BusquedaScreen> {
  final DocumentoService _documentoService = DocumentoService();
  final TextEditingController _searchController = TextEditingController();
  String _tagBuscado = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mantenimiento Hospital Austral')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por palabra clave...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _tagBuscado = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DocumentoModel>>(
              stream: _documentoService.buscarPorTag(_tagBuscado),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _tagBuscado.isNotEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron documentos'),
                  );
                }
                final documentos = snapshot.data!;
                return ListView.builder(
                  itemCount: documentos.length,
                  itemBuilder: (context, index) {
                    final doc = documentos[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(doc.titulo),
                        subtitle: Text(doc.descripcion),
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final url = await _documentoService.getMediaUrl(
                            doc.mediaUrl,
                          );

                          if (url.isNotEmpty) {
                            if (doc.mediaType == 'video') {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => VisorVideoScreen(
                                    videoUrl: url,
                                    titulo: doc.titulo,
                                  ),
                                ),
                              );
                            } else {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => VisorImagenScreen(
                                    imageUrl: url,
                                    titulo: doc.titulo,
                                  ),
                                ),
                              );
                            }
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Error al cargar el archivo'),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
