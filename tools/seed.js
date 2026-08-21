#!/usr/bin/env node
/**
 * Seeds the sample data described in SCHEMA.md into YOUR named Firestore
 * database in helix-staging-india.
 *
 * Setup:
 *   npm install firebase-admin
 *   gcloud auth application-default login
 *   node tools/seed.js --database=divya-teacher-corner --uid=<your-auth-uid>
 *
 * Get your uid by signing in once in the app and printing
 * FirebaseAuth.instance.currentUser!.uid, or from the Firebase Console under
 * Authentication.
 *
 * Safe to re-run: every write is an idempotent set() on a fixed document id.
 * It does not delete anything.
 */
const admin = require('firebase-admin');

const arg = (name, fallback) => {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.split('=').slice(1).join('=') : fallback;
};

const PROJECT  = arg('project', 'helix-staging-india');
const DATABASE = arg('database');
const UID      = arg('uid');

if (!DATABASE || !UID) {
  console.error('Usage: node tools/seed.js --database=<your-db-id> --uid=<your-auth-uid>');
  console.error('Do NOT point --database at someone else\'s database.');
  process.exit(1);
}

admin.initializeApp({ projectId: PROJECT });
// Named database. admin.firestore() alone would hit (default).
const db = admin.firestore(admin.app(), DATABASE);

const CLASSROOM = 'cls_oak_7a';
const PROGRAMME = 'prog_tip_2026';
const LU        = 'lu_magnetic_pen_stand';
const WORKFLOW  = 'wf_mps_v1';

async function main() {
  console.log(`Seeding ${PROJECT} / ${DATABASE} for uid ${UID}`);

  await db.collection('Teachers').doc(UID).set({
    name: 'Intern Teacher',
    teacherMeta: {
      firstName: 'Intern',
      lastName: 'Teacher',
      phoneNumber: '+919999900000',
      institutionName: 'Test School Oak',
      designation: 'Teacher',
    },
    classrooms: {
      [CLASSROOM]: {
        classroomId: CLASSROOM,
        classroomName: '7 A',
        type: 'CLASSROOM',
        grade: 7,
        section: 'A',
        institutionName: 'Test School Oak',
        programmes: { [PROGRAMME]: { programmeId: PROGRAMME, displayName: 'TIP 2026' } },
      },
      // Deliberately awkward second classroom: a STEM-CLUB with a NON-NUMERIC
      // grade, so your parsing meets the real-world edge case on day one.
      cls_oak_et: {
        classroomId: 'cls_oak_et',
        stemClubName: 'Oak ET Club',
        type: 'STEM-CLUB',
        grade: 'ET',
        institutionName: 'Test School Oak',
        programmes: { [PROGRAMME]: { programmeId: PROGRAMME, displayName: 'TIP 2026' } },
      },
    },
  }, { merge: true });
  console.log('  ✓ Teachers/' + UID);

  await db.collection('Classrooms').doc(CLASSROOM).set({
    classroomName: '7 A',
    type: 'CLASSROOM',
    grade: 7,
    section: 'A',
    board: 'CBSE',
    institutionName: 'Test School Oak',
    studentCounter: 32,
    programmes: {
      [PROGRAMME]: {
        displayName: 'TIP 2026',
        workflowIds: [{ learningUnitId: LU, workflowId: WORKFLOW }],
      },
    },
  }, { merge: true });

  await db.collection('Classrooms').doc('cls_oak_et').set({
    stemClubName: 'Oak ET Club',
    type: 'STEM-CLUB',
    grade: 'ET',
    institutionName: 'Test School Oak',
    studentCounter: 12,
    programmes: {
      [PROGRAMME]: {
        displayName: 'TIP 2026',
        // Map form rather than list form, the app must tolerate both.
        workflowIds: { '0': { learningUnitId: LU, workflowId: WORKFLOW } },
      },
    },
  }, { merge: true });
  console.log('  ✓ Classrooms (2)');

  await db.collection('LearningUnits').doc(LU).set({
    learningUnitDisplayName: 'Magnetic Pen Stand',
    type: 'TACtivity',
    shortDescription: 'Build a pen stand that holds itself up with magnets.',
    stepCount: 6,
    subjectName: 'Science',
    Maturity: 'gold',
  }, { merge: true });
  console.log('  ✓ LearningUnits/' + LU);

  await db.collection('Workflows').doc(WORKFLOW).set({
    steps: [
      // Out of array order ON PURPOSE. Sort by sequenceNumber, not by index.
      { workflowStepId: 's2', workflowStepName: 'Gather materials',
        workflowStepType: 'MATERIALS', sequenceNumber: 2,
        workflowStepDuration: 5, canSkipWorkflowStep: true,
        allowArtefactUpload: false,
        contents: [{ contentName: 'Material List', contentCategory: 'material',
                     contentType: 'material', resourcePath: '' }] },
      { workflowStepId: 's1', workflowStepName: 'Introduce the problem',
        workflowStepType: 'INTRO', sequenceNumber: 1,
        workflowStepDuration: 10, canSkipWorkflowStep: false,
        allowArtefactUpload: false,
        contents: [{ contentName: 'Guide', contentCategory: 'guide',
                     contentType: 'guide', resourcePath: '' }] },
      { workflowStepId: 's3', workflowStepName: 'Build it',
        workflowStepType: 'BUILD', sequenceNumber: 3,
        workflowStepDuration: 25, canSkipWorkflowStep: false,
        allowArtefactUpload: false, contents: [] },
      { workflowStepId: 's4', workflowStepName: 'Observe',
        workflowStepType: 'OBSERVATION', sequenceNumber: 4,
        workflowStepDuration: 10, canSkipWorkflowStep: false,
        allowArtefactUpload: false, contents: [] },
      { workflowStepId: 's5', workflowStepName: 'Discuss',
        workflowStepType: 'INFERENCE', sequenceNumber: 5,
        workflowStepDuration: 10, canSkipWorkflowStep: true,
        allowArtefactUpload: false, contents: [] },
      { workflowStepId: 's6', workflowStepName: 'Capture evidence',
        workflowStepType: 'ASSIGNMENT', sequenceNumber: 6,
        workflowStepDuration: 5, canSkipWorkflowStep: false,
        allowArtefactUpload: true, assignmentId: 'asg_mps_evidence',
        contents: [{ contentName: 'Photo evidence', contentCategory: 'assignment',
                     assignmentType: 'UPLOAD', assignmentId: 'asg_mps_evidence',
                     resourcePath: '' }] },
    ],
  }, { merge: true });
  console.log('  ✓ Workflows/' + WORKFLOW);

  console.log('\nDone. Two classrooms, one learning unit, six workflow steps.');
  console.log('The ET classroom has grade "ET" (a string) and map-form');
  console.log('workflowIds on purpose, if your UI survives both, your parsing');
  console.log('is right.');
}

main().catch((e) => { console.error(e); process.exit(1); });
