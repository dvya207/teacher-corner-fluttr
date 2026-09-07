// READ ONLY. Does the file actually exist in Cloud Storage?
//
// Firestore holding a path proves nothing about the bytes being there, and the
// two failures look identical in the app: a tab that will not render. This
// walks one unit's resource paths across all three stores and reports EXISTS
// or MISSING with the content type and size.
//
//   node tools/verify_storage.js
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

const app = initializeApp({
  projectId: 'helix-staging-india',
  storageBucket: 'helix-staging-india.firebasestorage.app',
});
const db = getFirestore(app, 'teacher-corner-dev');
const UNIT = '2awVLuyYaxFqMFuVp3Ny';

(async () => {
  const unit = await db.collection('learningUnits').doc(UNIT).get();
  const store2 = unit.get('resources') || {};

  const res = await db.collection('learningUnitResources')
    .where('learningUnitDocId', '==', UNIT).get();

  const bgr = await db.collection('boardGradeResources')
    .where('learningUnitDocId', '==', UNIT).get();

  const want = [];
  const add = (label, p) => {
    if (typeof p === 'string' && p.trim() && !/^https?:\/\//i.test(p)) {
      want.push({ label, path: p.trim() });
    }
  };

  for (const slot of ['guidePath', 'materialPath', 'observationPath',
                      'topicGuidePath', 'varGuidePath', 'templatePath']) {
    add(`store2  ${slot}`, store2[slot]);
  }
  for (const d of res.docs) {
    for (const [cat, group] of Object.entries(d.get('resources') || {})) {
      if (!group || typeof group !== 'object') continue;
      for (const [key, raw] of Object.entries(group)) {
        if (typeof raw === 'string') add(`store1  ${cat}.${key}`, raw);
      }
    }
  }
  for (const d of bgr.docs) {
    for (const [g, p] of Object.entries(d.get('resources') || {})) {
      add(`store3  ${d.get('category')}.${d.get('subCategory')} ${g}`, p);
    }
  }

  const bucket = getStorage(app).bucket();
  const seen = new Set();
  for (const { label, path } of want) {
    const key = `${label}|${path}`;
    if (seen.has(key)) continue;
    seen.add(key);
    try {
      const [exists] = await bucket.file(path).exists();
      if (!exists) { console.log(`MISSING  ${label}\n         ${path}`); continue; }
      const [md] = await bucket.file(path).getMetadata();
      console.log(`EXISTS   ${label}`);
      console.log(`         ${path}`);
      console.log(`         ${md.contentType}  ${md.size} bytes`);
    } catch (e) {
      console.log(`ERROR    ${label}: ${e.message}`);
    }
  }
  process.exit(0);
})().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
