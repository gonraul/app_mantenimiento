# Arquitectura de App Mantenimiento

Fecha: 2026-04-03

## 1) Vista general

La app esta construida con Flutter y Firebase, con una estructura por capas simple:

- Presentacion: pantallas Flutter en lib/screens
- Datos: servicios Firebase en lib/services
- Modelo: DTOs de Firestore en lib/models
- Estilo: tema y colores en lib/theme

Punto de entrada:
- lib/main.dart inicializa Firebase y abre AuthPage.

Flujo principal:
- AuthPage -> HomePage -> TasksPage (o BusquedaScreen) -> DetalleEquipoPage -> Visores y UploadContentScreen.

## 2) Diagrama de arquitectura refactorizada

```mermaid
flowchart TD
    A[main.dart] --> B[AuthPage]
    B -->|authStateChanges| C[HomePage]
    C --> D[TasksPage]
    D --> E[DetalleEquipoPage]
    D --> H[UploadContentScreen]
    E --> H
    
    D -->|TasksViewModel| TVM[GetEquipmentsStreamUseCase + SearchEquipmentsUseCase]
    E -->|GetEquipmentDetailStreamUseCase| EDetails[Equipment Stream]
    H -->|UploadContentViewModel| UVM[UploadMediaToEquipmentUseCase + DeleteMediaFromEquipmentUseCase]
    
    TVM --> ER[EquipmentRepository]
    EDetails --> ER
    UVM --> ER
    
    ER -->|queries| FR[(Firestore: equipos)]
    ER -->|media| FRMedia[(equipos/{id}/media)]
    ER -->|storage| FS[(Firebase Storage)]
    
    C --> I[BusquedaScreen]
    I -->|BusquedaViewModel| BVM[GetEquipmentsStreamUseCase + SearchEquipmentsUseCase]
    BVM --> ER
    
    E -->|abrir imagen| J[VisorImagenScreen]
    E -->|abrir video| K[VisorVideoScreen]
```

## 3) Estructura de datos (Firestore)

Coleccion principal: equipos

Campos de documento (equipo/tema):
- title
- description
- tags (array)
- status
- priority
- location
- piso
- area
- areaTecnica
- createdAt
- archivos (legacy array)
- documents (legacy array)

Subcoleccion: equipos/{id}/media

Campos de media:
- url
- storagePath
- type (image/video/file)
- name/caption
- order
- timestamp
- createdAt/created_at

Nota: Mapeo centralizado en Equipment.fromFirestore() integra media + campos legacy (archivos/documents) para compatibilidad historica.

## 4) Funcionalidad por pantalla

AuthPage
- Login con email y password usando FirebaseAuth.
- Sesion persistente por authStateChanges.

TasksPage
- Consumo de stream Equipment via TasksViewModel + GetEquipmentsStreamUseCase.
- Busqueda local por titulo, descripcion y tags via SearchEquipmentsUseCase.
- Navegacion a detalle y alta de contenido.

BusquedaScreen
- Pantalla alternativa de busqueda con mismo flujo que TasksPage.
- Usa BusquedaViewModel (ChangeNotifier) + GetEquipmentsStreamUseCase + SearchEquipmentsUseCase.
- Reutiliza Equipment model y logica de filtrado de dominio.
- Navega a DetalleEquipoPage con equipmentId.
- DocumentoService mantiene getMediaUrl() para casos legacy; buscarPorTag() delegada a EquipmentRepository.

DetalleEquipoPage
- Constructor parametrizado con equipmentId (String).
- Consumo de Equipment via GetEquipmentDetailStreamUseCase.
- Historial renderizado desde equipment.media list (sin queries de subcolleccion en UI).
- Delete orchestrado via DeleteMediaFromEquipmentUseCase.
- Desacoplado de Firestore directo (solo URL resolution para visualization).

UploadContentScreen
- Orquestacion de upload via UploadContentViewModel + UploadMediaToEquipmentUseCase.
- Crear equipo nuevo o agregar a existente.
- Sube archivo a Firebase Storage.
- Persiste metadata centralizadamente en EquipmentRepository.

VisorImagenScreen / VisorVideoScreen
- Visualizacion de contenido multimedia.
- Desacoplados de estructura de datos (reciben URL directa).

## 5) Estado actual de la arquitectura

Fortalezas
- Arquitectura por capas bien definida (Repository -> Use Cases -> ViewModels -> UI).
- Flujo principal limpio sin queries directas a Firestore en pantallas.
- Integracion Firebase centralizada (Auth, Firestore, Storage).
- Historial multimedia con soporte de datos legacy.
- Reutilización de use cases (SearchEquipments) en múltiples pantallas (TasksPage, BusquedaScreen).

Deuda tecnica (RESUELTA)
- ~~Duplicacion entre TaskService y DocumentoService~~ → Consolidado con EquipmentRepository.
- Variantes de nombres de timestamp (timestamp, createdAt, created_at) → Normalizado en MediaItem._parseTimestamp().
- ~~BusquedaScreen funcionalidad aislada~~ → Ahora integrada con BusquedaViewModel + Equipment model.

## 6) Plan de refactor por etapas (sin romper)

Fase 1: Consolidacion de data layer
- Crear un unico servicio de dominio para equipos y media (por ejemplo EquipmentRepository).
- Mover toda escritura de UploadContentScreen al servicio.
- Mantener API actual como wrappers temporales para compatibilidad.

Estado actual: implementada.
- Nuevo repositorio central: lib/services/equipment_repository.dart
- TaskService ahora funciona como fachada/wrapper para compatibilidad.
- UploadContentScreen ya no escribe directo en Firestore/Storage; delega en TaskService/EquipmentRepository.

