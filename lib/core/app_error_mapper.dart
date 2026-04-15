class AppErrorMapper {
  static String toUserMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission-denied')) {
      return 'No tienes permisos para realizar esta accion.';
    }
    if (text.contains('unavailable') || text.contains('network')) {
      return 'Sin conexion o servicio no disponible. Intenta nuevamente.';
    }
    if (text.contains('not-found')) {
      return 'No se encontro el recurso solicitado.';
    }
    return 'Ocurrio un error inesperado. Intenta nuevamente.';
  }
}
