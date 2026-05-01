const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const axios = require("axios");
const { BotFrameworkAdapter } = require("botbuilder");
const path = require("path");
const { randomUUID } = require("crypto");

if (!admin.apps.length) {
	admin.initializeApp();
}

const db = admin.firestore();

const WHATSAPP_VERIFY_TOKEN = "HUA_SECRET_2026";
const GEMINI_MODEL = "gemini-2.5-flash";
const MAX_GEMINI_RETRIES = 2;
const BASE_RETRY_DELAY_MS = 1200;
const SESSION_WINDOW_MS = 10 * 60 * 1000;
const WEBHOOK_LOGIC_VERSION = "2026-04-11-intent-v4";

const geminiSystemInstruction =
	"Sos el Asistente Tecnico del Hospital Austral. Analiza el mensaje del tecnico y extrae: equipo, accion y estado. Responde unicamente JSON valido.";

const fieldChiefSystemInstruction =
	"Sos el jefe de mantenimiento del Hospital Austral. Tu tarea es ayudar al tecnico en el campo. Analiza lo que te dice, detecta relaciones ocultas entre sintomas y causas (por ejemplo temperatura alta + borne flojo), prioriza riesgos de seguridad, sugiere pasos concretos de diagnostico/accion y responde de forma profesional y tecnica en espanol rioplatense. Responde SIEMPRE con este formato breve y claro: 1) Hipotesis (2 bullets max), 2) Evidencia (2 bullets max), 3) Plan de accion por prioridad: Seguridad, Diagnostico, Reparacion. Regla de foco: la respuesta principal debe centrarse SOLO en el equipo actual. No agregues bloque de Contexto/Pendientes al final salvo que el tecnico pregunte explicitamente 'que tenemos pendiente'.";

const consultaSystemInstructionBase =
	"Sos el Asistente Tecnico del Hospital Austral. Basado en este historial de mantenimiento [Historial], responde la duda del tecnico de forma concisa. Si la falla se repite mas de 3 veces en el historial, indicale que debe contactar al supervisor al +54XXXXXXXX.";

