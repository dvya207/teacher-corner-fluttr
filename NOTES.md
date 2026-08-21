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

## What the golden images showed that the tests did not

`test/golden/goldens/` renders every screen and state to a PNG. Three things
were only visible once I looked at them:

**The `+91` prefix was swallowing the phone field.** A `Center` inside
`InputDecoration.prefixIcon` expands to the field's whole width, so the input
area collapsed and the hint never rendered. Every test still passed, because
the field accepted text and validated correctly. It just looked broken.

**In landscape, type is oversized rather than overflowing.** The tokens resolve
`.sp` and `.w` against a 360-wide baseline, so at 800x360 everything horizontal
scales 2.2x while `.r` (min axis) shrinks to 0.45x. Nothing overflows any more,
but "No classrooms yet" renders enormous and the app bar logo shrinks to about
10px. That is a design-token decision rather than a bug in a screen, so I have
not unilaterally capped the width scale; it needs a call on whether the tokens
should clamp.

**The dashboard has a visible hole.** It renders a "Classrooms" section heading
with nothing beneath it, because Phase 2's dashboard is only name, institution
and counts. It reads as unfinished rather than as scoped, and either the heading
should go or the classroom list should come up onto the dashboard.

## How to look at it without a device

```bash
flutter test                     # 143 tests, no device, no Firebase, no data
flutter analyze                  # must print "No issues found!"
flutter test --update-goldens test/golden/screens_golden_test.dart
```

The goldens are rendered against fakes on a 360x800 surface. They show layout,
type and colour, and they prove nothing about whether the real reads work.

## What Phases 3 to 6 added to the list

**The workflow binding has to travel in the URL.** Because which workflow runs
is a property of the classroom, `/lu/:id` cannot resolve on its own. It takes
`workflowId` (and `classroomId` + `programmeId` for the evidence document) as
query parameters and refuses to load without them, rather than picking a
workflow and walking the teacher through steps their class is not doing. That
made a whole screen, `MissingWorkflowScreen`, exist purely to encode a
data-model rule.

**`contents` has no text field.** SCHEMA.md gives each content a
`contentName`, a category, a type and a `resourcePath`, and nothing to read.
Every seeded content has `resourcePath: ''`, which is present but useless. So
"render a text content type" resolves to: show the content's name, render the
image when the path points at one, name the file when it points at a document,
and say plainly when there is nothing attached. The learning unit's own
`shortDescription` is the only real prose in the data, and it sits above the
step strip. **This is the one thing I would want confirmed** — if contents are
supposed to carry a body somewhere, I have not found the field.

**Nothing about the evidence ordering is arbitrary.** Uploads wait for Submit,
so a photo the teacher reconsiders needs no cleanup. A failed upload deletes
what already landed, because those objects are unreferenced the moment the
write does not happen. Removal writes Firestore first and deletes second: that
order fails towards an unreferenced file, and the reverse fails towards a record
pointing at a deleted object, which breaks every render of that submission.

**Startup had the exact shape of the bug the brief describes.** `main` awaited
`Firebase.initializeApp` unguarded, so anything throwing there left a blank
splash with no way out. It now runs through `runStartup`, which cannot throw and
grades the two steps differently: localization failing is cosmetic and the app
still runs with keys showing, Firebase failing means there is no data layer and
the app says so with a Retry.

**A missing plugin mock was hiding a whole class of untestable widget.** Any
widget rendering a Storage-path image reaches the file cache, which asks
path_provider where to put files, which has no implementation in a test. Until
that channel was mocked in the harness, an image-bearing screen could not be
pumped at all, which is exactly how such a screen ends up with no test.

## Four layout bugs the tests found, none of which a passing unit test would

- `TcEmptyState` overflowed 144px in landscape.
- The learning unit's header block overflowed 325px in landscape.
- A step chip overflowed 5.3px at the 1.3x font ceiling: I had capped the chip's
  own width while its contents could not shrink.
- The login screen's "Change number / Resend code" row overflowed 50px at the
  same ceiling. Now a `Wrap`, so it reflows.

All four came from the same root cause, which is still open: the tokens scale
`.w` and `.sp` against a 360-wide baseline, so a wide viewport inflates
everything horizontally while `.r` shrinks. I have fixed each site to be
resilient rather than capping the width scale globally, because that is a
design-system decision with app-wide consequences and not mine to take
unilaterally.

## Still unverified

Everything below has only ever run against fakes. Listed so it is not mistaken
for done:

- Both Phase 1 acceptance checks. The redirect is unit-tested and the app has
  been seen to land on `/login` from a cold start on a real emulator, but no
  signed-in session has been killed and reopened.
- Every Firestore read, against real seeded documents.
- Every Storage interaction in Phases 4 and 5: no image has been resolved from a
  real bucket, and no evidence has been uploaded, recorded or deleted for real.
  The ordering guarantees are proven against a recording fake only.
- The Firestore rules, which are written and dry-run but not deployed.
- Rotation and font scaling on real hardware rather than a test surface.
