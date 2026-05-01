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

## Trabajo en 3 entornos (corporativo + no corporativos)

Para evitar diferencias entre PCs, usamos una unica guia operativa:

- docs/entornos_colaboracion.md

Ese documento define:

- bootstrap por tipo de maquina
- comandos estandar para desarrollar y validar
- reglas para archivos locales (Firebase) que no se versionan
- checks minimos antes de push

Comando sugerido de validacion local:

```powershell
.\scripts\check_all.ps1
```

Si PowerShell bloquea scripts por politicas corporativas:

```cmd
.\scripts\check_all.cmd
```

## Copilot Pro en otras PCs

Copilot toma reglas del repositorio desde:

- .github/copilot-instructions.md

Solo necesitan hacer `git pull` para recibir la configuracion compartida.
