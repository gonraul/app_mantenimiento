#!/usr/bin/env node

const admin = require("firebase-admin");
process.env.GOOGLE_APPLICATION_CREDENTIALS = undefined;
delete process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!admin.apps.length) {
	admin.initializeApp({
		projectId: "austral-matenimiento",
	});
}

const db = admin.firestore();

const args = new Set(process.argv.slice(2));
const shouldApply = args.has("--apply");
const previewOnly = !shouldApply;
const UNASSIGNED_EQUIPO_ID = "sin_asignar_migracion";

function normalizeText(value = "") {
	return String(value)
		.toLowerCase()
		.normalize("NFD")
		.replace(/[\u0300-\u036f]/g, "")
		.replace(/[^a-z0-9\s]/g, " ")
		.replace(/\s+/g, " ")
		.trim();
}

function toSafeString(value, fallback = "") {
	if (value === null || value === undefined) return fallback;
	const text = String(value).trim();
	return text || fallback;
}

function inferEventType(modo = "") {
	const n = normalizeText(modo);
	if (n === "consulta") return "consulta";
	if (n === "reporte") return "reporte";
	return "mantenimiento";
}

function inferFileType(inputType = "", url = "", name = "") {
	const source = normalizeText(`${inputType} ${url} ${name}`);
	if (/manual|pdf|doc|xls|txt/.test(source)) return "manual";
	if (/video|mp4|mov|avi|mkv|webm/.test(source)) return "video";
	return "foto";
}

function inferEquipoBase(docData = {}) {
	const nombre = toSafeString(docData.nombre || docData.title, "Sin nombre");
	const tipo = toSafeString(
		docData.tipo || docData.areaTecnica || docData.category || (Array.isArray(docData.tags) ? docData.tags[0] : ""),
		"general",
	);

	const ubicacionParts = [
		toSafeString(docData.ubicacion || docData.location),
		toSafeString(docData.piso),
		toSafeString(docData.area),
	].filter(Boolean);
	const ubicacion = toSafeString(ubicacionParts.join(" - "), "sin ubicacion");

	return { nombre, tipo, ubicacion };
}

function parseTimestamp(value) {
	if (!value) return null;
	if (typeof value.toDate === "function") {
		return value;
	}
	if (value instanceof Date) {
		return admin.firestore.Timestamp.fromDate(value);
	}
	return null;
}

async function loadEquipos() {
	console.log("- Cargando equipos...");
	const snapshot = await db.collection("equipos").get();
	const byId = new Map();
	const byName = new Map();

	for (const doc of snapshot.docs) {
		const data = doc.data() || {};
		const base = inferEquipoBase(data);
		const entry = {
			id: doc.id,
			ref: doc.ref,
			data,
			base,
		};
		byId.set(doc.id, entry);
		const key = normalizeText(base.nombre);
		if (key && !byName.has(key)) {
			byName.set(key, entry);
		}
	}

	return { byId, byName, snapshot };
}

function resolveEquipoFromMessage({ equipoId, equipoNombre, equiposIndex }) {
	if (equipoId && equiposIndex.byId.has(equipoId)) {
		return equiposIndex.byId.get(equipoId);
	}

	const key = normalizeText(equipoNombre || "");
	if (key && equiposIndex.byName.has(key)) {
		return equiposIndex.byName.get(key);
	}

	return null;
}

