import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/comment_model.dart';
import '../services/equipment_repository.dart';
import '../theme/app_theme.dart';

/// Sección de comentarios reutilizable para visores de imagen y video.
/// Si [mediaDocId] está vacío (ítems legacy sin doc Firestore) se oculta.
///
/// [panelMode] = true: el widget asume altura acotada por su padre y usa scroll
/// interno para la lista (ideal para visor de imagen).
/// [panelMode] = false (defecto): usa shrinkWrap para insertarse en un
/// SingleChildScrollView externo (ideal para visor de video).
class ComentariosSection extends StatefulWidget {
  const ComentariosSection({
    super.key,
    required this.equipmentId,
    required this.mediaDocId,
    this.panelMode = false,
  });

  final String equipmentId;
  final String mediaDocId;
  final bool panelMode;

  @override
  State<ComentariosSection> createState() => _ComentariosSectionState();
}

class _ComentariosSectionState extends State<ComentariosSection> {
  static final EquipmentRepository _repository = EquipmentRepository();

  final TextEditingController _textController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    if (widget.mediaDocId.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await _repository.addComment(
        equipmentId: widget.equipmentId,
        mediaDocId: widget.mediaDocId,
        text: text,
      );
      _textController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el comentario.')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar comentario'),
          content: const Text('¿Querés borrar este comentario?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Eliminar', style: TextStyle(color: Colors.red[400])),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _repository.deleteComment(
        equipmentId: widget.equipmentId,
        mediaDocId: widget.mediaDocId,
        commentId: commentId,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el comentario.')),
      );
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'es').format(dt);
    } catch (_) {
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    }
  }

  Widget _buildCommentList() {
    return StreamBuilder<List<CommentModel>>(
      stream: _repository.watchComments(
        equipmentId: widget.equipmentId,
        mediaDocId: widget.mediaDocId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          );
        }

        final comments = snapshot.data ?? [];
        if (comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Sin comentarios aún.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: !widget.panelMode,
          physics: widget.panelMode
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final comment = comments[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                          ),
                        ),
                        if (comment.createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(comment.createdAt),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteComment(comment.id),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white54,
                      size: 18,
                    ),
                    tooltip: 'Eliminar comentario',
                    splashRadius: 16,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendComment(),
            decoration: InputDecoration(
              hintText: 'Agregar un comentario…',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.10),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24, width: 0.8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.verdeAustral,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _isSending
            ? const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                onPressed: _sendComment,
                icon: const Icon(
                  Icons.send_rounded,
                  color: AppColors.verdeAustral,
                ),
                tooltip: 'Enviar comentario',
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaDocId.isEmpty) return const SizedBox.shrink();

    if (widget.panelMode) {
      // Modo panel: altura acotada por el padre, lista con scroll interno
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Expanded(child: _buildCommentList()),
          const SizedBox(height: 10),
          _buildInputRow(),
          const SizedBox(height: 8),
        ],
      );
    }

    // Modo inline: sin Expanded, para embeberse en SingleChildScrollView
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        _buildCommentList(),
        const SizedBox(height: 10),
        _buildInputRow(),
        const SizedBox(height: 8),
      ],
    );
  }
}