function sleep(ms) {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

function getRetryDelayMs(attempt) {
	const jitter = Math.floor(Math.random() * 250);
	return BASE_RETRY_DELAY_MS * (2 ** attempt) + jitter;
}

function isPendingSummaryRequest(textoTecnico = "") {
	const normalized = normalizeText(textoTecnico);
	return /(que tenemos pendiente|tenemos pendiente|pendientes|resumen de turno|resumen del turno)/.test(normalized);
}

function areSameEquipmentName(a = "", b = "") {
	const na = normalizeText(a);
	const nb = normalizeText(b);
	if (!na || !nb) return false;
	return na === nb || na.includes(nb) || nb.includes(na);
}

async function getLastTechnicianMessages(telefono, {
	limit = 10,
	activeEquipmentName = null,
	allowCrossTopic = false,
} = {}) {
	const snapshot = await db
		.collection("mensajes_ia")
		.where("telefono", "==", telefono)
		.limit(80)
		.get();

	const ordered = [...snapshot.docs].sort((a, b) => {
		const ta = a.data()?.timestamp?.toMillis?.() || 0;
		const tb = b.data()?.timestamp?.toMillis?.() || 0;
		return tb - ta;
	});

	const filtered = ordered.filter((doc) => {
		if (!activeEquipmentName || allowCrossTopic) {
			return true;
		}
		const d = doc.data() || {};
		const equipo = d?.respuesta_ia_json?.equipo || d.equipo_nombre_consulta || "";
		return areSameEquipmentName(equipo, activeEquipmentName);
	});

	return filtered
		.slice(0, limit)
		.map((doc) => {
			const d = doc.data() || {};
			return {
				fecha: d.timestamp?.toDate?.()?.toISOString?.() || null,
				modo: d.modo || "reporte",
				mensaje: d.mensaje_original || "",
				respuesta: d.respuesta_ia || "",
				equipo: d?.respuesta_ia_json?.equipo || d.equipo_nombre_consulta || null,
			};
		});
}

async function getHospitalEquipmentDescriptions(limit = 20) {
	const snapshot = await db.collection("equipos").limit(200).get();
	const ordered = [...snapshot.docs].sort((a, b) => {
		const ta = a.data()?.timestamp?.toMillis?.() || 0;
		const tb = b.data()?.timestamp?.toMillis?.() || 0;
		return tb - ta;
	});

	const unique = new Map();
	for (const doc of ordered) {
		const d = doc.data() || {};
		const title = (d.title || "").trim();
		if (!title) continue;
		if (!unique.has(title.toLowerCase())) {
			unique.set(title.toLowerCase(), {
				title,
				description: (d.description || "").trim(),
				status: d.status || "",
				priority: d.priority || "",
			});
		}
		if (unique.size >= limit) break;
	}

	return [...unique.values()];
}

function formatRecentMessagesForPrompt(messages) {
	if (!messages?.length) return "Sin mensajes previos.";
	return messages.map((m, i) => {
		const fecha = m.fecha || "sin_fecha";
		const equipo = m.equipo || "sin_equipo";
		return `#${i + 1} | fecha=${fecha} | modo=${m.modo} | equipo=${equipo} | tecnico=${m.mensaje}`;
	}).join("\n");
}

function formatEquipmentContextForPrompt(items) {
	if (!items?.length) return "Sin descripciones de equipos disponibles.";
	return items.map((e, i) =>
		`#${i + 1} | equipo=${e.title} | descripcion=${e.description || "sin descripcion"} | estado=${e.status || ""} | prioridad=${e.priority || ""}`,
	).join("\n");
}

function inferPriorityFromText(text) {
	const n = normalizeText(text);
	if (/(critico|riesgo|peligro|gas|chispa|incendio|electrico|electrica|fuga)/.test(n)) return "Alta";
	if (/(inestable|intermitente|calienta|temperatura|anomalo|anormal)/.test(n)) return "Media";
	return "Baja";
}

function inferStatusFromText(text) {
	const n = normalizeText(text);
	if (/(no enciende|falla|fuera de servicio|peligro|riesgo|fuga)/.test(n)) return "Con falla";
	if (/(reparado|resuelto|funciona|operativo|funcional)/.test(n)) return "Funcional";
	return "Pendiente";
}

function inferActionFromText(text) {
	const trimmed = String(text || "").trim();
	if (!trimmed) return "Analisis tecnico";
	const sentence = trimmed.split(/[.!?\n]/)[0].trim();
	return sentence.slice(0, 90) || "Analisis tecnico";
}

function clamp(num, min, max) {
	return Math.max(min, Math.min(max, num));
}

function confidenceLevelFromScore(score) {
	if (score >= 75) return "alta";
	if (score >= 50) return "media";
	return "baja";
}

function buildInternalConfidenceForReport({
	textoTecnico,
	recentMessagesCount,
	usedSessionContext,
	parsedEquipmentName,
}) {
	let score = 55;
	const rationale = [];
	const normalized = normalizeText(textoTecnico);

	if (!isGenericEquipmentValue(parsedEquipmentName)) {
		score += 15;
		rationale.push("equipo_identificado");
	} else {
		score -= 12;
		rationale.push("equipo_no_especifico");
	}

	if (usedSessionContext) {
		score += 10;
		rationale.push("memoria_sesion_aplicada");
	}

	if (recentMessagesCount >= 5) {
		score += 8;
		rationale.push("contexto_conversacional_amplio");
	} else if (recentMessagesCount >= 2) {
		score += 4;
		rationale.push("contexto_conversacional_basico");
	}

	if (/(\b\d+\b|temperatura|volt|amp|bar|psi|fase|presion)/.test(normalized)) {
		score += 7;
		rationale.push("senales_tecnicas_cuantificables");
	}

	if (normalized.length < 16) {
		score -= 10;
		rationale.push("mensaje_breve_ambiguo");
	}

	const finalScore = clamp(score, 0, 100);
	return {
		score: finalScore,
		level: confidenceLevelFromScore(finalScore),
		rationale,
	};
}

function buildInternalConfidenceForConsulta({
	historialCount,
	equipoName,
	dateRangeLabel,
}) {
	let score = 50;
	const rationale = [];

	if (equipoName) {
		score += 15;
		rationale.push("equipo_consulta_identificado");
	}

	if (historialCount >= 5) {
		score += 20;
		rationale.push("historial_suficiente");
	} else if (historialCount >= 2) {
		score += 10;
		rationale.push("historial_parcial");
	} else {
		score -= 12;
		rationale.push("historial_escaso");
	}

	if (dateRangeLabel) {
		score += 5;
		rationale.push("filtro_temporal_explicito");
	}

	const finalScore = clamp(score, 0, 100);
	return {
		score: finalScore,
		level: confidenceLevelFromScore(finalScore),
		rationale,
	};
}

function ensureTechnicalResponseFormat(rawText, fallbackResumen = "") {
	const text = String(rawText || "").trim();
	if (!text) {
		return [
			"Hipotesis:",
			"- Se requiere mas contexto tecnico del evento.",
			"Evidencia:",
			"- Informacion inicial limitada del reporte.",
			"Plan de accion por prioridad:",
			"- Seguridad: verificar condiciones de riesgo inmediato antes de intervenir.",
			"- Diagnostico: relevar mediciones clave y estado de protecciones.",
			"- Reparacion: definir correccion segun diagnostico confirmado.",
		].join("\n");
	}

	const n = normalizeText(text);
	const hasRequiredBlocks =
		n.includes("hipotesis") &&
		n.includes("evidencia") &&
		n.includes("plan de accion");

	if (hasRequiredBlocks) {
		return text;
	}

	const resumen = text || fallbackResumen || "Sin detalle tecnico suficiente.";
	return [
		"Hipotesis:",
		`- ${resumen.slice(0, 160)}`,
		"- Posible causa combinada entre condicion operativa y componente electrico/mecanico.",
		"Evidencia:",
		"- Sintoma reportado por tecnico en campo.",
		"- Tendencia consistente con eventos recientes del mismo equipo.",
		"Plan de accion por prioridad:",
		"- Seguridad: aislar riesgo y validar protecciones antes de maniobras.",
		"- Diagnostico: medir variable critica (temperatura/corriente/presion) y revisar conexiones.",
		"- Reparacion: corregir componente causante, probar ciclo completo y registrar cierre.",
	].join("\n");
}

function extractJsonObject(text) {
	if (!text || typeof text !== "string") {
		return null;
	}

	const trimmed = text.trim();
	const withoutFence = trimmed
		.replace(/^```json\s*/i, "")
		.replace(/^```\s*/i, "")
		.replace(/```$/, "")
		.trim();

	const firstBrace = withoutFence.indexOf("{");
	const lastBrace = withoutFence.lastIndexOf("}");
	if (firstBrace === -1 || lastBrace === -1 || lastBrace <= firstBrace) {
		return null;
	}

	const candidate = withoutFence.slice(firstBrace, lastBrace + 1);
	try {
		return JSON.parse(candidate);
	} catch {
		return null;
	}
}

function detectIntentMode(textoTecnico = "") {
	const normalized = String(textoTecnico)
		.toLowerCase()
		.normalize("NFD")
		.replace(/[\u0300-\u036f]/g, "")
		.replace(/[^a-z0-9\s?]/g, " ")
		.replace(/\s+/g, " ")
		.trim();
	if (!normalized) return "reporte";

	const consultaRequestPatterns = [
		/\?/,
		/\bmostra(?:me|s)?\b/,
		/\bme mostras\b/,
		/\bdecime\b/,
		/\bdame\b/,
		/\bpasame\b/,
		/\bquiero ver\b/,
		/\bconsulta\b/,
		/\bhistorial\b/,
		/\bultimos?\b/,
		/\bque le paso\b/,
		/\bque paso\b/,
		/\bque me podes decir\b/,
		/\bestado del equipo\b/,
		/\bantecedentes\b/,
		/\bya habia pasado\b/,
		/\bantes de eso\b/,
		/\bayer\b/,
		/\bhoy\b/,
	];

	const reporteDeclarationPatterns = [
		/\btengo\b/,
		/\bhay\b/,
		/\bpresenta\b/,
		/\bfalla\b/,
		/\berror\b/,
		/\balarma\b/,
		/\bfuga\b/,
		/\bperdida\b/,
		/\btemperatura\b/,
		/\bpresion\b/,
		/\bno\s+(?:anda|enciende|funciona|calienta|enfria|arranca)\b/,
		/\bse\s+rompio\b/,
		/\bse\s+detuvo\b/,
		/\bse\s+apago\b/,
		/\bno\s+arranca\b/,
		/\bproblema\b/,
		/\burgente\b/,
	];

	const hasConsultaSignal = consultaRequestPatterns.some((pattern) => pattern.test(normalized));
	const hasReporteSignal = reporteDeclarationPatterns.some((pattern) => pattern.test(normalized));

	if (hasConsultaSignal && !hasReporteSignal) {
		return "consulta";
	}

	if (hasReporteSignal && !hasConsultaSignal) {
		return "reporte";
	}

	if (hasConsultaSignal && hasReporteSignal) {
		const startsAsRequest = /^(me mostras|mostrame|mostras|decime|dame|pasame|quiero ver|consulta|historial)\b/.test(normalized);
		return startsAsRequest || normalized.includes("?") ? "consulta" : "reporte";
	}

	return "reporte";
}

function extractEquipoIdFromText(textoTecnico = "") {
	const text = String(textoTecnico);
	const explicitMatch = text.match(/(?:equipo[_\s-]*id|id[_\s-]*equipo|equipo)\s*[:#-]?\s*([a-zA-Z0-9_-]{8,40})/i);
	if (explicitMatch?.[1]) {
		return explicitMatch[1];
	}

	const firestoreIdMatch = text.match(/\b([a-zA-Z0-9]{20})\b/);
	return firestoreIdMatch?.[1] || null;
}

function isGenericEquipmentValue(value = "") {
	const normalized = normalizeText(value);
	return !normalized || [
		"no identificado",
		"no especificado",
		"equipo no identificado",
	].includes(normalized);
}

function normalizeText(text = "") {
	return String(text)
		.toLowerCase()
		.normalize("NFD")
		.replace(/[\u0300-\u036f]/g, "")
		.replace(/\bcadera\b/g, "caldera")
		.replace(/[^a-z0-9\s]/g, " ")
		.replace(/\s+/g, " ")
		.trim();
}

function extractEquipoNameFromConsulta(textoTecnico = "") {
	const normalized = normalizeText(textoTecnico);
	if (!normalized) return null;

	const stopwords = new Set([
		"ayer",
		"hoy",
		"antes",
		"despues",
		"luego",
		"eso",
		"esto",
		"aquello",
		"ese",
		"esta",
		"reporte",
		"reportes",
		"historial",
		"sucedio",
		"paso",
		"ultimo",
		"ultimos",
		"ultimamente",
	]);

	const patterns = [
		/\b(caldera)(?:\s*\d+)?\b/,
		/\b(calderas)\b/,
		/\b(bomba)(?:\s*\d+)?\b/,
		/\b(bombas)\b/,
		/\b(tablero)(?:\s*\d+)?\b/,
		/\b(tableros)\b/,
		/\b(compresor)(?:\s*\d+)?\b/,
		/\b(compresores)\b/,
		/\b(generador)(?:\s*\d+)?\b/,
		/\b(generadores)\b/,
		/\b(chiller)(?:\s*\d+)?\b/,
		/\b(chillers)\b/,
		/\b(ups)\b/,
		/\b(equipo\s+[a-z0-9\s]{2,30})\b/,
		/\b(?:de|del)\s+((?:caldera|bomba|tablero|compresor|generador|chiller)s?\s*\d*)\b/,
	];

	for (const pattern of patterns) {
		const match = normalized.match(pattern);
		if (match?.[1]) {
			const candidate = match[1].trim();
			const firstToken = candidate.split(" ")[0];
			if (candidate.length >= 3 && !stopwords.has(firstToken)) {
				return candidate;
			}
		}
	}

	return null;
}

function extractConsultaDateRange(textoTecnico = "") {
	const normalized = String(textoTecnico)
		.toLowerCase()
		.normalize("NFD")
		.replace(/[\u0300-\u036f]/g, "")
		.trim();

	if (!normalized) return null;

	const now = new Date();
	const localOffsetMs = -3 * 60 * 60 * 1000;
	const localNow = new Date(now.getTime() + localOffsetMs);
	const startOfTodayLocal = new Date(
		localNow.getFullYear(),
		localNow.getMonth(),
		localNow.getDate(),
	);
	const startOfTodayUtcMs = startOfTodayLocal.getTime() - localOffsetMs;

	if (/\bayer\b/.test(normalized)) {
		const startMs = startOfTodayUtcMs - (24 * 60 * 60 * 1000);
		const endMs = startOfTodayUtcMs;
		return { startMs, endMs, label: "ayer" };
	}

	if (/\bhoy\b/.test(normalized)) {
		return { startMs: startOfTodayUtcMs, endMs: now.getTime() + 1, label: "hoy" };
	}

	if (/\bultima semana\b|\bultimos 7 dias\b/.test(normalized)) {
		const start = new Date(now);
		start.setDate(start.getDate() - 7);
		return { startMs: start.getTime(), endMs: now.getTime() + 1, label: "ultima_semana" };
	}

	if (/\bultimo mes\b|\bultimos 30 dias\b/.test(normalized)) {
		const start = new Date(now);
		start.setDate(start.getDate() - 30);
		return { startMs: start.getTime(), endMs: now.getTime() + 1, label: "ultimo_mes" };
	}

	return null;
}

async function resolveEquipoIdForConsulta({ textoTecnico, telefono }) {
	const explicitId = extractEquipoIdFromText(textoTecnico);
	if (explicitId) {
		return explicitId;
	}

	const equipoName = extractEquipoNameFromConsulta(textoTecnico);
	if (equipoName) {
		const equiposSnapshot = await db
			.collection("equipos")
			.where("telefono", "==", telefono)
			.limit(120)
			.get();

		const target = normalizeText(equipoName);
		const sortedEquipos = [...equiposSnapshot.docs].sort((a, b) => {
			const ta = a.data()?.timestamp?.toMillis?.() || 0;
			const tb = b.data()?.timestamp?.toMillis?.() || 0;
			return tb - ta;
		});

		for (const doc of sortedEquipos) {
			const title = normalizeText(doc.data()?.title || "");
			if (title && (title.includes(target) || target.includes(title))) {
				return doc.id;
			}
		}
	}

	const lastByPhone = await db
		.collection("mensajes_ia")
		.where("telefono", "==", telefono)
		.limit(25)
		.get();

	const sortedDocs = [...lastByPhone.docs].sort((a, b) => {
		const ta = a.data()?.timestamp?.toMillis?.() || 0;
		const tb = b.data()?.timestamp?.toMillis?.() || 0;
		return tb - ta;
	});

	for (const doc of sortedDocs) {
		const data = doc.data();
		if (data?.equipo_id) {
			return data.equipo_id;
		}
	}

	return null;
}

async function fetchMaintenanceHistoryForConsulta({
	equipoId,
	telefono,
	dateRange,
	offset = 0,
	pageSize = 7,
}) {
	const snapshot = await db
		.collection("mensajes_ia")
		.where("telefono", "==", telefono)
		.limit(120)
		.get();

	const sortedDocs = [...snapshot.docs].sort((a, b) => {
		const ta = a.data()?.timestamp?.toMillis?.() || 0;
		const tb = b.data()?.timestamp?.toMillis?.() || 0;
		return tb - ta;
	});

	const filteredDocs = sortedDocs.filter((doc) => {
		const data = doc.data() || {};
		if (data.modo && data.modo !== "reporte") {
			return false;
		}

		if (detectIntentMode(data.mensaje_original || "") !== "reporte") {
			return false;
		}

		if (equipoId && data.equipo_id !== equipoId) {
			return false;
		}

		if (dateRange) {
			const ts = data.timestamp?.toMillis?.() || 0;
			if (ts < dateRange.startMs || ts >= dateRange.endMs) {
				return false;
			}
		}

		return true;
	});

	const fromMensajes = filteredDocs.slice(offset, offset + pageSize).map((doc) => {
		const data = doc.data() || {};
		return {
			id: doc.id,
			equipo_id: data.equipo_id || null,
			source: "mensajes_ia_telefono",
			fecha: data.timestamp?.toDate?.()?.toISOString?.() || null,
			mensaje_original: data.mensaje_original || "",
			respuesta_ia: data.respuesta_ia || "",
			respuesta_ia_json: data.respuesta_ia_json || null,
			num_media: data.num_media || 0,
		};
	});

	if (fromMensajes.length > 0) {
		return fromMensajes;
	}

	// Fallback: si no hay en mensajes_ia, intentamos leer historial desde equipos.
	const equiposSnapshot = await db
		.collection("equipos")
		.where("telefono", "==", telefono)
		.limit(120)
		.get();

	const equiposOrdenados = [...equiposSnapshot.docs].sort((a, b) => {
		const ta = a.data()?.timestamp?.toMillis?.() || 0;
		const tb = b.data()?.timestamp?.toMillis?.() || 0;
		return tb - ta;
	});

	const equiposFiltrados = equiposOrdenados.filter((doc) => {
		const data = doc.data() || {};
		if (equipoId && doc.id !== equipoId) {
			return false;
		}

		if (dateRange) {
			const ts = data.timestamp?.toMillis?.() || 0;
			if (ts < dateRange.startMs || ts >= dateRange.endMs) {
				return false;
			}
		}

		return true;
	});

	return equiposFiltrados.slice(offset, offset + pageSize).map((doc) => {
		const data = doc.data() || {};
		return {
			id: doc.id,
			equipo_id: doc.id,
			source: "equipos_telefono",
			fecha: data.timestamp?.toDate?.()?.toISOString?.() || null,
			mensaje_original: data.description || "",
			respuesta_ia: "",
			respuesta_ia_json: {
				equipo: data.title || "No identificado",
				accion: "Reporte en equipos",
				estado: data.status || "No identificado",
				prioridad: data.priority || "No definida",
			},
			num_media: 0,
		};
	});
}

async function fetchMaintenanceHistoryForConsultaByEquipoName({
	equipoName,
	telefono,
	dateRange,
	offset = 0,
	pageSize = 7,
}) {
	if (!equipoName) return [];

	const targetName = normalizeText(equipoName);

	const filterMensajesByName = (docs) => docs.filter((doc) => {
		const data = doc.data() || {};
		if (data.modo && data.modo !== "reporte") {
			return false;
		}

		if (detectIntentMode(data.mensaje_original || "") !== "reporte") {
			return false;
		}

		const eqFromJson = normalizeText(data?.respuesta_ia_json?.equipo || "");
		const eqFromText = normalizeText(data?.mensaje_original || "");
		const matchesName =
			(eqFromJson && (eqFromJson.includes(targetName) || targetName.includes(eqFromJson))) ||
			(!eqFromJson && eqFromText && eqFromText.includes(targetName));

		if (!matchesName) {
			return false;
		}

		if (dateRange) {
			const ts = data.timestamp?.toMillis?.() || 0;
			if (ts < dateRange.startMs || ts >= dateRange.endMs) {
				return false;
			}
		}

		return true;
	});

	const snapshotByPhone = await db
		.collection("mensajes_ia")
		.where("telefono", "==", telefono)
		.limit(250)
		.get();

	const sortedByPhone = [...snapshotByPhone.docs].sort((a, b) => {
		const ta = a.data()?.timestamp?.toMillis?.() || 0;
		const tb = b.data()?.timestamp?.toMillis?.() || 0;
		return tb - ta;
	});

	let byName = filterMensajesByName(sortedByPhone);

	// Fallback global por equipo: si no hay resultados por telefono, buscar en todo mensajes_ia.
	if (byName.length === 0) {
		const snapshotGlobal = await db
			.collection("mensajes_ia")
			.limit(600)
			.get();
		const sortedGlobal = [...snapshotGlobal.docs].sort((a, b) => {
			const ta = a.data()?.timestamp?.toMillis?.() || 0;
			const tb = b.data()?.timestamp?.toMillis?.() || 0;
			return tb - ta;
		});
		byName = filterMensajesByName(sortedGlobal);
	}

	const fromMensajes = byName.slice(offset, offset + pageSize).map((doc) => {
		const data = doc.data() || {};
		return {
			id: doc.id,
			equipo_id: data.equipo_id || null,
			source: byName.length > 0 && snapshotByPhone.size > 0 ? "mensajes_ia_telefono" : "mensajes_ia_global",
			fecha: data.timestamp?.toDate?.()?.toISOString?.() || null,
			mensaje_original: data.mensaje_original || "",
			respuesta_ia: data.respuesta_ia || "",
			respuesta_ia_json: data.respuesta_ia_json || null,
			num_media: data.num_media || 0,
		};
	});

	if (fromMensajes.length > 0) {
		return fromMensajes;
	}

	const equiposSnapshotByPhone = await db
		.collection("equipos")
		.where("telefono", "==", telefono)
		.limit(200)
		.get();

	const filterEquiposByName = (docs) => docs.filter((doc) => {
		const data = doc.data() || {};
		const title = normalizeText(data.title || "");
		const matchesName = title && (title.includes(targetName) || targetName.includes(title));
		if (!matchesName) {
			return false;
		}

		if (dateRange) {
			const ts = data.timestamp?.toMillis?.() || 0;
			if (ts < dateRange.startMs || ts >= dateRange.endMs) {
				return false;
			}
		}

		return true;
	});

	const equiposOrdenadosByPhone = [...equiposSnapshotByPhone.docs].sort((a, b) => {
		const ta = a.data()?.timestamp?.toMillis?.() || 0;
		const tb = b.data()?.timestamp?.toMillis?.() || 0;
		return tb - ta;
	});

	let equiposFiltrados = filterEquiposByName(equiposOrdenadosByPhone);

	// Fallback global por equipo en coleccion equipos.
	if (equiposFiltrados.length === 0) {
		const equiposSnapshotGlobal = await db
			.collection("equipos")
			.limit(600)
			.get();
		const equiposOrdenadosGlobal = [...equiposSnapshotGlobal.docs].sort((a, b) => {
			const ta = a.data()?.timestamp?.toMillis?.() || 0;
			const tb = b.data()?.timestamp?.toMillis?.() || 0;
			return tb - ta;
		});
		equiposFiltrados = filterEquiposByName(equiposOrdenadosGlobal);
	}

	return equiposFiltrados.slice(offset, offset + pageSize).map((doc) => {
		const data = doc.data() || {};
		return {
			id: doc.id,
			equipo_id: doc.id,
			source: equiposFiltrados.length > 0 && equiposSnapshotByPhone.size > 0 ? "equipos_telefono" : "equipos_global",
			fecha: data.timestamp?.toDate?.()?.toISOString?.() || null,
			mensaje_original: data.description || "",
			respuesta_ia: "",
			respuesta_ia_json: {
				equipo: data.title || "No identificado",
				accion: "Reporte en equipos",
				estado: data.status || "No identificado",
				prioridad: data.priority || "No definida",
			},
			num_media: 0,
		};
	});
}

function buildHistoryForPrompt(historial = []) {
	if (!historial.length) {
		return "Sin historial disponible para este equipo.";
	}

	return historial
		.map((item, index) => {
			const equipo = item.respuesta_ia_json?.equipo || "No identificado";
			const accion = item.respuesta_ia_json?.accion || "No identificada";
			const estado = item.respuesta_ia_json?.estado || "No identificado";
			const prioridad = item.respuesta_ia_json?.prioridad || "No definida";
			return [
				`#${index + 1}`,
				`fecha=${item.fecha || "sin_fecha"}`,
				`equipo=${equipo}`,
				`accion=${accion}`,
				`estado=${estado}`,
				`prioridad=${prioridad}`,
				`mensaje=${item.mensaje_original || ""}`,
			].join(" | ");
		})
		.join("\n");
}

