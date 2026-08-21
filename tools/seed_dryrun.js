/**
 * Runs tools/seed.js against a stubbed Admin SDK and prints what it WOULD write.
 *
 *   node tools/seed_dryrun.js
 *   node tools/seed_dryrun.js --skip-storage
 *
 * No credentials, no network, no writes. It exists because the seed is the one
 * piece of this project that cannot be unit tested and is easy to get subtly
 * wrong: a Storage path referenced in Firestore with no object behind it renders
 * as a placeholder forever and looks like an app bug rather than a seed bug. The
 * last section of the output is the check that matters.
 */
const Module = require('module');
const captured = { docs: {}, uploads: [] };

const fakeAdmin = {
  initializeApp: () => {},
  app: () => ({}),
  firestore: () => ({
    collection: (c) => ({
      doc: (d) => ({
        set: async (data) => {
          captured.docs[`${c}/${d}`] = data;
        },
      }),
    }),
  }),
  storage: () => ({
    bucket: () => ({
      name: 'helix-staging-india.firebasestorage.app',
      file: (path) => ({
        save: async (bytes, opts) => {
          captured.uploads.push({ path, bytes: bytes.length, type: opts.contentType });
        },
      }),
    }),
  }),
};

const original = Module.prototype.require;
Module.prototype.require = function (id) {
  if (id === 'firebase-admin') return fakeAdmin;
  return original.apply(this, arguments);
};

// Fixed values: nothing here reaches a real project, and the point is to
// inspect shape, not to seed. Extra flags are passed straight through.
const passthrough = process.argv.slice(2);
process.argv = [
  process.argv[0], 'seed.js',
  '--database=divya-teacher-corner',
  '--uid=uid_dryrun',
  ...passthrough,
];

require('./seed.js');

setTimeout(() => {
  console.log('\n================ DRY RUN RESULT ================');
  console.log('documents written:', Object.keys(captured.docs).join(', '));
  const lu = captured.docs['LearningUnits/lu_magnetic_pen_stand'];
  console.log('\nLearningUnits fields:', Object.keys(lu).join(', '));
  console.log('  learningUnitPreviewImage :', lu.learningUnitPreviewImage);
  console.log('  resources                :', JSON.stringify(lu.resources));
  console.log('  longDescription length   :', lu.longDescription.length);
  const wf = captured.docs['Workflows/wf_mps_v1'];
  console.log('\nworkflow steps and their content resource paths:');
  for (const step of wf.steps) {
    const paths = (step.contents || []).map(
      (c) => `${c.contentName}=${c.resourcePath === '' ? '(empty)' : c.resourcePath}`,
    );
    console.log(`  seq ${step.sequenceNumber} ${step.workflowStepId.padEnd(3)} ${paths.join('  ') || '(no contents)'}`);
  }
  console.log('\nstorage uploads:');
  for (const u of captured.uploads) {
    console.log(`  ${u.path}  ${u.bytes} bytes  ${u.type}`);
  }
  console.log('\npaths referenced in Firestore but never uploaded:');
  const uploaded = new Set(captured.uploads.map((u) => u.path));
  const referenced = new Set([lu.learningUnitPreviewImage]);
  for (const step of wf.steps) {
    for (const c of step.contents || []) {
      if (c.resourcePath) referenced.add(c.resourcePath);
    }
  }
  const missing = [...referenced].filter((r) => !uploaded.has(r));
  console.log(missing.length ? '  ' + missing.join('\n  ') : '  none — every referenced path has an object');
}, 400);
