// READ ONLY. One teacher's own record, in full: submissions (photo evidence
// and the quiz attempt), formResponses (the answers) and workflowProgress.
//
// These three documents are what the Submissions report joins, and their
// shapes are not guessable: answers arrive as lists, strings and numbers, and
// a quiz attempt is written as the submissions document's OWN top level rather
// than nested under an assignment id like the uploads are.
//
//   node tools/inspect_teacher_data.js [uid]
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const app = initializeApp({ projectId: 'helix-staging-india' });
const db = getFirestore(app, 'teacher-corner-dev');
const UID = process.argv[2] || '7vbKdBSqG3YRI6X1GzFNeQD24Rm1';
(async () => {
  for (const name of ['submissions', 'formResponses', 'workflowProgress']) {
    const snap = await db.collection('users').doc(UID).collection(name).get();
    console.log(`\n########## ${name}  (${snap.size})`);
    for (const d of snap.docs) {
      console.log(`\n  --- ${d.id}`);
      console.log(JSON.stringify(d.data(), null, 2).slice(0, 2600));
    }
  }
  process.exit(0);
})().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
