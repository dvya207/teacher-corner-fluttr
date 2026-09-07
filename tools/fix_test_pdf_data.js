// Two data fixes in teacher-corner-dev. DRY RUN unless --apply is passed.
//
//   1. boardGradeResources/s9qKMMiIrTMVaay3Kn14 (3S.conceptPreTestQuizPdf, CBSE)
//      gains resources.grade_04, pointing at the same PDF its grade_01 does.
//      Mirrors how the post-test copy was already filled in.
//
//   2. workflows/xHcyOmsSYLmyNT7QJxRv step 5 content "Post-Test Questionnaire"
//      has its contentSubCategory changed from 'teacherNotes' (empty on the
//      resource document) to 'conceptPostTestQuizPdf' (where the PDF is).
//
// Backs both documents up to tools/.backup-<timestamp>/ before writing.
const fs = require('fs');
const path = require('path');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const app = initializeApp({ projectId: 'helix-staging-india' });
const db = getFirestore(app, 'teacher-corner-dev');

const APPLY = process.argv.includes('--apply');

const BGR_ID = 's9qKMMiIrTMVaay3Kn14';
const WF_ID = 'xHcyOmsSYLmyNT7QJxRv';
const OLD_SLOT = 'teacherNotes';
const NEW_SLOT = 'conceptPostTestQuizPdf';
const STEP_CONTENT = 'Post-Test Questionnaire';

(async () => {
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const dir = path.join(__dirname, `.backup-${stamp}`);
  if (APPLY) fs.mkdirSync(dir, { recursive: true });

  const save = (name, data) => {
    if (!APPLY) return;
    fs.writeFileSync(path.join(dir, `${name}.json`), JSON.stringify(data, null, 2));
  };

  // ---- Fix 1 --------------------------------------------------------------
  const bgrRef = db.collection('boardGradeResources').doc(BGR_ID);
  const bgr = await bgrRef.get();
  if (!bgr.exists) throw new Error(`boardGradeResources/${BGR_ID} is missing`);
  save('boardGradeResources', bgr.data());

  const grades = bgr.get('resources') || {};
  const source = grades.grade_01;
  console.log(`FIX 1  boardGradeResources/${BGR_ID}`);
  console.log(`       ${bgr.get('category')}.${bgr.get('subCategory')}  board=${bgr.get('board')}`);
  console.log(`       before: ${JSON.stringify(grades)}`);
  if (!source) throw new Error('no grade_01 to copy the path from');
  if (grades.grade_04) {
    console.log('       grade_04 already set, nothing to do');
  } else {
    console.log(`       after:  + grade_04 = ${source}`);
    if (APPLY) await bgrRef.update({ 'resources.grade_04': source });
  }

  // ---- Fix 2 --------------------------------------------------------------
  const wfRef = db.collection('workflows').doc(WF_ID);
  const wf = await wfRef.get();
  if (!wf.exists) throw new Error(`workflows/${WF_ID} is missing`);
  save('workflow', wf.data());

  const field = wf.get('workflowSteps') !== undefined ? 'workflowSteps' : 'steps';
  const steps = wf.get(field);
  if (!Array.isArray(steps)) throw new Error(`${field} is not an array`);

  console.log(`\nFIX 2  workflows/${WF_ID}.${field}`);
  let hits = 0;
  for (const step of steps) {
    const contents = step.contents || step.workflowContents;
    if (!Array.isArray(contents)) continue;
    for (const c of contents) {
      if (c.contentName !== STEP_CONTENT) continue;
      if (c.contentSubCategory !== OLD_SLOT) {
        console.log(`       "${c.contentName}" already points at ${JSON.stringify(c.contentSubCategory)}, leaving it`);
        continue;
      }
      hits += 1;
      console.log(`       step ${step.sequenceNumber} "${c.contentName}"`);
      console.log(`       before: ${c.contentCategory}.${c.contentSubCategory}`);
      console.log(`       after:  ${c.contentCategory}.${NEW_SLOT}`);
      c.contentSubCategory = NEW_SLOT;
    }
  }

  if (hits === 0) {
    console.log('       nothing matched, no write');
  } else if (APPLY) {
    // The whole array is rewritten because Firestore cannot address an array
    // index. Timestamps round-trip as Timestamp objects, so the other fields
    // of every step and content are written back byte-identical.
    await wfRef.update({ [field]: steps });
  }

  console.log(APPLY ? `\nAPPLIED. Backups in ${dir}` : '\nDRY RUN. Nothing written. Re-run with --apply.');
  process.exit(0);
})().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
