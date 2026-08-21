# Notes

Running notes, in my own words. Phases 1 to 3 are built, Phase 4's models are
in, and nothing has been verified against live data yet (see "Still unverified").

## What the data model does that I did not expect

**The workflow binding hangs off the classroom, and that removes a read path
entirely.** I expected `LearningUnits/{id}` to know its own workflow. It does
not, and it cannot: the same learning unit runs a different workflow in a
different classroom, so "the workflow for this activity" is not a well-formed
question. In practice this means there is no function from learning unit to
workflow anywhere in the code, only `Classroom.workflowIdFor(luId)`. I wrote a
test asserting two classrooms resolve the same unit to different workflows,
because a comment would not have stopped me from later adding the read I first
went looking for.

**The classroom card's four fields live in two collections.** PLAN asks the card
to show name, grade/section, institution and student count. `studentCounter` is
only on `Classrooms/{id}`, while the teacher's denormalised `classrooms` map is
the only thing that says which classrooms are mine. So the list is one teacher
read plus one read per classroom, merged field by field. I had assumed the
denormalised copy existed precisely so the list could be one read; it cannot,
and the card requirement is what proves it. This is the single thing I would
most want spelled out in SCHEMA.md, because neither document says it and you
only discover it when you try to render the card.

**Map-or-list is an idiom, not an exception.** SCHEMA.md flags it on
`workflowIds`, but the same shape ambiguity applies to `classrooms`,
`programmes`, `contents` and `steps`. I wrote the tolerance inline for the first
two and then pulled it into `KeyedEntries`, which is where it should have
started. Related: the map key is the id, and the nested `classroomId` /
`programmeId` is a duplicate that is sometimes absent and can disagree with the
key. "Prefer the key" has to be a rule applied everywhere rather than a
judgement made per field.

**One field, three names, in a specific order.** `learningUnitDisplayName` then
`learningUnitName` then `name`; `classroomName` then `name`; and `stemClubName`
replaces `classroomName` outright when `type` is `STEM-CLUB`. The last one is
different in kind from the other two: it is not a fallback chain, it is a
different field selected by another field's value. I initially wrote it as a
fallback and it produced the wrong name for the ET club.

**Counting has to be by identity, not by occurrence.** Both seeded classrooms
run `prog_tip_2026`. Summing programmes per classroom puts "2 Programmes" on the
dashboard, which is simply untrue, so `programmeCount` counts distinct ids.

**Absent, empty and zero are three different things, and the UI has to keep
them apart.** `studentCounter` of null is a statement about my read; 0 would be
a statement about the classroom. `resourcePath` is present-but-empty on every
seeded content, which is not the same as missing. `grade` of `"ET"` parses to
null meaning "no grade", so the card omits the line rather than rendering
"Grade 0" or "Grade null".

## Two things that were not in the data model but cost real time

**A new named Firestore database ships with closed rules.** The Firebase CLI
says so on create and the README does not mention it. The seed script uses the
Admin SDK, which bypasses rules, so seeding will appear to work while every
client read fails with permission-denied. Rules are in `firestore.rules`, scoped
by the `database` key in `firebase.json` so a deploy from this repo cannot reach
anyone else's database.

**`flutter create` puts `INTERNET` only in the debug and profile manifests.** A
release build would have had no network at all, and nothing in debug would ever
have shown it. Moved to the main manifest.

## What I would build differently a second time

**One teacher repository, not a teacher read per provider.** `AuthProvider`,
`DashboardProvider` and `ClassroomProvider` each read `Teachers/{uid}`. I did
that deliberately, so each screen owns its own loading/error/retry lifecycle and
its Retry button actually retries something, and the Firestore SDK serves the
repeat reads from its local cache. But three owners of one document is a smell,
and the honest fix is a repository holding the teacher with an explicit
`refresh()`, which would give each screen a real retry without the duplication.

**Decide the tolerance primitives before writing the second parser.**
`KeyedEntries`, "sort at the parse boundary, never in the widget", and "prefer
the key" are three decisions that should have been made once, up front. I
arrived at all three by refactoring, which cost more than deciding would have.

**Sort at the boundary, and make the result unmodifiable.** `Workflow.steps` is
sorted in `fromMap` and returned as an unmodifiable list, so no widget can
re-sort it in place and no screen has to remember to. Same for
`ClassroomSearch.filter` and `LearningUnit.resources`. Cheap, and it turns a
convention into something the analyzer and the tests enforce.

## Still unverified

Everything below needs either a working device or seeded data, and I have
neither yet. Listed so it is not mistaken for done:

- Both Phase 1 acceptance checks (cold start without a login flash, and sign-out
  locking every route). The redirect logic is unit-tested; the behaviour is not.
- Every screen against real data. The providers are tested behind fakes.
- Phase 4's caching work, which is the part PLAN warns is easy to get invisibly
  wrong. `seed.js` writes no `learningUnitPreviewImage` and every content's
  `resourcePath` is the empty string, so there is nothing in Storage to resolve
  or cache against yet.
- Rotation and maximum system font size on every screen. Screens are built
  scrollable for this, but built-for is not tested-for.
