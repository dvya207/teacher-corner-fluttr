#!/usr/bin/env node
/**
 * SEEDING IS DISABLED. This script no longer writes anything.
 *
 * WHY. This app used to own a private Firestore database, `divya-teacher-corner`,
 * and this script filled it with fixtures: a `Teachers/{uid}` document, two
 * `Classrooms`, a `LearningUnits` and a `Workflows`. That was correct while the
 * database was ours and empty.
 *
 * It is not ours any more. The app now reads `teacher-corner-dev`, which is owned
 * by the live Angular Teacher Corner web app in `~/code/teacher-corner` and holds
 * real teachers, classrooms and programmes that real people are using. The whole
 * point of the repoint was ONE source of truth for a teacher. Seeding into that
 * database would defeat it in the most expensive possible way:
 *
 *   - The Admin SDK BYPASSES SECURITY RULES. Nothing would stop these writes.
 *     Not the web app's rules, not this repo's lack of a rules file. The
 *     `allow write: if false` protections that make this app a read consumer
 *     apply to the CLIENT; a script holding a service account ignores them.
 *   - `set()` on a fixed document id is an OVERWRITE, not an insert. A fixture
 *     that happened to collide with a real classroom id would replace a live
 *     document, and "safe to re-run" would then mean "reliably destructive".
 *   - Even where ids did not collide, it would add duplicate teachers and
 *     classrooms to collections the web app lists, so its own screens would show
 *     invented rows next to real ones.
 *
 * THERE IS NOTHING TO SEED ANY MORE, either. The teacher, the classrooms and the
 * programmes come from the web app's own data. If the Flutter dashboard is empty,
 * the answer is never to write fixtures; it is that no `teachers` document has
 * this sign-in's uid at `teacherMeta.uid` yet, which an administrator fixes by
 * registering the phone number in the web app. The app reports exactly that
 * state rather than hiding it.
 *
 * The previous implementation is in this repo's git history if the fixture shapes
 * are ever wanted for a test. Do not restore it against a shared database.
 *
 * `tools/fixture_images.js` is untouched and still safe: it only GENERATES PNG
 * bytes in memory and makes no Firebase or Storage calls of its own.
 */

console.error(`
tools/seed.js is DISABLED and writes nothing.

This app reads the 'teacher-corner-dev' database, which belongs to the live
Teacher Corner web app (~/code/teacher-corner). Seeding fixtures into it would
create duplicate teachers and classrooms in a database real people are using,
and the Admin SDK bypasses every security rule that would otherwise stop it.

If the Flutter dashboard shows no classrooms, the cause is one of:

  1. No 'teachers' document has your uid at 'teacherMeta.uid'. An administrator
     registers your phone number against a classroom in the web app; its
     linkSignedInUid() then stamps your uid in on your next sign-in.
  2. The linked teacher record has an empty 'classrooms' map.

Both are data states to fix in the web app, not here. See SCHEMA.md.
`.trim());

// Non-zero, so a script or CI step that calls this fails loudly instead of
// reporting success for work it did not do.
process.exit(1);
