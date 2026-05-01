# Instrucciones Copilot para este proyecto

Estas reglas aplican para todo el equipo y todas las PCs.

## Objetivo

Mantener un flujo unico entre entorno corporativo y no corporativo.

## Entorno y comandos base

- Antes de trabajar, preparar entorno con `scripts/dev_env.ps1`.
- Para validar cambios usar:
  - Windows corporativo: `scripts/check_all.cmd`
  - Resto de entornos: `scripts/check_all.ps1`
- Para `functions/` usar `scripts/functions_npm.ps1` en lugar de npm global.

## Reglas de colaboracion

- Priorizar scripts y docs del repo sobre configuraciones locales de cada PC.
- No versionar secretos ni archivos locales de Firebase.
- No proponer cambios que dependan de PATH global o permisos de admin.
- Si algo falla solo en una PC, tratar primero como problema de entorno.

## Validacion minima antes de PR

- `flutter analyze` sin errores nuevos.
- `flutter test` pasando.
- Si cambia setup, actualizar docs en `docs/` y/o scripts en `scripts/`.

## Referencias del proyecto

- Guia de entornos: `docs/entornos_colaboracion.md`
- Plantilla de PR: `.github/PULL_REQUEST_TEMPLATE.md`