async function collectPreview(equiposIndex) {
	console.log("- Leyendo colecciones legacy (mensajes_ia, mensajes_teams)...");
	const mensajesIaSnapshot = await db.collection("mensajes_ia").get();
	const mensajesTeamsSnapshot = await db.collection("mensajes_teams").get();

	let equiposConMedia = 0;
	let mediaDocsTotal = 0;
	let scanned = 0;

	for (const equipo of equiposIndex.byId.values()) {
		const mediaSnapshot = await equipo.ref.collection("media").get();
		scanned += 1;
		if (scanned % 10 === 0 || scanned === equiposIndex.byId.size) {
			console.log(`- Escaneados media de ${scanned}/${equiposIndex.byId.size} equipos`);
		}
		if (!mediaSnapshot.empty) {
			equiposConMedia += 1;
			mediaDocsTotal += mediaSnapshot.size;
		}
	}

	const iaByMode = { reporte: 0, consulta: 0, mantenimiento: 0, otro: 0 };
	for (const doc of mensajesIaSnapshot.docs) {
		const mode = normalizeText(doc.data()?.modo || "");
		if (mode === "reporte") iaByMode.reporte += 1;
		else if (mode === "consulta") iaByMode.consulta += 1;
		else if (mode === "mantenimiento") iaByMode.mantenimiento += 1;
		else iaByMode.otro += 1;
	}

	const teamsByMode = { reporte: 0, consulta: 0, mantenimiento: 0, otro: 0 };
	for (const doc of mensajesTeamsSnapshot.docs) {
		const mode = normalizeText(doc.data()?.modo || "");
		if (mode === "reporte") teamsByMode.reporte += 1;
		else if (mode === "consulta") teamsByMode.consulta += 1;
		else if (mode === "mantenimiento") teamsByMode.mantenimiento += 1;
		else teamsByMode.otro += 1;
	}

	const unresolvedIa = mensajesIaSnapshot.docs.filter((doc) => {
		const data = doc.data() || {};
		const resolved = resolveEquipoFromMessage({
			equipoId: data.equipo_id,
			equipoNombre: data?.respuesta_ia_json?.equipo,
			equiposIndex,
		});
		return !resolved;
	}).length;

	const unresolvedTeams = mensajesTeamsSnapshot.docs.filter((doc) => {
		const data = doc.data() || {};
		const resolved = resolveEquipoFromMessage({
			equipoNombre: data.equipo_nombre_consulta || data?.respuesta_ia_json?.equipo,
			equiposIndex,
		});
		return !resolved;
	}).length;

	return {
		equiposTotal: equiposIndex.snapshot.size,
		equiposConMedia,
		mediaDocsTotal,
		mensajesIaTotal: mensajesIaSnapshot.size,
		mensajesTeamsTotal: mensajesTeamsSnapshot.size,
		iaByMode,
		teamsByMode,
		unresolvedIa,
		unresolvedTeams,
		mensajesIaSnapshot,
		mensajesTeamsSnapshot,
	};
}

async function upsertEquipoBase(equipoEntry, batch) {
	batch.set(
		equipoEntry.ref,
		{
			nombre: equipoEntry.base.nombre,
			tipo: equipoEntry.base.tipo,
			ubicacion: equipoEntry.base.ubicacion,
		},
		{ merge: true },
	);
}

function eventPayload({ texto, tipo, tecnico, canal, timestamp }) {
	return {
		texto: toSafeString(texto, "Sin detalle"),
		tipo: ["reporte", "consulta", "mantenimiento"].includes(tipo) ? tipo : "mantenimiento",
		tecnico: toSafeString(tecnico, "desconocido"),
		canal: ["teams", "app", "google_chat"].includes(canal) ? canal : "app",
		timestamp: timestamp || admin.firestore.FieldValue.serverTimestamp(),
	};
}

function queueSet(ops, ref, data, options = { merge: true }) {
	ops.push({ type: "set", ref, data, options });
}

function queueFileFromLegacy({ ops, equipoRef, eventId, fileId, raw }) {
	const eventRef = equipoRef.collection("eventos").doc(eventId);
	queueSet(
		ops,
		eventRef,
		eventPayload({
			texto: "Migracion de archivos legacy",
			tipo: "mantenimiento",
			tecnico: "migracion_script",
			canal: "app",
			timestamp: admin.firestore.FieldValue.serverTimestamp(),
		}),
	);

	queueSet(ops, eventRef.collection("archivos").doc(fileId), {
		tipo: inferFileType(raw.type, raw.url, raw.name),
		url: toSafeString(raw.url, ""),
		nombre: toSafeString(raw.name, "archivo_sin_nombre"),
	});
}

