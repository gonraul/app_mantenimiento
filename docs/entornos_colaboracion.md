# Entornos colaboracion (3 PCs)

Objetivo: trabajar en 3 terminales/PCs (1 corporativa y 2 no corporativas) sin friccion y sin cambios sorpresa.

## 1) Contrato unico de trabajo

Todos usamos los mismos contratos de repo:

- misma rama base (`main`) y ramas por tarea (`feat/...`, `fix/...`)
- mismos comandos de validacion antes de push
- no versionar secretos ni archivos locales de Firebase

Archivos locales (no versionados):

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `firebase.json`

## 2) Perfiles por maquina

### Perfil A: PC corporativa (restricciones)

En cada terminal nueva, inicializar entorno:

```powershell
.\scripts\dev_env.ps1
```

Notas:

- evita depender de PATH global de Windows
- usa Node 22 / Java 17 / Flutter desde rutas user-scope
- para `functions/`, usar siempre:

```powershell
.\scripts\functions_npm.ps1 install
```

### Perfil B: PCs no corporativas

Pueden usar instalacion normal global, pero para consistencia se recomienda ejecutar los mismos scripts del repo:

```powershell
.\scripts\dev_env.ps1
.\scripts\functions_npm.ps1 install
```

Asi, todos corren con versiones equivalentes y mismos comandos.

## 3) Flujo diario recomendado

1. `git pull --rebase origin main`
2. Crear rama: `git checkout -b feat/<tema>`
3. Desarrollar
4. Validar (recomendado, comando unico):

```powershell
.\scripts\check_all.ps1
```

En Windows con politicas corporativas de PowerShell, usar:

```cmd
.\scripts\check_all.cmd
```

Alternativa equivalente manual:

```powershell
flutter pub get
flutter analyze
flutter test
```

5. Commit pequeno y descriptivo
6. Push + PR

## 4) Regla de oro para diferencias de entorno

Si algo solo falla en la PC corporativa, no tocar logica de negocio primero.

1. Verificar entorno con `scripts/dev_env.ps1`
2. Reproducir en otra PC
3. Si en otra PC no falla, tratarlo como problema de entorno (certificados, proxy, PATH, permisos)

## 5) Checklist minimo antes de merge

- `flutter analyze` sin errores nuevos
- `flutter test` pasando
- app inicia localmente (`flutter run`)
- no se subieron secretos ni archivos Firebase locales
- README/docs actualizados si cambia setup

## 6) Decision de equipo (importante)

Acordar que:

- lo que manda es el repo (scripts + docs), no la config local de cada uno
- toda solucion de setup repetible se documenta en `docs/` y/o `scripts/`
- evitar "arreglos manuales" que no queden escritos
