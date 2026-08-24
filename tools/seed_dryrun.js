#!/usr/bin/env node
/**
 * DISABLED, along with `tools/seed.js`. See the long note at the top of that
 * file for why.
 *
 * This one only ever printed what the seed WOULD write, so it was harmless in
 * itself. It is disabled anyway, for one reason: it existed to be the safe way to
 * check the fixture shapes before running the real thing, and leaving a working
 * dry run beside a disabled seed is an invitation to restore the seed. There is
 * no longer anything to seed. The teacher, classrooms and programmes come from
 * the Teacher Corner web app's own `teacher-corner-dev` data.
 *
 * To inspect what is actually in that database, read it rather than imagining
 * it. A read-only Admin SDK script is the right tool, and reads are always safe:
 *
 *   node -e "…getFirestore(app, 'teacher-corner-dev').collection('teachers')…"
 */

console.error(`
tools/seed_dryrun.js is DISABLED.

Nothing is seeded any more: this app reads the live 'teacher-corner-dev' data
owned by the Teacher Corner web app. To see what is in that database, query it
read-only. See SCHEMA.md for the collections and the uid relationship.
`.trim());

process.exit(1);
