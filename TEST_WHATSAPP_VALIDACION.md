# Test de Validación WhatsApp - Declaración vs Consulta
**Fecha:** 11/4/2026  
**Lógica:** 2026-04-11-intent-v4  
**Responsable:** Raúl González  

---

## Instrucciones

1. Copiar y pegar **exactamente** cada frase de prueba en WhatsApp.
2. Registrar el resultado observado en la columna correspondiente.
3. Marcar ✅ si coincide con lo esperado, ❌ si no.
4. **Tiempo estimado:** 5-7 minutos.

---

## Test 1: Consulta Base + Continuidad

| # | Frase Enviada | Modo Esperado | Respuesta Esperada | Respuesta Observada | ✅/❌ | Notas |
|---|---|---|---|---|---|---|
| 1.1 | `Me mostrás historial de caldera 2.` | consulta | Listado de reportes de caldera 2 | | | |
| 1.2 | `Y antes de eso?` | consulta | Continúa con caldera 2, página siguiente o "No hay más" | | | |
| 1.3 | `Seguí.` | consulta | Continúa con caldera 2 o "No hay más" | | | |

**Criterio de aprobación:** 3/3 ✅ sin saltos de equipo.

---

## Test 2: Falla + Antecedentes (Mixta)

| # | Frase Enviada | Modo Esperado | Respuesta Esperada | Respuesta Observada | ✅/❌ | Notas |
|---|---|---|---|---|---|---|
| 2.1 | `Tengo una falla en caldera 2, qué antecedentes hay?` | consulta | Listado o consulta sobre antecedentes de caldera 2 | | | |

**Criterio de aprobación:** 1/1 ✅, sin saltar de equipo.

---

## Test 3: Cambio de Equipo Explícito

| # | Frase Enviada | Modo Esperado | Respuesta Esperada | Respuesta Observada | ✅/❌ | Notas |
|---|---|---|---|---|---|---|
| 3.1 | `Me mostrás historial de tableros.` | consulta | Listado de tableros (no compresor/caldera) | | | |
| 3.2 | `Y de calderas?` | consulta | Cambio a calderas sin mezclar contexto anterior | | | |
| 3.3 | `Y de bombas?` | consulta | Cambio a bombas, equipo limpio | | | |

**Criterio de aprobación:** 3/3 ✅, sin mezclar contextos de equipos previos.

---

## Test 4: Registro Puro (Reporte)

| # | Frase Enviada | Modo Esperado | Respuesta Esperada | Respuesta Observada | ✅/❌ | Notas |
|---|---|---|---|---|---|---|
| 4.1 | `Caldera 2 no enciende, marca alarma de presión.` | reporte | `ok. registrado` | | | |
| 4.2 | `Tablero 1 presenta olor a quemado y temperatura alta.` | reporte | `ok. registrado` | | | |

**Criterio de aprobación:** 2/2 ✅, modo reporte (sin análisis).

---

## Test 5: Consulta Temporal

| # | Frase Enviada | Modo Esperado | Respuesta Esperada | Respuesta Observada | ✅/❌ | Notas |
|---|---|---|---|---|---|---|
| 5.1 | `Me mostrás reportes de hoy de caldera 2.` | consulta | Listado filtrado a HOY de caldera 2 | | | |
| 5.2 | `Sí, seguí.` | consulta | Continúa mismo rango temporal (hoy) o "No hay más" | | | |

**Criterio de aprobación:** 2/2 ✅, temporal preservado en follow-up.

---

## Test 6: Fin de Paginación

| # | Frase Enviada | Modo Esperado | Respuesta Esperada | Respuesta Observada | ✅/❌ | Notas |
|---|---|---|---|---|---|---|
| 6.1 | `Seguí.` (repetidamente hasta agotar) | consulta | Finalmente: "No hay mas reportes para mostrar en esa consulta." | | | |

**Criterio de aprobación:** 1/1 ✅, mensaje correcto cuando se agota historial.

---

## Resumen Final

| Test | Esperado | Observado | % Aprobación |
|---|---|---|---|
| 1: Continuidad | 3/3 | | |
| 2: Mixta | 1/1 | | |
| 3: Cambio Equipo | 3/3 | | |
| 4: Registro | 2/2 | | |
| 5: Temporal | 2/2 | | |
| 6: Paginación | 1/1 | | |
| **TOTAL** | **12/12** | | **%** |

### Criterio General
- **≥11/12 (92%):** ESTABLE ✅ → Listo para producción.
- **9-10/12 (75-83%):** PARCIAL ⚠ → Ajuste fino necesario.
- **<9/12 (<75%):** INESTABLE ❌ → Revisar lógica de intención.

---

## Notas Técnicas

- Versión de lógica actual: `WEBHOOK_LOGIC_VERSION = "2026-04-11-intent-v4"`
- Se busca desde logs: `logicVersion` en cada request recibida.
- Cambios más recientes: 
  - Equipos plurales (calderas, tableros, compresores, bombas, generadores, chillers).
  - Detección de "Y de X" como cambio de equipo operativo.
  - Filtro de reportes mal clasificados históricos.

---

## Próximos Pasos

Si aprobación ≥ 92%:
1. ✅ Dejar en producción 24h de monitoreo.
2. ✅ Revisar logs de "Error en modo consulta" diariamente.
3. ✅ Documentar cualquier edge case para versión v5.

Si aprobación < 92%:
1. Capturar nuevas pruebas fallidas.
2. Ajustar patrones en `detectIntentMode` o `shouldUseListadoMode`.
3. Redeploy y revalidar.