async function migrate(preview, equiposIndex) {
	const ops = [];
	let unresolvedIaMigrated = 0;
	let unresolvedTeamsMigrated = 0;
	console.log("- Preparando operaciones de migracion...");

	const unassignedRef = db.collection("equipos").doc(UNASSIGNED_EQUIPO_ID);
	queueSet(ops, unassignedRef, {
		nombre: "Sin asignar (migracion)",
		tipo: "sistema",
		ubicacion: "sin ubicacion",
		title: "Sin asignar (migracion)",
		description: "Contenedor temporal para eventos legacy sin equipo resoluble.",
		source: "migration_script",
		updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		createdAt: admin.firestore.FieldValue.serverTimestamp(),
	}, { merge: true });

	let preparedEquipos = 0;
	for (const equipo of equiposIndex.byId.values()) {
		upsertEquipoBase(equipo, { set: (...args) => queueSet(ops, ...args) });

		const data = equipo.data || {};
		if (toSafeString(data.description)) {
			queueSet(
				ops,
				equipo.ref.collection("eventos").doc(`legacy_equipo_${equipo.id}`),
				eventPayload({
					texto: data.description,
					tipo: "mantenimiento",
					tecnico: toSafeString(data.telefono, "legacy"),
					canal: "app",
					timestamp: parseTimestamp(data.timestamp) || parseTimestamp(data.createdAt),
				}),
			);
		}

		preparedEquipos += 1;
		if (preparedEquipos % 10 === 0 || preparedEquipos === equiposIndex.byId.size) {
			console.log(`- Preparacion equipos ${preparedEquipos}/${equiposIndex.byId.size}`);
		}

		const legacyArchivos = Array.isArray(data.archivos) ? data.archivos : [];
		legacyArchivos.forEach((url, index) => {
			queueFileFromLegacy({
				ops,
				equipoRef: equipo.ref,
				eventId: "legacy_archivos_event",
				fileId: `archivo_${index + 1}`,
				raw: { type: "", url, name: `archivo_${index + 1}` },
			});
		});

		const legacyDocuments = Array.isArray(data.documents) ? data.documents : [];
		legacyDocuments.forEach((file, index) => {
			const mapped = typeof file === "object" && file
				? file
				: { url: String(file || "") };
			queueFileFromLegacy({
				ops,
				equipoRef: equipo.ref,
				eventId: "legacy_documents_event",
				fileId: `document_${index + 1}`,
				raw: {
					type: mapped.type,
					url: mapped.url || mapped.storagePath,
					name: mapped.name || `document_${index + 1}`,
				},
			});
		});
	}
	console.log(`- Operaciones preparadas tras equipos base: ${ops.length}`);

	const mediaGroupSnapshot = await db.collectionGroup("media").get();
	for (const mediaDoc of mediaGroupSnapshot.docs) {
		const media = mediaDoc.data() || {};
		const equipoRef = mediaDoc.ref.parent.parent;
		if (!equipoRef || equipoRef.parent.id !== "equipos") continue;

		queueFileFromLegacy({
			ops,
			equipoRef,
			eventId: "legacy_media_event",
			fileId: mediaDoc.id,
			raw: {
				type: media.type,
				url: media.url,
				name: media.name,
			},
		});
	}
	console.log(`- Operaciones preparadas tras media legacy: ${ops.length}`);

	for (const doc of preview.mensajesIaSnapshot.docs) {
		const data = doc.data() || {};
		let equipo = resolveEquipoFromMessage({
			equipoId: data.equipo_id,
			equipoNombre: data?.respuesta_ia_json?.equipo,
			equiposIndex,
		});
		if (!equipo) {
			equipo = {
				id: UNASSIGNED_EQUIPO_ID,
				ref: unassignedRef,
			};
			unresolvedIaMigrated += 1;
		}

		const eventRef = equipo.ref.collection("eventos").doc(`msg_ia_${doc.id}`);
		queueSet(ops, eventRef, eventPayload({
			texto: data.mensaje_original || data.respuesta_ia || data?.respuesta_ia_json?.resumen,
			tipo: inferEventType(data.modo),
			tecnico: toSafeString(data.telefono, "whatsapp"),
			canal: "app",
			timestamp: parseTimestamp(data.timestamp),
		}));

		const mediaResultados = Array.isArray(data.media_resultados) ? data.media_resultados : [];
		for (let index = 0; index < mediaResultados.length; index++) {
			const item = mediaResultados[index] || {};
			if (!item.ok || !item.downloadURL) continue;
			queueSet(ops, eventRef.collection("archivos").doc(`media_${index + 1}`), {
				tipo: inferFileType("", item.downloadURL, item.storagePath),
				url: item.downloadURL,
				nombre: toSafeString(item.storagePath, `media_${index + 1}`),
			});
		}
	}
	console.log(`- Operaciones preparadas tras mensajes_ia: ${ops.length}`);

	for (const doc of preview.mensajesTeamsSnapshot.docs) {
		const data = doc.data() || {};
		let equipo = resolveEquipoFromMessage({
			equipoNombre: data.equipo_nombre_consulta || data?.respuesta_ia_json?.equipo,
			equiposIndex,
		});
		if (!equipo) {
			equipo = {
				id: UNASSIGNED_EQUIPO_ID,
				ref: unassignedRef,
			};
			unresolvedTeamsMigrated += 1;
		}

		queueSet(
			ops,
			equipo.ref.collection("eventos").doc(`msg_teams_${doc.id}`),
			eventPayload({
				texto: data.mensaje_original || data.respuesta_ia,
				tipo: inferEventType(data.modo),
				tecnico: toSafeString(data?.tecnico?.name || data?.tecnico?.id, "teams"),
				canal: "teams",
				timestamp: parseTimestamp(data.timestamp),
			}),
		);
	}
	console.log(`- Operaciones totales preparadas: ${ops.length}`);

	console.log(`\nOperaciones preparadas: ${ops.length}`);
	console.log(`- mensajes_ia no resolubles migrados en ${UNASSIGNED_EQUIPO_ID}: ${unresolvedIaMigrated}`);
	console.log(`- mensajes_teams no resolubles migrados en ${UNASSIGNED_EQUIPO_ID}: ${unresolvedTeamsMigrated}`);
	if (previewOnly) {
		console.log("Preview activa: no se escribio nada en Firestore.");
		console.log("Para ejecutar la migracion: node scripts/migrate_firestore_schema.js --apply");
		return;
	}

	let batch = db.batch();
	let count = 0;
	console.log("- Iniciando escritura en batches...");
	for (const op of ops) {
		batch.set(op.ref, op.data, op.options);
		count += 1;
		if (count % 450 === 0) {
			await batch.commit();
			batch = db.batch();
			console.log(`Batch commit ok: ${count} operaciones`);
		}
	}

	if (count % 450 !== 0) {
		await batch.commit();
	}

	console.log(`Migracion finalizada. Operaciones escritas: ${count}`);
}

async function main() {
	console.log("=== Firestore migration preview ===");
	console.log(`Modo: ${previewOnly ? "PREVIEW (sin cambios)" : "APPLY"}`);

	const equiposIndex = await loadEquipos();
	const preview = await collectPreview(equiposIndex);

	console.log("\nHallazgos previos:");
	console.log(`- equipos: ${preview.equiposTotal}`);
	console.log(`- equipos con media subcollection: ${preview.equiposConMedia}`);
	console.log(`- docs en equipos/*/media: ${preview.mediaDocsTotal}`);
	console.log(`- mensajes_ia: ${preview.mensajesIaTotal}`);
	console.log(`  - por modo: ${JSON.stringify(preview.iaByMode)}`);
	console.log(`- mensajes_teams: ${preview.mensajesTeamsTotal}`);
	console.log(`  - por modo: ${JSON.stringify(preview.teamsByMode)}`);
	console.log(`- mensajes_ia sin equipo resoluble: ${preview.unresolvedIa}`);
	console.log(`- mensajes_teams sin equipo resoluble: ${preview.unresolvedTeams}`);

	await migrate(preview, equiposIndex);
}

main().catch((error) => {
	console.error("Fallo la migracion:", error);
	process.exitCode = 1;
});
