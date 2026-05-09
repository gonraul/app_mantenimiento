#!/usr/bin/env node

const admin = require("firebase-admin");

process.env.GOOGLE_APPLICATION_CREDENTIALS = undefined;
delete process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "austral-matenimiento" });
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const LEGACY_EVENT_FIELDS = [
  "source",
  "title",
  "status",
  "priority",
  "tags",
  "telefono",
  "incidente_id",
  "twilio_reply_meta",
];

function parseArgs(argv) {
  const args = new Map();
  for (let i = 2; i < argv.length; i++) {
    const token = argv[i];
    if (token.startsWith("--")) {
      const key = token.slice(2);
      const next = argv[i + 1];
      if (!next || next.startsWith("--")) {
        args.set(key, true);
      } else {
        args.set(key, next);
        i += 1;
      }
    }
  }
  return args;
}

function normalizeText(value = "") {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim();
}

function shouldDeleteLegacyEvent(data) {
  const tipoRaw = String(data?.tipo || "").trim().toLowerCase();
  const textoRaw = String(data?.texto || "").trim().toLowerCase();
  const textoNormalized = normalizeText(data?.texto || "");

  const reasons = [];

  if (tipoRaw === "consulta") {
    reasons.push("tipo_consulta");
  }

  if (textoNormalized.includes("hipotesis")) {
    reasons.push("texto_contiene_hipotesis");
  }

  if (textoRaw.startsWith("¡dale,")) {
    reasons.push("texto_empieza_¡dale,");
  }

  if (textoRaw.startsWith("dale,")) {
    reasons.push("texto_empieza_dale,");
  }

  if (
    textoRaw.startsWith("aca estoy, decime") ||
    textoRaw.startsWith("acá estoy, decime")
  ) {
    reasons.push("texto_empieza_aca_estoy_decime");
  }

  return {
    shouldDelete: reasons.length > 0,
    reasons,
  };
}

function isEquipoEventoDoc(docRef) {
  const eventosCollection = docRef?.parent;
  const equipoDoc = eventosCollection?.parent;
  return eventosCollection?.id === "eventos" && equipoDoc?.parent?.id === "equipos";
}

async function countMensajesIa() {
  const snap = await db.collection("mensajes_ia").get();
  return { total: snap.size };
}

async function deleteMensajesIa() {
  const snap = await db.collection("mensajes_ia").get();
  let deleted = 0;
  let batch = db.batch();

  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    deleted += 1;
    if (deleted % 450 === 0) {
      await batch.commit();
      batch = db.batch();
      console.log(`Batch delete mensajes_ia: ${deleted}`);
    }
  }

  if (deleted % 450 !== 0) {
    await batch.commit();
  }

  return { deleted };
}

async function countLegacyEventFields() {
  const snap = await db.collectionGroup("eventos").get();
  let affectedDocs = 0;
  const byField = Object.fromEntries(LEGACY_EVENT_FIELDS.map((f) => [f, 0]));

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    let hasAny = false;
    for (const field of LEGACY_EVENT_FIELDS) {
      if (Object.prototype.hasOwnProperty.call(data, field)) {
        byField[field] += 1;
        hasAny = true;
      }
    }
    if (hasAny) {
      affectedDocs += 1;
    }
  }

  return {
    totalEventos: snap.size,
    affectedDocs,
    byField,
  };
}

async function cleanupLegacyEventFields() {
  const snap = await db.collectionGroup("eventos").get();
  let updated = 0;
  let batch = db.batch();

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const update = {};
    for (const field of LEGACY_EVENT_FIELDS) {
      if (Object.prototype.hasOwnProperty.call(data, field)) {
        update[field] = FieldValue.delete();
      }
    }

    if (Object.keys(update).length > 0) {
      batch.update(doc.ref, update);
      updated += 1;
      if (updated % 450 === 0) {
        await batch.commit();
        batch = db.batch();
        console.log(`Batch cleanup eventos: ${updated}`);
      }
    }
  }

  if (updated > 0 && updated % 450 !== 0) {
    await batch.commit();
  }

  return { updated };
}