function formatDateForReply(isoDate) {
	if (!isoDate) return "sin hora";
	const date = new Date(isoDate);
	if (Number.isNaN(date.getTime())) return "sin hora";
	return date.toLocaleString("es-AR", {
		timeZone: "America/Argentina/Buenos_Aires",
		hour: "2-digit",
		minute: "2-digit",
		day: "2-digit",
		month: "2-digit",
	});
}

function shouldUseListadoMode(textoTecnico = "") {
	const normalized = normalizeText(textoTecnico);
	if (!normalized) return false;

	const expertOnlyPatterns = /(hipotesis|causa raiz|plan de accion|diagnostico|analisis|analiza|recomendacion tecnica|que puede ser|por que)/;
	if (expertOnlyPatterns.test(normalized)) {
		return false;
	}

	const equipoPatterns = /(caldera|bomba|tablero|compresor|generador|chiller|ups)/;
	const listadoPatterns = /(reporte|reportes|historial|antecedentes|ayer|hoy|ultimamente|ultimos|antes de eso|sucedio|\bsi\b|mas|mas info|seguir|segui|continua|continuar)/;
	const hasEquipo = equipoPatterns.test(normalized);
	const hasListado = listadoPatterns.test(normalized);

	if (normalized.startsWith("y de") || normalized.startsWith("de")) {
		return hasEquipo;
	}

	return hasListado || hasEquipo;
}

