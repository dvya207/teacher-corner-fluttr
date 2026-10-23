// READ ONLY. Which description field each learning unit actually has filled,
// so the fallback chain is ordered against the data rather than guessed.
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const app = initializeApp({ projectId: 'helix-staging-india' });
const db = getFirestore(app, 'teacher-corner-dev');
const FIELDS = ['longDescription', 'shortDescription', 'alternateLongDescription',
                'alternateShortDescription', 'tinyDescription'];
(async () => {
  const snap = await db.collection('learningUnits').get();
  const filled = Object.fromEntries(FIELDS.map((f) => [f, 0]));
  for (const d of snap.docs) {
    const name = d.get('learningUnitDisplayName') || d.get('learningUnitName');
    const has = FIELDS.filter((f) => String(d.get(f) ?? '').trim());
    console.log(`${name}: ${has.length ? has.join(', ') : '(no description at all)'}`);
    for (const f of has) filled[f] += 1;
    for (const f of has) {
      const v = String(d.get(f)).trim();
      console.log(`    ${f} = ${v.slice(0, 90)}${v.length > 90 ? '…' : ''}`);
    }
  }
  console.log('\ncounts across', snap.size, 'units:', JSON.stringify(filled));
  process.exit(0);
})().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
