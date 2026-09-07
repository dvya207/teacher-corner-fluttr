// READ ONLY. Answers "why is this tab empty" without a device.
//
// Mirrors LearningUnitProvider.resolvedPathFor exactly, for every content of
// every workflow, and prints OK or BLANK per tab with the store it came from.
// A BLANK line says WHICH lookup missed, which is the whole point: an empty
// tab has four different causes and they need four different fixes.
//
//   node tools/verify_resolution.js
//
// The order is LearningUnitProvider.resolvedPathFor:
//   1. the content's own resourcePath
//   2. externalResources -> learningUnits/{id}.resources[sub]      (store 2)
//   3. grade-dependent   -> boardGradeResources/{slot[board]}.resources[grade_NN]
//   4. otherwise         -> learningUnitResources.resources[cat][sub] (store 1)
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const app = initializeApp({ projectId: 'helix-staging-india' });
const db = getFirestore(app, 'teacher-corner-dev');

const MATURITY = new Set(['bronze', 'silver', 'gold', 'platinum', 'diamond']);

// ResourceSlot.of: a string leaf is a path, a map leaf is grade-dependent and
// its board keys hold boardGradeResources document ids.
const slotOf = (leaf) => {
  if (typeof leaf === 'string') {
    const v = leaf.trim();
    return v ? { path: v } : null;
  }
  if (!leaf || typeof leaf !== 'object') return null;
  const uni = String(leaf.universalGradeBoardResourcePath ?? '').trim();
  const byBoard = {};
  for (const [k, v] of Object.entries(leaf)) {
    if (k === 'universalGradeBoardResourcePath') continue;
    if (typeof v === 'string' && v.trim()) byBoard[k] = v.trim();
  }
  if (!uni && !Object.keys(byBoard).length) return null;
  return { universal: uni || null, byBoard };
};

// BoardGradeResource.gradeKey
const gradeKey = (grade) => {
  const t = String(grade ?? '').trim();
  if (!t) return '';
  if (/^\d+$/.test(t)) return `grade_${t.padStart(2, '0')}`;
  const pp = /^pre[\s-]*primary\s*(\d+)$/i.exec(t);
  return pp ? `grade_preprimary_${pp[1]}` : '';
};

const normalise = (s) => (s || '').toLowerCase().replace(/[^a-z]/g, '');

(async () => {
  const workflows = await db.collection('workflows').get();

  for (const wf of workflows.docs) {
    const unitId = wf.get('learningUnitId');
    if (!unitId) continue;

    const unit = await db.collection('learningUnits').doc(unitId).get();
    const store2 = unit.exists ? (unit.get('resources') || {}) : {};

    const resSnap = await db.collection('learningUnitResources')
      .where('learningUnitDocId', '==', unitId).get();
    const store1 = {};
    for (const d of resSnap.docs) {
      for (const [cat, group] of Object.entries(d.get('resources') || {})) {
        if (!group || typeof group !== 'object') continue;
        for (const [key, raw] of Object.entries(group)) {
          const slot = slotOf(raw);
          if (slot) store1[`${cat}|${key}`] = slot;
        }
      }
    }

    // Store 3, and the classroom that decides which cell of it applies.
    const bgrSnap = await db.collection('boardGradeResources')
      .where('learningUnitDocId', '==', unitId).get();
    const store3 = {};
    for (const d of bgrSnap.docs) store3[d.id] = d.get('resources') || {};

    const classroomId = wf.get('classroomId');
    const classroom = classroomId
      ? await db.collection('classrooms').doc(classroomId).get() : null;
    const board = classroom && classroom.exists ? (classroom.get('board') || '') : '';
    const grade = classroom && classroom.exists ? (classroom.get('grade') || '') : '';
    const gKey = gradeKey(grade);

    console.log(`\n##### ${wf.get('learningUnitName')} — workflow ${wf.id}`);
    console.log(`      classroom ${wf.get('classroomName')}  board=${board || '(none)'} grade=${grade || '(none)'} -> ${gKey || '(no grade key)'}`);
    console.log(`      store1 slots=${Object.keys(store1).length}  store2 filled=${Object.entries(store2).filter(([k, v]) => typeof v === 'string' && v.trim() && !MATURITY.has(k.toLowerCase())).length}  store3 docs=${Object.keys(store3).length}`);

    const steps = wf.get('workflowSteps') || wf.get('steps') || [];
    const list = Array.isArray(steps) ? steps : Object.values(steps);

    for (const s of list) {
      console.log(`\n  STEP ${s.sequenceNumber ?? '?'} ${s.workflowStepName || s.stepName || '(unnamed)'}`);
      const contents = s.contents || s.workflowContents || [];
      const cl = Array.isArray(contents) ? contents : Object.values(contents);
      for (const c of cl) {
        const cat = c.contentCategory || '';
        const sub = c.contentSubCategory || '';
        const name = c.contentName || '(unnamed)';

        // Assignments never go through resource resolution.
        const aType = (c.assignmentType || '').trim().toUpperCase();
        const isAssignment = normalise(cat) === 'assignment' || aType;
        if (isAssignment) {
          const id = (c.assignmentId || '').trim();
          const kind = aType || '(no type -> upload)';
          const verdict = id ? `assignment ${kind} id=${id}` : `ASSIGNMENT WITH NO ID -> unavailable`;
          console.log(`      ${verdict.startsWith('ASSIGNMENT WITH NO ID') ? 'BLANK  ' : 'OK     '} "${name}"  ${kind}${id ? '' : '  <-- no assignmentId'}`);
          continue;
        }

        let path = (c.resourcePath || '').trim();
        let via = 'content.resourcePath';
        if (!path) {
          if (normalise(cat) === 'externalresources') {
            via = 'store2 (unit.resources)';
            const key = sub.trim();
            const raw = MATURITY.has(key.toLowerCase()) ? '' : store2[key];
            path = typeof raw === 'string' ? raw.trim() : leafPath(raw);
          } else {
            const slot = store1[`${cat}|${sub}`];
            if (!slot) {
              via = 'store1 (maturity doc)';
              path = '';
            } else if (slot.path) {
              via = 'store1 (maturity doc)';
              path = slot.path;
            } else {
              const docId = board ? (slot.byBoard[board] || '') : '';
              const cell = docId ? (store3[docId] || {}) : {};
              const graded = gKey ? (cell[gKey] || '') : '';
              if (graded) {
                via = `store3 (boardGradeResources/${docId} ${gKey})`;
                path = graded;
              } else if (slot.universal) {
                via = 'store1 universal fallback';
                path = slot.universal;
              } else {
                via = docId
                  ? `store3 MISS: ${docId} has ${Object.keys(cell).join(',') || 'no grades'}, needed ${gKey}`
                  : `no copy for board ${board || '(none)'}`;
                path = '';
              }
            }
          }
        }
        const status = path ? 'OK     ' : 'BLANK  ';
        console.log(`      ${status} "${name}"  ${cat}.${sub}  via ${via}`);
        if (path) console.log(`               -> ${path.slice(0, 78)}`);
        else console.log(`               -> nothing at ${cat}.${sub}`);
      }
    }
  }
  process.exit(0);
})().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