function isCompleteHistoryRequest(textoTecnico = "") {
	const normalized = normalizeText(textoTecnico);
	if (!normalized) return false;
	return /(historial completo|completo|todo el historial|todos los reportes)/.test(normalized);
}

function isAffirmativeFollowUp(textoTecnico = "") {
	const normalized = normalizeText(textoTecnico);
	return /^(si|ok|dale|mas|mas info|seguir|segui|continua|continuar)\b/.test(normalized);
}

function isPaginationFollowUp(textoTecnico = "") {
	const normalized = normalizeText(textoTecnico);
	if (!normalized) return false;
	return /^(si|ok|dale|mas|mas info|seguir|segui|continua|continuar|y antes|antes de eso|y despues|y luego)\b/.test(normalized);
}

async function getLastConsultaContext(telefono) {
	const lastMsgs = await db
		.collection("mensajes_ia")
		.where("telefono", "==", telefono)
		.limit(25)
		.get();

	const sortedLast = [...lastMsgs.docs].sort((a, b) => {
		const ta = a.data()?.timestamp?.toMillis?.() || 0;
		const tb = b.data()?.timestamp?.toMillis?.() || 0;
		return tb - ta;
	});

	for (const doc of sortedLast) {
		const data = doc.data() || {};
		const tsMs = data.timestamp?.toMillis?.() || 0;
		if (!tsMs || (Date.now() - tsMs) > SESSION_WINDOW_MS) {
			continue;
		}

		if (data.modo === "consulta") {
			return {
				...data,
				message_id: doc.id,
				equipo_nombre_consulta:
					data.equipo_nombre_consulta ||
					data?.respuesta_ia_json?.equipo ||
					null,
			};
		}
	}

	return null;
}

function buildListadoResponse({ textoTecnico, historial, dateRange, isComplete = false, isFollowUp = false }) {
	if (!historial.length) {
		if (isFollowUp) {
			return "No hay mas reportes para mostrar en esa consulta.";
		}
		if (dateRange?.label === "ayer") {
			return "No encontré reportes de ayer para ese equipo/telefono.";
		}
		if (isComplete) {
			return "No encontré historial completo para esa consulta.";
		}
		return "No encontré historial para esa consulta.";
	}

	const header = isComplete
		? "Historial completo encontrado:"
		: dateRange?.label
			? `Reportes encontrados (${dateRange.label}):`
			: "Ultimos reportes encontrados:";

	const lines = historial.map((item) => {
		const equipo = item.respuesta_ia_json?.equipo || "Equipo no identificado";
		const accion = item.respuesta_ia_json?.accion || "Accion no identificada";
		const estado = item.respuesta_ia_json?.estado || "Estado no identificado";
		const hora = formatDateForReply(item.fecha);
		return `- ${hora} | ${equipo} | ${estado} | ${accion}`;
	});

	const sourceSet = new Set(historial.map((h) => h.source || "unknown"));
	let sourceLabel = "Fuente: telefono actual";
	if (sourceSet.has("mensajes_ia_global") || sourceSet.has("equipos_global")) {
		sourceLabel = "Fuente: historial global del equipo";
	}

	const normalized = normalizeText(textoTecnico);
	const footer = /antes de eso/.test(normalized)
		? "Si queres, te busco mas antiguos tambien."
		: "";

	return [header, sourceLabel, ...lines, footer].filter(Boolean).join("\n");
}

async function runGeminiConsultation({ textoTecnico, historial }) {
	const apiKey = process.env.GEMINI_API_KEY;
	if (!apiKey) {
		const missingSecretError = new Error("Falta secreto GEMINI_API_KEY");
		missingSecretError.status = 500;
		throw missingSecretError;
	}

	const genAI = new GoogleGenerativeAI(apiKey);
	const model = genAI.getGenerativeModel({
		model: GEMINI_MODEL,
		systemInstruction: fieldChiefSystemInstruction,
	});

	const isPendingSummary = isPendingSummaryRequest(textoTecnico);
	const activeEquipmentName = historial?.[0]?.respuesta_ia_json?.equipo || null;

	const historialPrompt = buildHistoryForPrompt(historial);
	const equiposPrompt = formatEquipmentContextForPrompt(await getHospitalEquipmentDescriptions(20));
	const userPrompt = [
		"Mision: asistir al tecnico como jefe de mantenimiento.",
		"Responde de forma natural, profesional y tecnica. No uses JSON.",
		isPendingSummary
			? "Modo resumen de turno: puedes listar pendientes de distintos equipos si aplica."
			: `Foco de tema: responder solo sobre ${activeEquipmentName || "el equipo consultado"}. No agregues bloque de contexto/pedientes general.`,
		"[Ultimos 10 mensajes del tecnico / memoria]",
		historialPrompt,
		"[Descripcion de equipos del hospital]",
		equiposPrompt,
		"[Consulta del tecnico]",
		textoTecnico,
	].join("\n");

	const result = await model.generateContent({
		contents: [{ role: "user", parts: [{ text: userPrompt }] }],
	});

	const text = result.response.text()?.trim();
	const finalResponse = ensureTechnicalResponseFormat(text, textoTecnico);
	return {
		text: finalResponse,
	};
}

function getAxiosErrorMeta(error) {
	return {
		status: error?.response?.status || null,
		code: error?.code || null,
		message: error?.message || "UNKNOWN_ERROR",
	};
}