Fase 2: Normalizacion de modelo y mapeo
- Definir entidades unificadas: Equipment y MediaItem.
- Normalizar campos de fecha y tipo.
- Centralizar conversion desde/hacia Firestore.

Estado actual: implementada.
- Entidades unificadas creadas: lib/models/equipment.dart y lib/models/media_item.dart
- Mapeo centralizado en Equipment.fromFirestore y MediaItem.fromFirestore.
- Compatibilidad legacy preservada al integrar archivos/documents en el mapeo.
- TasksPage migrada para consumir Equipment en el flujo principal de listado.

Fase 3: Casos de uso
- Separar operaciones en casos de uso:
  - GetEquipmentsStream
  - GetEquipmentDetailStream
  - UploadMediaToEquipment
  - DeleteMediaFromEquipment
  - SearchEquipments

Estado actual: implementada.
- Casos de uso creados en lib/use_cases/:
  - get_equipments_stream_use_case.dart
  - get_equipment_detail_stream_use_case.dart
  - upload_media_to_equipment_use_case.dart
  - delete_media_from_equipment_use_case.dart
  - search_equipments_use_case.dart

Fase 4: Presentacion desacoplada
- Introducir capa de estado (ValueNotifier/ChangeNotifier, Riverpod o Bloc).
- Quitar acceso directo a Firebase desde pantallas.

Estado actual: implementada (completo).
- TasksPage usa TasksViewModel (ChangeNotifier) con stream + busqueda desacoplada.
- UploadContentScreen usa UploadContentViewModel para orquestar carga y estado de UI.
- BusquedaScreen usa BusquedaViewModel (ChangeNotifier) reutilizando use cases de dominio.
- DetalleEquipoPage consume Equipment via GetEquipmentDetailStreamUseCase.
- Todas las pantallas principales desacopladas de Firestore (solo EquipmentRepository + use cases).

Fase 5: Calidad y observabilidad
- Tests unitarios de mapeos y servicios.
- Tests de widget para flujos criticos.
- Logging y manejo uniforme de errores.

Estado actual: implementada (base).
- Logging central: lib/core/app_logger.dart
- Mapeo uniforme de errores: lib/core/app_error_mapper.dart
- Tests unitarios agregados:
  - test/search_equipments_use_case_test.dart
  - test/media_item_mapping_test.dart

## 7) Riesgos a controlar durante cambios

- Compatibilidad con datos legacy (archivos/documents).
- Borrado de Storage cuando existen URLs y storagePath mixtos.
- Rendimiento de consultas en listas grandes y subcolecciones.
- Indices necesarios en Firestore para busquedas y ordenamientos.

## 8) Siguientes pasos sugeridos

1. **Consolidar DocumentoService/BusquedaScreen** - ✅ COMPLETADO.
   - BusquedaViewModel creado (similar a TasksViewModel) en lib/view_models/busqueda_view_model.dart.
   - Reutiliza GetEquipmentsStreamUseCase + SearchEquipmentsUseCase para busqueda desacoplada.
   - BusquedaScreen refactorizado: ahora usa ViewModel, navega a DetalleEquipoPage con equipmentId.
   - DocumentoService simplificado: mantiene getMediaUrl()/getImageUrl() para compatibilidad; buscarPorTag() delegada a EquipmentRepository (marcado @Deprecated).
   - Una sola fuente de verdad: EquipmentRepository es el acceso a datos para todas las pantallas.
   - Tests unitarios: 4 tests de mapeo + búsqueda, todos pasando (00:04 +4: All tests passed!).

2. **Widget tests para flujos críticos** - PENDIENTE.
   - Testing completo: login -> TasksPage/BusquedaScreen -> DetalleEquipoPage -> UploadContentScreen -> VisorImagenScreen/VisorVideoScreen.
   - Casos de prueba: listar equipos, buscar, ver detalle, eliminar media, subir archivo.
   - Mocks: Firebase Auth, Firestore, Storage.

3. **Revisión de Firestore** - PENDIENTE.
   - Validar colección 'equipos' es la correcta (no residuos de 'pdfs').
   - Crear índices para queries usadas en SearchEquipmentsUseCase (title, description, tags).
   - Revisar/actualizar reglas de seguridad para restricciones por usuario/rol.
   - Performance: probar con datasets grandes (1000+) y monitorear latencias de subcollection.

## 9) Notas técnicas finales

**Capas de la arquitectura (implementada):**
- **Presentation:** Vista (Flutter UI) + ViewModel (ChangeNotifier) = desacoplado de datos.
- **Domain:** Use Cases (funcionalidad de negocio pura, testeable).
- **Data:** Repository (acceso centralizado) + Models (normalizados).
- **Core:** Logger y ErrorMapper (cross-cutting concerns).

**Beneficios logrados:**
- ✅ Single Responsibility: cada pantalla delega a su ViewModel.
- ✅ Testability: use cases sin dependencias de Firebase.
- ✅ Reusability: SearchEquipmentsUseCase usado en TasksPage + BusquedaScreen.
- ✅ Maintainability: cambios en Firestore mapping impactan un solo lugar (Equipment.fromFirestore).
- ✅ Legacy compatibility: campos viejos (archivos/documents) integrados transparentemente.

**Riesgos residuales:**
- Datos legacy con múltiples formatos de timestamp (mitigado con _parseTimestamp fallback).
- Storage URLs mixtas (gs:// vs https://) en registros antiguos (manejado en getMediaUrl).
- Necesidad de migración de datos 'pdfs' -> 'equipos' si aún existe ambas colecciones en producción.
