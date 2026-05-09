#!/usr/bin/env node

const admin = require("firebase-admin");

const PROJECT_ID = "austral-matenimiento";
const DEFAULT_BUCKET = `${PROJECT_ID}.firebasestorage.app`;

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET || DEFAULT_BUCKET,
  });
}

const bucket = admin.storage().bucket();

const args = new Set(process.argv.slice(2));
const shouldApply = args.has("--apply");
const isPreview = !shouldApply;

const MANUAL_FILE_NAME = "GUIA TRANSFERENCIA DE ENERGIA SEMIAUTOMATICA.png";
const WHATSAPP_PREFIX_PATTERNS = [
  /^whatsapp image 2025-07-15/i,
  /^whatsapp image 2025-07-16/i,
];

function buildDestination(fileName) {
  if (fileName === MANUAL_FILE_NAME) {
    return `pdfs/manuales/${fileName}`;
  }

  if (WHATSAPP_PREFIX_PATTERNS.some((pattern) => pattern.test(fileName))) {
    return `mantenimiento/sin_asignar/${fileName}`;
  }

  return null;
}

function isRootObject(filePath) {
  return !String(filePath || "").includes("/");
}

async function collectRootObjects() {
  const files = [];
  let nextQuery = {};

  do {
    const [pageFiles, , queryForNextPage] = await bucket.getFiles({
      autoPaginate: false,
      maxResults: 1000,
      ...nextQuery,
    });

    files.push(...pageFiles);
    nextQuery = queryForNextPage?.pageToken
      ? { pageToken: queryForNextPage.pageToken }
      : null;
  } while (nextQuery);

  return files.filter((file) => isRootObject(file.name));
}

async function planMoves() {
  const rootFiles = await collectRootObjects();
  const mapped = [];

  for (const file of rootFiles) {
    const source = file.name;
    const destination = buildDestination(source);
    if (!destination) continue;

    const metadata = file.metadata || {};
    mapped.push({
      source,
      destination,
      size: Number(metadata.size || 0),
      updated: metadata.updated || null,
      md5Hash: metadata.md5Hash || null,
    });
  }

  mapped.sort((a, b) => a.source.localeCompare(b.source));

  return {
    bucket: bucket.name,
    rootObjectsScanned: rootFiles.length,
    plannedMoves: mapped.length,
    moves: mapped,
  };
}

async function applyMoves(plan) {
  const results = [];

  for (const move of plan.moves) {
    const sourceFile = bucket.file(move.source);
    const destinationFile = bucket.file(move.destination);

    await sourceFile.copy(destinationFile);

    const [srcMetadata] = await sourceFile.getMetadata();
    const [dstMetadata] = await destinationFile.getMetadata();
    const sameSize = String(srcMetadata.size || "") === String(dstMetadata.size || "");
    const sameMd5 = String(srcMetadata.md5Hash || "") === String(dstMetadata.md5Hash || "");

    if (!sameSize || !sameMd5) {
      throw new Error(
        `Verificacion fallida para ${move.source} -> ${move.destination} (size/md5 no coinciden)`,
      );
    }

    await sourceFile.delete();

    results.push({
      source: move.source,
      destination: move.destination,
      status: "moved",
    });
  }

  return {
    moved: results.length,
    results,
  };
}

async function main() {
  console.log(`Modo: ${isPreview ? "PREVIEW" : "APPLY"}`);
  console.log(`Bucket: ${bucket.name}`);

  const plan = await planMoves();
  console.log(JSON.stringify(plan, null, 2));

  if (isPreview) {
    console.log("Preview activa: no se movio ningun archivo.");
    console.log("Para aplicar: node scripts/storage_reorg_plan.js --apply");
    return;
  }

  const result = await applyMoves(plan);
  console.log(JSON.stringify(result, null, 2));
}

main().catch((error) => {
  console.error("Error storage reorg:", error?.message || error);
  process.exit(1);
});
