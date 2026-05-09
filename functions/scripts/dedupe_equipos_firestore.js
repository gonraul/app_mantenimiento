#!/usr/bin/env node

const admin = require("firebase-admin");

process.env.GOOGLE_APPLICATION_CREDENTIALS = undefined;
delete process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "austral-matenimiento" });
}

const db = admin.firestore();

const args = new Set(process.argv.slice(2));
const shouldApply = args.has("--apply");
const isPreview = !shouldApply;

function normalizeName(value = "") {
  return String(value || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ");
}

function toDateSafe(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function pickPrincipal(a, b) {
  if (a.eventCount !== b.eventCount) {
    return a.eventCount > b.eventCount ? a : b;
  }

  const aDate = a.referenceDate || new Date(8640000000000000);
  const bDate = b.referenceDate || new Date(8640000000000000);
  if (aDate.getTime() !== bDate.getTime()) {
    return aDate.getTime() < bDate.getTime() ? a : b;
  }

  return a.id < b.id ? a : b;
}

async function buildGroups() {
  const equiposSnap = await db.collection("equipos").get();
  const eventosSnap = await db.collectionGroup("eventos").get();
  const groups = new Map();
  const eventStatsByEquipoId = new Map();

  for (const eventDoc of eventosSnap.docs) {
    const equipoRef = eventDoc.ref.parent.parent;
    if (!equipoRef || equipoRef.parent.id !== "equipos") continue;
    const equipoId = equipoRef.id;

    const eventDate = toDateSafe(eventDoc.data()?.timestamp);
    const stats = eventStatsByEquipoId.get(equipoId) || {
      count: 0,
      firstDate: null,
    };
    stats.count += 1;
    if (eventDate) {
      if (!stats.firstDate || eventDate.getTime() < stats.firstDate.getTime()) {
        stats.firstDate = eventDate;
      }
    }
    eventStatsByEquipoId.set(equipoId, stats);
  }

  let processed = 0;

  for (const doc of equiposSnap.docs) {
    const data = doc.data() || {};
    const nombreRaw = String(data.nombre || data.title || "").trim();
    const key = normalizeName(nombreRaw);
    if (!key) continue;

    const stats = eventStatsByEquipoId.get(doc.id) || { count: 0, firstDate: null };
    const firstEventDate = stats.firstDate;

    const createdAt = toDateSafe(data.createdAt);
    const timestamp = toDateSafe(data.timestamp);
    const referenceDate = createdAt || timestamp || firstEventDate;

    const entry = {
      id: doc.id,
      ref: doc.ref,
      nombre: nombreRaw,
      eventCount: stats.count,
      referenceDate,
    };

    if (!groups.has(key)) {
      groups.set(key, {
        key,
        displayName: nombreRaw,
        docs: [],
      });
    }

    groups.get(key).docs.push(entry);

    processed += 1;
    if (processed % 10 === 0 || processed === equiposSnap.size) {
      console.log(`- Analizados ${processed}/${equiposSnap.size} equipos`);
    }
  }

  return [...groups.values()]
    .map((group) => {
      const principal = group.docs.reduce((best, current) =>
        pickPrincipal(best, current),
      );
      const duplicates = group.docs.filter((d) => d.id !== principal.id);
      return {
        ...group,
        principal,
        duplicates,
      };
    })
    .filter((group) => group.duplicates.length > 0)
    .sort((a, b) => b.docs.length - a.docs.length);
}

async function applyGroup(group) {
  const principalRef = group.principal.ref;
  let movedEvents = 0;
  let deletedDocs = 0;

  for (const duplicate of group.duplicates) {
    const dupEventsSnap = await duplicate.ref.collection("eventos").get();

    let batch = db.batch();
    let opsInBatch = 0;

    for (const eventDoc of dupEventsSnap.docs) {
      const eventData = eventDoc.data() || {};
      const newEventRef = principalRef.collection("eventos").doc();

      batch.set(newEventRef, {
        ...eventData,
        migrated_from_equipo_id: duplicate.id,
        migrated_from_evento_id: eventDoc.id,
        migrated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      opsInBatch += 1;

      batch.delete(eventDoc.ref);
      opsInBatch += 1;

      movedEvents += 1;
      if (opsInBatch >= 400) {
        await batch.commit();
        batch = db.batch();
        opsInBatch = 0;
      }
    }

    batch.delete(duplicate.ref);
    opsInBatch += 1;
    deletedDocs += 1;

    if (opsInBatch > 0) {
      await batch.commit();
    }
  }

  return { movedEvents, deletedDocs };
}

async function main() {
  console.log("=== Dedupe equipos por nombre ===");
  console.log(`Modo: ${isPreview ? "PREVIEW" : "APPLY"}`);

  const groups = await buildGroups();

  if (groups.length === 0) {
    console.log("No se detectaron nombres duplicados.");
    return;
  }

  console.log(`Nombres duplicados detectados: ${groups.length}`);
  for (const group of groups) {
    console.log(`- ${group.displayName}: ${group.docs.length} docs`);
  }

  if (isPreview) {
    console.log("\nDetalle por grupo (preview):");
    for (const group of groups) {
      console.log(
        `* ${group.displayName}: principal=${group.principal.id} (eventos=${group.principal.eventCount}), duplicados=${group.duplicates.length}`,
      );
    }
    console.log("\nPreview activa: no se escribio nada en Firestore.");
    console.log("Para aplicar: node scripts/dedupe_equipos_firestore.js --apply");
    return;
  }

  let totalMoved = 0;
  let totalDeleted = 0;
  for (const group of groups) {
    const result = await applyGroup(group);
    totalMoved += result.movedEvents;
    totalDeleted += result.deletedDocs;
    console.log(
      `Grupo ${group.displayName}: eventos_movidos=${result.movedEvents}, docs_eliminados=${result.deletedDocs}`,
    );
  }

  console.log("\nDedupe finalizado.");
  console.log(`- eventos movidos: ${totalMoved}`);
  console.log(`- documentos duplicados eliminados: ${totalDeleted}`);
}

main().catch((error) => {
  console.error("Fallo dedupe:", error);
  process.exitCode = 1;
});
