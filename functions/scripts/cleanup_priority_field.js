/**
 * Script: cleanup_priority_field.js
 * Elimina el campo "priority" de todos los documentos en la colección "equipos".
 * Ejecutar con: node scripts/cleanup_priority_field.js
 * Desde la carpeta functions/ con el entorno de Node configurado.
 */

const admin = require('firebase-admin');

process.env.GOOGLE_APPLICATION_CREDENTIALS = undefined;
delete process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'austral-matenimiento' });
}

const db = admin.firestore();

async function main() {
  const colRef = db.collection('equipos');
  const snapshot = await colRef.get();

  const docsConPriority = snapshot.docs.filter(
    (doc) => doc.data().priority !== undefined
  );

  console.log(`Total documentos en "equipos": ${snapshot.size}`);
  console.log(`Documentos con campo "priority": ${docsConPriority.length}`);

  if (docsConPriority.length === 0) {
    console.log('Nada que limpiar. El campo priority ya no existe en ningún documento.');
    process.exit(0);
  }

  console.log('\nDocumentos a modificar:');
  docsConPriority.forEach((doc) => {
    console.log(`  - ${doc.id} | priority: "${doc.data().priority}" | title: "${doc.data().title ?? '(sin título)'}"`);
  });

  console.log('\nEjecutando limpieza...');

  // Procesar en lotes de 500 (límite de Firestore batch)
  const BATCH_SIZE = 500;
  let procesados = 0;

  for (let i = 0; i < docsConPriority.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const lote = docsConPriority.slice(i, i + BATCH_SIZE);

    lote.forEach((doc) => {
      batch.update(doc.ref, {
        priority: admin.firestore.FieldValue.delete(),
      });
    });

    await batch.commit();
    procesados += lote.length;
    console.log(`  Lote procesado: ${procesados}/${docsConPriority.length}`);
  }

  console.log(`\n✅ Listo. Campo "priority" eliminado de ${procesados} documentos.`);
  process.exit(0);
}

main().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});