function escapeXml(value = "") {
	return String(value)
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/\"/g, "&quot;")
		.replace(/'/g, "&apos;");
}

function buildTwimlMessage(body = "") {
	return `<?xml version="1.0" encoding="UTF-8"?><Response><Message>${escapeXml(body)}</Message></Response>`;
}

async function sendWhatsAppReply({ accountSid, twilioAuthToken, from, to, body }) {
	if (!accountSid || !twilioAuthToken || !from || !to || !body) {
		return { sent: false, reason: "MISSING_REQUIRED_FIELDS" };
	}

	const endpoint = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
	const payload = new URLSearchParams({
		From: from,
		To: to,
		Body: body,
	});

	const authHeader = Buffer.from(`${accountSid}:${twilioAuthToken}`, "utf8").toString("base64");
	let lastError;
	for (let attempt = 0; attempt <= 2; attempt++) {
		try {
			const response = await axios.post(endpoint, payload.toString(), {
				headers: {
					"Content-Type": "application/x-www-form-urlencoded",
					Authorization: `Basic ${authHeader}`,
				},
				timeout: 30000,
			});

			return {
				sent: true,
				twilioMessageSid: response.data?.sid || null,
			};
		} catch (error) {
			lastError = error;
			const status = error?.response?.status || 0;
			const shouldRetry = status === 429 || status >= 500;
			if (!shouldRetry || attempt === 2) {
				break;
			}
			await sleep(500 + (attempt * 700));
		}
	}

	throw lastError;
}

function getExtensionFromMime(mimeType = "") {
	const normalized = String(mimeType).toLowerCase();
	if (normalized.includes("jpeg")) return ".jpg";
	if (normalized.includes("jpg")) return ".jpg";
	if (normalized.includes("png")) return ".png";
	if (normalized.includes("gif")) return ".gif";
	if (normalized.includes("webp")) return ".webp";
	if (normalized.includes("mp4")) return ".mp4";
	if (normalized.includes("mov")) return ".mov";
	if (normalized.includes("3gpp")) return ".3gp";
	return "";
}

function inferMediaType(mimeType = "") {
	const normalized = String(mimeType).toLowerCase();
	if (normalized.startsWith("image/")) return "image";
	if (normalized.startsWith("video/")) return "video";
	return "file";
}

function buildFirebaseDownloadUrl(bucketName, storagePath, token) {
	const encodedPath = encodeURIComponent(storagePath);
	return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${token}`;
}

function extractAccountSidFromTwilioMediaUrl(mediaUrl = "") {
	const match = String(mediaUrl).match(/\/Accounts\/(AC[0-9a-fA-F]{32})\//);
	return match?.[1] || "";
}

async function uploadTwilioMediaToStorage({
	mediaUrl,
	mediaContentType,
	accountSid,
	twilioAuthToken,
	storagePath,
}) {
	const authHeader = Buffer.from(`${accountSid}:${twilioAuthToken}`, "utf8").toString("base64");
	const mediaResponse = await axios.get(mediaUrl, {
		responseType: "arraybuffer",
		headers: {
			Authorization: `Basic ${authHeader}`,
		},
		maxRedirects: 5,
		timeout: 30000,
	});

	const bucket = admin.storage().bucket();
	const file = bucket.file(storagePath);
	const downloadToken = randomUUID();
	const contentType = mediaContentType || mediaResponse.headers["content-type"] || "application/octet-stream";

	await file.save(Buffer.from(mediaResponse.data), {
		metadata: {
			contentType,
			metadata: {
				firebaseStorageDownloadTokens: downloadToken,
			},
		},
		resumable: false,
	});

	return {
		storagePath,
		downloadURL: buildFirebaseDownloadUrl(bucket.name, storagePath, downloadToken),
		mediaType: inferMediaType(contentType),
		contentType,
		sizeBytes: Buffer.byteLength(mediaResponse.data),
	};
}

async function runGeminiAnalysis(textoTecnico) {
	return runGeminiAnalysisWithSessionContext({ textoTecnico });
}

async function runGeminiAnalysisWithSessionContext({ textoTecnico, sessionContext = null }) {
	const apiKey = process.env.GEMINI_API_KEY;
	if (!apiKey) {
		const missingSecretError = new Error("Falta secreto GEMINI_API_KEY");
		missingSecretError.status = 500;
		throw missingSecretError;
	}

	const genAI = new GoogleGenerativeAI(apiKey);
	const model = genAI.getGenerativeModel({
		model: GEMINI_MODEL,
		systemInstruction: fieldChiefSystemInstruction,
	});

	const explicitEquipmentName = extractEquipoNameFromConsulta(textoTecnico);
	const activeEquipmentName = explicitEquipmentName || sessionContext?.equipoNombre || null;
	const isTopicSwitch = Boolean(
		explicitEquipmentName &&
		sessionContext?.equipoNombre &&
		!areSameEquipmentName(explicitEquipmentName, sessionContext.equipoNombre),
	);
	const isPendingSummary = isPendingSummaryRequest(textoTecnico);

	const recentMessages = await getLastTechnicianMessages(
		sessionContext?.telefono || "",
		{
			limit: 10,
			activeEquipmentName,
			allowCrossTopic: isPendingSummary,
		},
	);
	const equipments = await getHospitalEquipmentDescriptions(20);

	const userPrompt = [
		"No respondas con JSON. Responde como experto tecnico.",
		isPendingSummary
			? "Modo resumen de turno: solo aqui puedes integrar pendientes de distintos equipos."
			: `Foco de tema: responde SOLO sobre ${activeEquipmentName || "el equipo actual"}. No agregues un bloque final de Contexto/Pendientes.`,
		isTopicSwitch
			? `Cambio de tema detectado: cerrar mentalmente el tema anterior (${sessionContext?.equipoNombre || "N/A"}) y trabajar ahora solo sobre ${explicitEquipmentName}.`
			: null,
		sessionContext?.equipoNombre
			? `Contexto de sesion: El tecnico esta continuando un reporte anterior sobre: ${sessionContext.equipoNombre}. Si el mensaje actual no menciona un equipo nuevo, asumi que se refiere a este mismo.`
			: null,
		"[Memoria: ultimos 10 mensajes del tecnico]",
		formatRecentMessagesForPrompt(recentMessages),
		"[Descripcion de equipos del hospital]",
		formatEquipmentContextForPrompt(equipments),
		`Reporte: ${textoTecnico}`,
	].filter(Boolean).join("\n");

	let lastError;
	for (let attempt = 0; attempt <= MAX_GEMINI_RETRIES; attempt++) {
		try {
			const geminiResult = await model.generateContent({
				contents: [{ role: "user", parts: [{ text: userPrompt }] }],
			});

			const rawText = geminiResult.response.text()?.trim() || "";
			const technicianResponse = ensureTechnicalResponseFormat(rawText, textoTecnico);
			const resolvedEquipmentName = isTopicSwitch
				? explicitEquipmentName
				: (isGenericEquipmentValue(sessionContext?.equipoNombre)
					? (extractEquipoNameFromConsulta(textoTecnico) || "No identificado")
					: (sessionContext?.equipoNombre || extractEquipoNameFromConsulta(textoTecnico) || "No identificado"));
			const parsed = {
				equipo: resolvedEquipmentName,
				estado: inferStatusFromText(`${textoTecnico} ${rawText}`),
				accion: inferActionFromText(textoTecnico),
				prioridad: inferPriorityFromText(`${textoTecnico} ${rawText}`),
				resumen: (technicianResponse || textoTecnico).slice(0, 180),
				hallazgos_tecnicos: technicianResponse,
			};
			return {
				rawText: technicianResponse,
				parsed,
				recentMessagesCount: recentMessages.length,
			};
		} catch (error) {
			lastError = error;
			const shouldRetry = error?.status === 429 || error?.status >= 500;
			if (!shouldRetry || attempt === MAX_GEMINI_RETRIES) {
				throw error;
			}

			await sleep(getRetryDelayMs(attempt));
		}
	}

	throw lastError;
}

async function getRecentSessionReportContext(telefono) {
	const lastMsgs = await db
		.collection("mensajes_ia")
		.where("telefono", "==", telefono)
		.limit(20)
		.get();

	const sortedLast = [...lastMsgs.docs].sort((a, b) => {
		const ta = a.data()?.timestamp?.toMillis?.() || 0;
		const tb = b.data()?.timestamp?.toMillis?.() || 0;
		return tb - ta;
	});

	const latest = sortedLast[0];
	if (!latest) return null;

	const data = latest.data() || {};
	const tsMs = data.timestamp?.toMillis?.() || 0;
	if (!tsMs || (Date.now() - tsMs) > SESSION_WINDOW_MS) {
		return null;
	}

	const equipoNombre =
		data?.respuesta_ia_json?.equipo ||
		data?.equipo_nombre_consulta ||
		"";

	if (!data?.equipo_id && !equipoNombre) {
		return null;
	}

	return {
		messageId: latest.id,
		modo: data.modo || null,
		equipoId: data.equipo_id || null,
		incidenteId: data.incidente_id || null,
		equipoNombre,
		timestampMs: tsMs,
	};
}

function shouldReuseSessionEquipment({ textoTecnico, sessionContext, parsedEquipmentName }) {
	if (!sessionContext?.equipoId) {
		return false;
	}

	const explicitEquipmentId = extractEquipoIdFromText(textoTecnico);
	if (explicitEquipmentId) {
		return explicitEquipmentId === sessionContext.equipoId;
	}

	const explicitEquipmentName = extractEquipoNameFromConsulta(textoTecnico);
	const normalizedSession = normalizeText(sessionContext.equipoNombre || "");
	const normalizedParsed = normalizeText(parsedEquipmentName || "");

	if (explicitEquipmentName) {
		const normalizedExplicit = normalizeText(explicitEquipmentName);
		return normalizedExplicit === normalizedSession ||
			normalizedExplicit.includes(normalizedSession) ||
			normalizedSession.includes(normalizedExplicit);
	}

	if (isGenericEquipmentValue(parsedEquipmentName)) {
		return true;
	}

	return normalizedParsed === normalizedSession ||
		normalizedParsed.includes(normalizedSession) ||
		normalizedSession.includes(normalizedParsed);
}

async function resolveIntentWithConversationContext({ textoTecnico, telefono }) {
	const baseIntent = detectIntentMode(textoTecnico);
	if (baseIntent === "consulta") {
		return "consulta";
	}

	const normalized = normalizeText(textoTecnico);
	const isShortFollowUp =
		/^(si|ok|dale|y|mas|seguir|segui|continua|continuar)\b/.test(normalized) ||
		/^(y antes|y despues|y luego|mas info)\b/.test(normalized) ||
		normalized.length <= 14;
	if (!isShortFollowUp) {
		return baseIntent;
	}

	const lastMsgs = await db
		.collection("mensajes_ia")
		.where("telefono", "==", telefono)
		.limit(10)
		.get();

	const sortedLast = [...lastMsgs.docs].sort((a, b) => {
		const ta = a.data()?.timestamp?.toMillis?.() || 0;
		const tb = b.data()?.timestamp?.toMillis?.() || 0;
		return tb - ta;
	});

	const prev = sortedLast[0]?.data();
	if (prev?.modo === "consulta") {
		return "consulta";
	}

	return baseIntent;
}

function buildTeamsTechnicianRef(activity = {}) {
	const from = activity?.from || {};
	const conversation = activity?.conversation || {};
	const channelData = activity?.channelData || {};

	return {
		id: from.id || null,
		name: from.name || null,
		aadObjectId: from.aadObjectId || channelData?.tenant?.id || null,
		conversationId: conversation.id || null,
		serviceUrl: activity?.serviceUrl || null,
		channelId: activity?.channelId || "msteams",
	};
}

async function fetchTeamsHistoryContext({ tecnicoId, equipoName, limit = 8 }) {
	if (!tecnicoId) {
		return [];
	}

	const snapshot = await db
		.collection("mensajes_teams")
		.where("tecnico.id", "==", tecnicoId)
		.limit(120)
		.get();

	const ordered = [...snapshot.docs].sort((a, b) => {
		const ta = a.data()?.timestamp?.toMillis?.() || 0;
		const tb = b.data()?.timestamp?.toMillis?.() || 0;
		return tb - ta;
	});

	const normalizedEquipo = normalizeText(equipoName || "");
	const filtered = ordered.filter((doc) => {
		const data = doc.data() || {};
		if (data.modo !== "reporte") {
			return false;
		}

		if (!normalizedEquipo) {
			return true;
		}

		const msg = normalizeText(data.mensaje_original || "");
		const equipo = normalizeText(data.equipo_nombre_consulta || data?.respuesta_ia_json?.equipo || "");
		return (equipo && (equipo.includes(normalizedEquipo) || normalizedEquipo.includes(equipo))) || msg.includes(normalizedEquipo);
	});

	return filtered.slice(0, limit).map((doc) => {
		const d = doc.data() || {};
		return {
			fecha: d.timestamp?.toDate?.()?.toISOString?.() || null,
			mensaje: d.mensaje_original || "",
			respuesta: d.respuesta_ia_tecnica || d.respuesta_ia || "",
		};
	});
}

async function runTeamsGeminiConsultation({ textoTecnico, historial }) {
	const apiKey = process.env.GEMINI_API_KEY;
	if (!apiKey) {
		throw new Error("Falta secreto GEMINI_API_KEY");
	}

	const genAI = new GoogleGenerativeAI(apiKey);
	const model = genAI.getGenerativeModel({
		model: GEMINI_MODEL,
		systemInstruction: fieldChiefSystemInstruction,
	});

	const historialPrompt = historial.length
		? historial
			.map((h, idx) => `#${idx + 1} | fecha=${h.fecha || "sin_fecha"} | tecnico=${h.mensaje} | analisis=${h.respuesta || "sin_analisis"}`)
			.join("\n")
		: "Sin historial previo para este tecnico.";

	const userPrompt = [
		"Contexto: mantenimiento hospitalario en Microsoft Teams.",
		"Responde en espanol rioplatense, concreto y tecnico.",
		"Si no hay datos suficientes, pedi 1 dato faltante puntual.",
		"[Historial Firestore del tecnico]",
		historialPrompt,
		"[Consulta actual]",
		textoTecnico,
	].join("\n");

	const result = await model.generateContent({
		contents: [{ role: "user", parts: [{ text: userPrompt }] }],
	});

	const text = result.response.text()?.trim();
	return ensureTechnicalResponseFormat(text, textoTecnico);
}

exports.teamsWebhook = onRequest({}, async (request, response) => {
	if (request.method !== "POST") {
		return response.status(405).send("Metodo no permitido");
	}

	const adapter = new BotFrameworkAdapter({
		appId: process.env.MICROSOFT_APP_ID || "59c897eb-2b85-4182-acf0-55a81cc220e9",
		appPassword: process.env.MICROSOFT_APP_PASSWORD || "",
	});

	adapter.onTurnError = async (turnContext, error) => {
		logger.error("Error en Teams bot turn", {
			error: error?.message,
			stack: error?.stack,
		});
		await turnContext.sendActivity("Hubo un error procesando tu mensaje. Intenta nuevamente.");
	};

	try {
		await adapter.processActivity(request, response, async (turnContext) => {
			if (turnContext.activity.type !== "message") {
				return;
			}

			const textoTecnico = String(turnContext.activity.text || "").trim();
			if (!textoTecnico) {
				await turnContext.sendActivity("No recibi texto en el mensaje.");
				return;
			}

			const tecnico = buildTeamsTechnicianRef(turnContext.activity);
			const intentMode = detectIntentMode(textoTecnico);
			const equipoName = extractEquipoNameFromConsulta(textoTecnico);

			if (intentMode === "reporte") {
				await db.collection("mensajes_teams").add({
					modo: "reporte",
					canal: "msteams",
					mensaje_original: textoTecnico,
					equipo_nombre_consulta: equipoName || null,
					tecnico,
					timestamp: admin.firestore.FieldValue.serverTimestamp(),
				});

				await turnContext.sendActivity("ok. registrado");
				return;
			}

			let respuestaConsulta = "No pude resolver tu consulta en este momento.";
			let iaStatus = "error";
			let iaErrorCode = "UNKNOWN";

			try {
				const historial = await fetchTeamsHistoryContext({
					tecnicoId: tecnico.id,
					equipoName,
					limit: 8,
				});

				respuestaConsulta = await runTeamsGeminiConsultation({
					textoTecnico,
					historial,
				});
				iaStatus = "ok";
				iaErrorCode = null;

				await db.collection("mensajes_teams").add({
					modo: "consulta",
					canal: "msteams",
					mensaje_original: textoTecnico,
					respuesta_ia: respuestaConsulta,
					tecnico,
					equipo_nombre_consulta: equipoName || null,
					contexto_reportes_usados: historial.length,
					ia_status: iaStatus,
					ia_error_code: iaErrorCode,
					ia_model: GEMINI_MODEL,
					timestamp: admin.firestore.FieldValue.serverTimestamp(),
				});
			} catch (consultaError) {
				if (consultaError?.status === 429) {
					respuestaConsulta = "Servicio de IA no disponible por cuota agotada. Reintentar mas tarde.";
					iaErrorCode = "QUOTA_EXCEEDED";
				} else if (consultaError?.status === 404) {
					respuestaConsulta = "Modelo de IA no disponible actualmente. Se requiere actualizar configuracion del modelo.";
					iaErrorCode = "MODEL_NOT_FOUND";
				} else if (consultaError?.message === "Falta secreto GEMINI_API_KEY") {
					respuestaConsulta = "Configuracion de IA incompleta. Falta GEMINI_API_KEY.";
					iaErrorCode = "MISSING_API_KEY_SECRET";
				}

				logger.error("Error en consulta Teams", {
					error: consultaError?.message,
					stack: consultaError?.stack,
					tecnicoId: tecnico.id,
				});

				await db.collection("mensajes_teams").add({
					modo: "consulta",
					canal: "msteams",
					mensaje_original: textoTecnico,
					respuesta_ia: respuestaConsulta,
					tecnico,
					equipo_nombre_consulta: equipoName || null,
					ia_status: iaStatus,
					ia_error_code: iaErrorCode,
					ia_model: GEMINI_MODEL,
					timestamp: admin.firestore.FieldValue.serverTimestamp(),
				});
			}

			await turnContext.sendActivity(respuestaConsulta);
		});

		return;
	} catch (error) {
		logger.error("Error en teamsWebhook", {
			error: error?.message,
			stack: error?.stack,
		});
		return response.status(500).json({
			error: "Error interno al procesar Teams webhook",
			detalle: error?.message,
		});
	}
});

exports.whatsappWebhook = onRequest({}, async (request, response) => {
	try {
		if (request.method === "GET") {
			const mode = request.query["hub.mode"];
			const token = request.query["hub.verify_token"];
			const challenge = request.query["hub.challenge"];

			if (mode === "subscribe" && token === WHATSAPP_VERIFY_TOKEN) {
				logger.info("Webhook verificado correctamente");
				return response.status(200).send(challenge);
			}

			logger.warn("Fallo de verificacion del webhook", {
				mode,
				tokenRecibido: token,
			});
			return response.status(403).send("Token de verificacion invalido");
		}

		if (request.method !== "POST") {
			return response.status(405).send("Metodo no permitido");
		}

		const textoTecnico = request.body?.Body;
		const telefono = request.body?.From || "desconocido";
		const twilioNumber = request.body?.To || "";
		const numMedia = Number.parseInt(request.body?.NumMedia || "0", 10) || 0;
		const accountSid = String(request.body?.AccountSid || "").trim();
		const twilioAuthToken = String(process.env.TWILIO_AUTH_TOKEN || "").trim();
		const intentMode = await resolveIntentWithConversationContext({
			textoTecnico,
			telefono,
		});

		logger.info("Webhook request recibida", {
			logicVersion: WEBHOOK_LOGIC_VERSION,
			telefono,
			intentMode,
		});

		if (!textoTecnico || !textoTecnico.trim()) {
			logger.info("Mensaje vacio", { telefono, body: request.body });
			return response.status(200).send("EVENT_RECEIVED");
		}

		if (intentMode === "consulta") {
			let respuestaConsulta = "No pude resolver tu consulta en este momento.";
			let iaStatusConsulta = "error";
			let iaErrorCodeConsulta = "UNKNOWN";
			let equipoIdConsulta = null;
			let equipoNameConsulta = extractEquipoNameFromConsulta(textoTecnico);
			let dateRangeConsulta = extractConsultaDateRange(textoTecnico);
			let historialConsulta = [];
			let twilioReplyMeta = null;
			let shouldReplyViaTwiml = false;
			const listadoMode = shouldUseListadoMode(textoTecnico);
			const isFollowUpYes = isAffirmativeFollowUp(textoTecnico);
			const isPaginationRequest = isPaginationFollowUp(textoTecnico);
			const isCompleteHistory = isCompleteHistoryRequest(textoTecnico);
			let paginationOffset = 0;
			let pageSize = 7;

			const lastConsultaContext = await getLastConsultaContext(telefono);
			if (!equipoNameConsulta && lastConsultaContext?.equipo_nombre_consulta) {
				equipoNameConsulta = lastConsultaContext.equipo_nombre_consulta;
			}

			if (isCompleteHistory) {
				dateRangeConsulta = null;
				pageSize = 30;
			}

			if (!dateRangeConsulta && isPaginationRequest) {
				const hasStoredAbsoluteRange =
					Number.isFinite(lastConsultaContext?.filtro_fecha_start_ms) &&
					Number.isFinite(lastConsultaContext?.filtro_fecha_end_ms);

				if (hasStoredAbsoluteRange) {
					dateRangeConsulta = {
						startMs: Number(lastConsultaContext.filtro_fecha_start_ms),
						endMs: Number(lastConsultaContext.filtro_fecha_end_ms),
						label: lastConsultaContext?.filtro_fecha || "rango_prev",
					};
				} else if (lastConsultaContext?.filtro_fecha) {
					if (lastConsultaContext.filtro_fecha === "ayer") {
						dateRangeConsulta = extractConsultaDateRange("ayer");
					} else if (lastConsultaContext.filtro_fecha === "hoy") {
						dateRangeConsulta = extractConsultaDateRange("hoy");
					}
				}
			}
			if (isPaginationRequest) {
				paginationOffset = (lastConsultaContext?.pagination_offset || 0) + 7;
			}

			try {
				equipoIdConsulta = await resolveEquipoIdForConsulta({ textoTecnico, telefono });
				if (equipoNameConsulta) {
					historialConsulta = await fetchMaintenanceHistoryForConsultaByEquipoName({
						equipoName: equipoNameConsulta,
						telefono,
						dateRange: dateRangeConsulta,
						offset: paginationOffset,
						pageSize,
					});
				} else {
					historialConsulta = await fetchMaintenanceHistoryForConsulta({
						equipoId: equipoIdConsulta,
						telefono,
						dateRange: dateRangeConsulta,
						offset: paginationOffset,
						pageSize,
					});
				}

				if (listadoMode || isPaginationRequest) {
					respuestaConsulta = buildListadoResponse({
						textoTecnico,
						historial: historialConsulta,
						dateRange: dateRangeConsulta,
						isComplete: isCompleteHistory,
						isFollowUp: isPaginationRequest,
					});
				} else {
					const consultaResult = await runGeminiConsultation({
						textoTecnico,
						historial: historialConsulta,
					});
					respuestaConsulta = consultaResult.text;
				}
				iaStatusConsulta = "ok";
				iaErrorCodeConsulta = null;

				try {
					twilioReplyMeta = await sendWhatsAppReply({
						accountSid,
						twilioAuthToken,
						from: twilioNumber,
						to: telefono,
						body: respuestaConsulta,
					});
				} catch (twilioSendError) {
					const twilioErr = getAxiosErrorMeta(twilioSendError);
					logger.error("Error enviando respuesta WhatsApp en modo consulta", {
						telefono,
						accountSid,
						error: twilioErr.message,
						status: twilioErr.status,
						code: twilioErr.code,
					});
					twilioReplyMeta = {
						sent: false,
						error: twilioErr.message || "SEND_ERROR",
						status: twilioErr.status,
						code: twilioErr.code,
					};
					shouldReplyViaTwiml = true;
				}
			} catch (consultaError) {
				if (consultaError?.status === 429) {
					respuestaConsulta = "Servicio de IA no disponible por cuota agotada. Reintentar mas tarde.";
					iaErrorCodeConsulta = "QUOTA_EXCEEDED";
				} else if (consultaError?.status === 404) {
					respuestaConsulta = "Modelo de IA no disponible actualmente. Se requiere actualizar configuracion del modelo.";
					iaErrorCodeConsulta = "MODEL_NOT_FOUND";
				} else if (consultaError?.status === 500) {
					respuestaConsulta = "Servicio de IA temporalmente inestable. Reintentar en unos minutos.";
					iaErrorCodeConsulta = "UPSTREAM_500";
				} else if (consultaError?.message === "Falta secreto GEMINI_API_KEY") {
					respuestaConsulta = "Configuracion de IA incompleta. Falta secreto GEMINI_API_KEY.";
					iaErrorCodeConsulta = "MISSING_API_KEY_SECRET";
				}

				logger.error("Error en modo consulta", {
					telefono,
					errorNombre: consultaError?.name,
					error: consultaError?.message,
					stack: consultaError?.stack,
					status: consultaError?.status,
				});

				try {
					twilioReplyMeta = await sendWhatsAppReply({
						accountSid,
						twilioAuthToken,
						from: twilioNumber,
						to: telefono,
						body: respuestaConsulta,
					});
				} catch (fallbackSendError) {
					const twilioErr = getAxiosErrorMeta(fallbackSendError);
					twilioReplyMeta = {
						sent: false,
						error: twilioErr.message || "SEND_ERROR",
						status: twilioErr.status,
						code: twilioErr.code,
					};
					logger.error("Error enviando fallback WhatsApp en modo consulta", {
						telefono,
						accountSid,
						error: twilioErr.message,
						status: twilioErr.status,
						code: twilioErr.code,
					});
					shouldReplyViaTwiml = true;
				}
			}

			await db.collection("mensajes_ia").add({
				telefono,
				mensaje_original: textoTecnico,
				respuesta_ia: respuestaConsulta,
				respuesta_ia_json: null,
				ia_status: iaStatusConsulta,
				ia_error_code: iaErrorCodeConsulta,
				ia_model: GEMINI_MODEL,
				modo: "consulta",
				equipo_id: equipoIdConsulta,
				equipo_nombre_consulta: equipoNameConsulta,
				filtro_fecha: dateRangeConsulta?.label || null,
				filtro_fecha_start_ms: dateRangeConsulta?.startMs || null,
				filtro_fecha_end_ms: dateRangeConsulta?.endMs || null,
				pagination_offset: paginationOffset,
				contexto_reportes_usados: historialConsulta.length,
				ai_internal: {
					confidence: buildInternalConfidenceForConsulta({
						historialCount: historialConsulta.length,
						equipoName: equipoNameConsulta,
						dateRangeLabel: dateRangeConsulta?.label || null,
					}),
					response_mode: listadoMode ? "listado" : "experto",
					generated_at: admin.firestore.FieldValue.serverTimestamp(),
				},
				twilio_reply_meta: twilioReplyMeta,
				timestamp: admin.firestore.FieldValue.serverTimestamp(),
			});

			logger.info("Consulta procesada", {
				telefono,
				equipoIdConsulta,
				historialUsado: historialConsulta.length,
			});
			if (shouldReplyViaTwiml) {
				return response.status(200)
					.type("text/xml")
					.send(buildTwimlMessage(respuestaConsulta));
			}
			return response.status(200).send("EVENT_RECEIVED");
		}

		let respuestaIA = "ok. registrado";
		let respuestaIATecnica = "";
		let respuestaIAJson = null;
		let iaStatus = "error";
		let iaErrorCode = "UNKNOWN";
		let reportConfidence = {
			score: 0,
			level: "baja",
			rationale: ["sin_evaluacion"],
		};
		const reportSessionContext = await getRecentSessionReportContext(telefono);
		const geminiSessionContext = {
			...reportSessionContext,
			telefono,
		};
		try {
			const geminiAnalysis = await runGeminiAnalysisWithSessionContext({
				textoTecnico,
				sessionContext: geminiSessionContext,
			});
			respuestaIAJson = geminiAnalysis.parsed;
			if (
				reportSessionContext?.equipoNombre &&
				shouldReuseSessionEquipment({
					textoTecnico,
					sessionContext: reportSessionContext,
					parsedEquipmentName: respuestaIAJson?.equipo,
				})
			) {
				respuestaIAJson = {
					...respuestaIAJson,
					equipo: reportSessionContext.equipoNombre,
				};
			}
			const willReuseSession = Boolean(
				reportSessionContext?.equipoNombre &&
				shouldReuseSessionEquipment({
					textoTecnico,
					sessionContext: reportSessionContext,
					parsedEquipmentName: respuestaIAJson?.equipo,
				}),
			);
			reportConfidence = buildInternalConfidenceForReport({
				textoTecnico,
				recentMessagesCount: geminiAnalysis.recentMessagesCount || 0,
				usedSessionContext: willReuseSession,
				parsedEquipmentName: respuestaIAJson?.equipo,
			});
			iaStatus = "ok";
			iaErrorCode = null;
			respuestaIATecnica = geminiAnalysis.rawText || `Analisis: ${respuestaIAJson.resumen}`;
		} catch (geminiError) {
			if (geminiError?.status === 429) {
				respuestaIATecnica = "Servicio de IA no disponible por cuota agotada. Reintentar mas tarde.";
				iaErrorCode = "QUOTA_EXCEEDED";
			} else if (geminiError?.status === 404) {
				respuestaIATecnica = "Modelo de IA no disponible actualmente. Se requiere actualizar configuracion del modelo.";
				iaErrorCode = "MODEL_NOT_FOUND";
			} else if (geminiError?.status === 500) {
				respuestaIATecnica = "Servicio de IA temporalmente inestable. Reintentar en unos minutos.";
				iaErrorCode = "UPSTREAM_500";
			} else if (geminiError?.message === "Falta secreto GEMINI_API_KEY") {
				respuestaIATecnica = "Configuracion de IA incompleta. Falta secreto GEMINI_API_KEY.";
				iaErrorCode = "MISSING_API_KEY_SECRET";
			}
			logger.error("Error al invocar Gemini", {
				telefono,
				errorNombre: geminiError.name,
				error: geminiError.message,
				stack: geminiError.stack,
				status: geminiError.status,
			});
		}

		const now = new Date();
		const anio = String(now.getFullYear());
		const mes = String(now.getMonth() + 1).padStart(2, "0");
		const shouldReuseEquipment = shouldReuseSessionEquipment({
			textoTecnico,
			sessionContext: reportSessionContext,
			parsedEquipmentName: respuestaIAJson?.equipo,
		});
		const equipoId = shouldReuseEquipment && reportSessionContext?.equipoId
			? reportSessionContext.equipoId
			: db.collection("equipos").doc().id;
		const incidenteId = shouldReuseEquipment && reportSessionContext?.incidenteId
			? reportSessionContext.incidenteId
			: db.collection("equipos").doc().id;
		const equipoRef = db.collection("equipos").doc(equipoId);

		await equipoRef.set({
			title: respuestaIAJson?.equipo || "No identificado",
			description: respuestaIAJson?.resumen || textoTecnico,
			tags: [
				"whatsapp",
				"twilio",
				String(respuestaIAJson?.prioridad || "Media").toLowerCase(),
			],
			status: respuestaIAJson?.estado || "Pendiente",
			priority: respuestaIAJson?.prioridad || "Media",
			source: "whatsapp_twilio",
			telefono,
			incidente_id: incidenteId,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			timestamp: admin.firestore.FieldValue.serverTimestamp(),
		}, { merge: true });

		const mediaResultados = [];
		if (numMedia > 0) {
			if (!twilioAuthToken) {
				logger.error("No se pudo procesar media: faltan credenciales Twilio", {
					telefono,
					numMedia,
					hasAccountSid: Boolean(accountSid),
					hasTwilioAuthToken: Boolean(twilioAuthToken),
				});
			} else {
				for (let index = 0; index < numMedia; index++) {
					const mediaUrl = request.body?.[`MediaUrl${index}`];
					const mediaContentType = request.body?.[`MediaContentType${index}`] || "application/octet-stream";
					if (!mediaUrl) {
						continue;
					}

					const extension = getExtensionFromMime(mediaContentType);
					const fileName = `twilio_media_${index + 1}${extension || path.extname(mediaUrl) || ""}`;
					const storagePath = `mantenimiento/equipos/${equipoRef.id}/${anio}/${mes}/${incidenteId}/${fileName}`;
					const accountSidFromMediaUrl = extractAccountSidFromTwilioMediaUrl(mediaUrl);
					const effectiveAccountSid = accountSidFromMediaUrl || accountSid;

					try {
						if (!effectiveAccountSid) {
							throw new Error("No se pudo determinar AccountSid para descargar media de Twilio");
						}

						const uploaded = await uploadTwilioMediaToStorage({
							mediaUrl,
							mediaContentType,
							accountSid: effectiveAccountSid,
							twilioAuthToken,
							storagePath,
						});

						await equipoRef.collection("media").add({
							url: uploaded.downloadURL,
							storagePath: uploaded.storagePath,
							type: uploaded.mediaType,
							name: fileName,
							caption: "Adjunto de WhatsApp",
							order: index,
							contentType: uploaded.contentType,
							sizeBytes: uploaded.sizeBytes,
							source: "twilio_whatsapp",
							timestamp: admin.firestore.FieldValue.serverTimestamp(),
							createdAt: admin.firestore.FieldValue.serverTimestamp(),
						});

						mediaResultados.push({
							index,
							ok: true,
							storagePath,
							downloadURL: uploaded.downloadURL,
						});
					} catch (mediaError) {
						logger.error("Error al descargar/subir media Twilio", {
							telefono,
							index,
							mediaUrl,
							accountSidBody: accountSid,
							accountSidFromMediaUrl,
							effectiveAccountSid,
							error: mediaError?.message,
						});
						mediaResultados.push({
							index,
							ok: false,
							mediaUrl,
							error: mediaError?.message || "Error desconocido",
						});
					}
				}
			}
		}

		let twilioReplyMeta = null;
		let shouldReplyViaTwiml = false;
		try {
			twilioReplyMeta = await sendWhatsAppReply({
				accountSid,
				twilioAuthToken,
				from: twilioNumber,
				to: telefono,
				body: respuestaIA,
			});
		} catch (twilioSendError) {
			const twilioErr = getAxiosErrorMeta(twilioSendError);
			logger.error("Error enviando respuesta WhatsApp en modo reporte", {
				telefono,
				accountSid,
				error: twilioErr.message,
				status: twilioErr.status,
				code: twilioErr.code,
			});
			twilioReplyMeta = {
				sent: false,
				error: twilioErr.message || "SEND_ERROR",
				status: twilioErr.status,
				code: twilioErr.code,
			};
			shouldReplyViaTwiml = true;
		}

		await db.collection("mensajes_ia").add({
			telefono,
			mensaje_original: textoTecnico,
			respuesta_ia: respuestaIA,
			respuesta_ia_tecnica: respuestaIATecnica,
			respuesta_ia_json: respuestaIAJson,
			ia_status: iaStatus,
			ia_error_code: iaErrorCode,
			ia_model: GEMINI_MODEL,
			modo: "reporte",
			equipo_id: equipoRef.id,
			incidente_id: incidenteId,
			num_media: numMedia,
			media_resultados: mediaResultados,
			ai_internal: {
				confidence: reportConfidence,
				response_mode: "experto",
				generated_at: admin.firestore.FieldValue.serverTimestamp(),
			},
			session_context_used: Boolean(shouldReuseEquipment && reportSessionContext),
			session_reference_message_id: reportSessionContext?.messageId || null,
			session_reference_equipo: reportSessionContext?.equipoNombre || null,
			twilio_reply_meta: twilioReplyMeta,
			timestamp: admin.firestore.FieldValue.serverTimestamp(),
		});

		logger.info("Mensaje procesado y guardado en Firestore", {
			telefono,
			equipoId: equipoRef.id,
			numMedia,
		});
		if (shouldReplyViaTwiml) {
			return response.status(200)
				.type("text/xml")
				.send(buildTwimlMessage(respuestaIA));
		}
		return response.status(200).send("EVENT_RECEIVED");
	} catch (error) {
		logger.error("Error en whatsappWebhook", error);
		return response.status(500).json({
			error: "Error interno al procesar webhook",
			detalle: error.message,
		});
	}
});
