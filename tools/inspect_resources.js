// READ ONLY diagnosis of the TWO resource stores a learning unit has. Writes
// nothing, and is here because "the tab is empty" has two completely different
// causes and this is the only way to tell them apart:
//
//   STORE 1  learningUnitResources/{doc}.resources[category][subCategory]
//            One document per maturity rung. Where video, tacDev, 3S,
//            graphics and socialMedia uploads go.
//   STORE 2  learningUnits/{id}.resources[slot]
//            No maturity. The web app's nine "External Resources": guidePath,
//            observationPath, materialPath, videoUrl, templatePath,
//            topicGuidePath, topicVideoUrl, varGuidePath, varVideoUrl.
//            A workflow step reaches these with contentCategory
//            'externalResources'.
//
// Note store 2's map ALSO holds the maturity rung keys, whose values are
// document ids pointing into store 1 rather than files.
//
//   node tools/inspect_resources.js
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const app = initializeApp({ projectId: 'helix-staging-india' });
const db = getFirestore(app, 'teacher-corner-dev');

const leaf = (v) => {
  if (typeof v === 'string') return v.trim();
  if (v && typeof v === 'object') {
    return (Object.values(v).find((x) => typeof x === 'string' && x.trim()) || '').trim();
  }
  return '';
};

(async () => {
  const units = await db.collection('learningUnits').get();
  for (const u of units.docs) {
    const name = u.get('learningUnitDisplayName') || u.get('learningUnitName');
    console.log(`\n===== ${name}  (${u.id})  maturity=${u.get('Maturity')}`);

    console.log('  STORE 2 — learningUnits/<id>.resources (External Resources, no maturity):');
    const own = u.get('resources') || {};
    let any2 = false;
    for (const [k, v] of Object.entries(own)) {
      const val = leaf(v);
      if (val) { any2 = true; console.log(`      ${k} = ${val.slice(0, 90)}`); }
    }
    if (!any2) console.log('      (all empty)');

    console.log('  STORE 1 — learningUnitResources (per maturity rung):');
    const res = await db.collection('learningUnitResources')
      .where('learningUnitDocId', '==', u.id).get();
    if (res.empty) console.log('      (no document)');
    for (const d of res.docs) {
      console.log(`      [${d.get('maturity') || '(none)'}] ${d.id}`);
      const groups = d.get('resources') || {};
      for (const [cat, group] of Object.entries(groups)) {
        if (!group || typeof group !== 'object') continue;
        const filled = Object.entries(group)
          .map(([k, raw]) => [k, leaf(raw)])
          .filter(([, v]) => v);
        if (filled.length) {
          console.log(`          ${cat}: ${filled.map(([k]) => k).join(', ')}`);
        }
      }
    }
  }
  process.exit(0);
})().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
