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
 * Also uploads the image fixtures the learning unit screen needs, because a
 * Storage PATH in Firestore with no object behind it is not a fixture, it is a
 * broken link. Pass --skip-storage to seed Firestore only (for instance if you
 * do not have write access to the bucket).
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
const BUCKET   = arg('bucket', `${PROJECT}.firebasestorage.app`);
const SKIP_STORAGE = process.argv.includes('--skip-storage');

if (!DATABASE || !UID) {
  console.error('Usage: node tools/seed.js --database=<your-db-id> --uid=<your-auth-uid>');
  console.error('Do NOT point --database at someone else\'s database.');
  process.exit(1);
}

admin.initializeApp({ projectId: PROJECT, storageBucket: BUCKET });
// Named database. admin.firestore() alone would hit (default).
const db = admin.firestore(admin.app(), DATABASE);

const CLASSROOM = 'cls_oak_7a';
const PROGRAMME = 'prog_tip_2026';
const LU        = 'lu_magnetic_pen_stand';
const WORKFLOW  = 'wf_mps_v1';

// Fixture object paths are namespaced by database id.
//
// SCHEMA.md's example reads `luImages/mps_200x200.png`, but every developer's
// named Firestore database shares ONE Storage bucket in this project. Un-
// namespaced, each seed run silently overwrites everyone else's fixture, and a
// changed fixture would change it for all of them. The app never cares what the
// path looks like, only that it is stable, so the prefix costs nothing.
const PREVIEW_IMAGE   = `luImages/${DATABASE}/mps_200x200.png`;
const STEP_IMAGE      = `luContent/${DATABASE}/mps_step3_assembly.png`;
const MATERIALS_IMAGE = `luContent/${DATABASE}/mps_materials.png`;

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
    longDescription:
      'Children build a pen stand from card and two magnets, then work out why ' +
      'it stays upright without glue. The stand holds itself together because ' +
      'the magnets attract through the card, so the question to draw out is ' +
      'what is pulling on what, and what happens when the card gets thicker.',
    stepCount: 6,
    subjectName: 'Science',
    // A Storage PATH, not a URL. The app resolves it with getDownloadURL() and
    // caches the file under THIS string, never under the resolved URL, because
    // every resolution mints a fresh access token.
    learningUnitPreviewImage: PREVIEW_IMAGE,
    Maturity: 'gold',
    // Maturity level -> LearningUnitResources document id. The vertical slice
    // does not read that collection, so nothing is seeded into it; the field is
    // here because the learning unit document really carries it.
    resources: { gold: 'lur_mps_gold' },
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
                     contentType: 'image', resourcePath: MATERIALS_IMAGE }] },
      { workflowStepId: 's1', workflowStepName: 'Introduce the problem',
        workflowStepType: 'INTRO', sequenceNumber: 1,
        workflowStepDuration: 10, canSkipWorkflowStep: false,
        allowArtefactUpload: false,
        contents: [{ contentName: 'Guide', contentCategory: 'guide',
                     contentType: 'guide', resourcePath: '' }] },
      // Two contents on purpose, so the content tab strip has something to
      // switch between and the keep-alive behaviour is observable: leaving the
      // image tab and coming back must not re-resolve or re-download it.
      { workflowStepId: 's3', workflowStepName: 'Build it',
        workflowStepType: 'BUILD', sequenceNumber: 3,
        workflowStepDuration: 25, canSkipWorkflowStep: false,
        allowArtefactUpload: false,
        contents: [
          { contentName: 'Assembly', contentCategory: 'image',
            contentType: 'image', resourcePath: STEP_IMAGE },
          // Deliberately left empty. A content that is present but carries
          // nothing renderable is a real state in this data, and the app has to
          // say so rather than render a blank pane.
          { contentName: 'Teacher notes', contentCategory: 'guide',
            contentType: 'guide', resourcePath: '' },
        ] },
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

  await seedStorage();

  console.log('\nDone. Two classrooms, one learning unit, six workflow steps.');
  console.log('The ET classroom has grade "ET" (a string) and map-form');
  console.log('workflowIds on purpose, if your UI survives both, your parsing');
  console.log('is right.');
  console.log('');
  console.log('Step 2 and step 3 carry real image resources; step 3 also has a');
  console.log('content with an EMPTY resourcePath, which is just as real a');
  console.log('state and the UI has to say so rather than render a blank pane.');
}

/**
 * Uploads the image fixtures the Firestore paths point at.
 *
 * Idempotent like the rest of the seed: each object is overwritten at a fixed
 * path. A failure here is reported but does not fail the run, because Firestore
 * is already seeded by this point and the app degrades to a placeholder tile
 * when an image cannot be resolved.
 */
async function seedStorage() {
  if (SKIP_STORAGE) {
    console.log('  – Storage skipped (--skip-storage). Image paths in Firestore');
    console.log('    will resolve to nothing and render as placeholders.');
    return;
  }

  const { fixtures } = require('./fixture_images.js');
  const built = fixtures();
  const uploads = [
    [PREVIEW_IMAGE, built.preview],
    [STEP_IMAGE, built.stepImage],
    [MATERIALS_IMAGE, built.materialList],
  ];

  try {
    const bucket = admin.storage().bucket();
    for (const [path, fixture] of uploads) {
      await bucket.file(path).save(fixture.bytes, {
        contentType: fixture.contentType,
        resumable: false,
      });
      console.log(`  ✓ gs://${bucket.name}/${path}`);
    }
  } catch (e) {
    console.error('  ! Storage upload failed:', e.message);
    console.error('    Firestore is seeded. The image paths will render as');
    console.error('    placeholders until the objects exist. Re-run, or pass');
    console.error('    --skip-storage to silence this.');
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
