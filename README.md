# app_mantenimiento

Aplicacion Flutter para mantenimiento hospitalario con Firebase.

## Configuracion local de Firebase

Los archivos de configuracion Firebase no se versionan en este repositorio.
Para ejecutar la app localmente, regeneralos en tu maquina.

### Archivos que deben existir localmente

- lib/firebase_options.dart
- android/app/google-services.json
- firebase.json

### Regeneracion recomendada

1. Instala FlutterFire CLI si todavia no la tenes.
2. Inicia sesion en Firebase si hace falta.
3. Desde la raiz del proyecto ejecuta:

```bash
flutterfire configure --project=austral-matenimiento --platforms=android,web
```

Si vas a configurar iOS o macOS mas adelante, volve a ejecutar FlutterFire CLI
incluyendo esas plataformas para generar tambien sus archivos nativos.

### Verificacion

Despues de regenerar los archivos, valida el entorno con:

```bash
flutter doctor
flutter pub get
flutter run
```