async function countPdfs() {
  const snap = await db.collection("pdfs").get();
  return { total: snap.size };
}

async function countLegacyEventsToDelete() {
  const snap = await db.collectionGroup("eventos").get();
  let affectedDocs = 0;
  let totalEventosEnEquipos = 0;
  const byReason = {
    tipo_consulta: 0,
    texto_contiene_hipotesis: 0,
    "texto_empieza_¡dale,": 0,
    "texto_empieza_dale,": 0,
    texto_empieza_aca_estoy_decime: 0,
  };

  for (const doc of snap.docs) {
    if (!isEquipoEventoDoc(doc.ref)) continue;
    totalEventosEnEquipos += 1;

    const { shouldDelete, reasons } = shouldDeleteLegacyEvent(doc.data() || {});
    if (!shouldDelete) continue;
    affectedDocs += 1;
    for (const reason of reasons) {
      byReason[reason] = (byReason[reason] || 0) + 1;
    }
  }

  return {
    totalEventos: totalEventosEnEquipos,
    affectedDocs,
    byReason,
  };
}

async function deleteLegacyEvents() {
  const snap = await db.collectionGroup("eventos").get();
  let deleted = 0;
  let scanned = 0;
  const byReason = {
    tipo_consulta: 0,
    texto_contiene_hipotesis: 0,
    "texto_empieza_¡dale,": 0,
    "texto_empieza_dale,": 0,
    texto_empieza_aca_estoy_decime: 0,
  };

  let batch = db.batch();

  for (const doc of snap.docs) {
    if (!isEquipoEventoDoc(doc.ref)) continue;

    scanned += 1;
    const { shouldDelete, reasons } = shouldDeleteLegacyEvent(doc.data() || {});
    if (!shouldDelete) continue;

    batch.delete(doc.ref);
    deleted += 1;
    for (const reason of reasons) {
      byReason[reason] = (byReason[reason] || 0) + 1;
    }

    if (deleted % 450 === 0) {
      await batch.commit();
      batch = db.batch();
      console.log(`Batch delete eventos legacy: ${deleted} (scanned: ${scanned})`);
    }
  }

  if (deleted > 0 && deleted % 450 !== 0) {
    await batch.commit();
  }

  return {
    scanned,
    deleted,
    byReason,
  };
}

async function main() {
  const args = parseArgs(process.argv);
  const action = String(args.get("action") || "").trim();
  const target = String(args.get("target") || "").trim();

  if (!action || !target) {
    console.log("Uso: node scripts/cleanup_legacy_firestore.js --action <count|apply> --target <mensajes_ia|eventos_legacy_fields|eventos_legacy_delete|pdfs>");
    process.exit(1);
  }

  if (action === "count" && target === "mensajes_ia") {
    const result = await countMensajesIa();
    console.log(JSON.stringify(result));
    return;
  }

  if (action === "apply" && target === "mensajes_ia") {
    const result = await deleteMensajesIa();
    console.log(JSON.stringify(result));
    return;
  }

  if (action === "count" && target === "eventos_legacy_fields") {
    const result = await countLegacyEventFields();
    console.log(JSON.stringify(result));
    return;
  }

  if (action === "apply" && target === "eventos_legacy_fields") {
    const result = await cleanupLegacyEventFields();
    console.log(JSON.stringify(result));
    return;
  }

  if (action === "count" && target === "pdfs") {
    const result = await countPdfs();
    console.log(JSON.stringify(result));
    return;
  }

  if (action === "count" && target === "eventos_legacy_delete") {
    const result = await countLegacyEventsToDelete();
    console.log(JSON.stringify(result));
    return;
  }

  if (action === "apply" && target === "eventos_legacy_delete") {
    const result = await deleteLegacyEvents();
    console.log(JSON.stringify(result));
    return;
  }

  console.error("Combinacion de action/target no soportada");
  process.exit(1);
}

main().catch((error) => {
  console.error("Error cleanup:", error?.message || error);
  process.exit(1);
});
