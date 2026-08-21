# The brief: build a Teacher Corner slice

## What this app is

ThinkTac Teacher Corner is the Android app a school teacher opens **in the
middle of a live science class**. It tells them which activity they are running,
walks them through it step by step, gives them the guide and materials list, and
lets them photograph what the children built as evidence that the activity
happened.

That context sets every priority. The teacher is standing in front of 32
children on school wifi. Slow is broken. A spinner that never resolves is worse
than an error message. Offline has to degrade, not fail.

The production app is 118 Dart files and about 30,000 lines, with 41 routes and
25 Firestore collections. **You are not rebuilding that.** You are rebuilding one
vertical slice through all of it:

```
Login  →  Dashboard  →  Classroom list  →  Classroom  →  Learning unit  →  Submit photo evidence
```

Six screens. But that line crosses every layer the real app has, auth, routing,
state, Firestore modelling, Storage, image handling, the design system, i18n and
error states. When you finish it you will have touched everything, at about a
tenth of the volume.

## Ground rules

1. **Every user-facing string goes in `assets/l10n/en.json`** from the first
   screen. Retrofitting i18n across 40 screens is miserable work; doing it as
   you go costs nothing.
2. **No hardcoded colours, font sizes, spacing or radii.** They are all tokens
   in `lib/core/theme/`. If you need a value that is not there, add a token.
3. **Compose the `tc_*` widgets before writing a new one.** There are 15. Read
   them first.
4. **`flutter analyze` stays at zero issues.** Not "mostly clean".
5. **Nothing that looks like a secret goes in the repo.** No keys, no tokens, no
   passwords, no phone numbers of real people. Not even temporarily.
6. **Ask when the data surprises you.** Half of this app's complexity is the
   data model, and some of it is genuinely counter-intuitive rather than wrong.

---

## Phase 1 · Auth and the shell
**Goal:** a real teacher can sign in, and the router keeps unauthenticated
users out.

Build:

- `AuthProvider` (a `ChangeNotifier`) holding `uid`, the loaded `Teacher`, and
  an `authLoaded` flag.
- Sign-in with **Firebase phone auth** (`verifyPhoneNumber` → OTP → `signInWithCredential`).
- A splash screen that waits for auth to resolve before routing anywhere.
- Wire `AuthProvider` into the router's `refreshListenable` (`main.dart` already
  shows the shape).

**Use stock Firebase phone auth.** The production app does something different
and more complicated for reasons that are specific to Indian SMS delivery
regulations, and you should not copy it.

**Acceptance:** kill the app while signed in, reopen it, and you land on the
dashboard without seeing the login screen flash. Sign out and you cannot reach
`/dashboard` by any route.

**The trap:** `authLoaded` and `isAuthenticated` are two different things. On a
cold start you do not yet know whether the user is signed in. If your redirect
treats "not yet known" as "not signed in", every launch flashes the login
screen. Hold the splash until auth has actually resolved.

---

## Phase 2 · The data layer
**Goal:** a dashboard showing the real teacher's name, their institution, and
how many classrooms and programmes they have.

Build:

- Models: `Teacher`, `ClassroomRef`, `ProgrammeRef`. Read `SCHEMA.md`.
- A `FirestoreService`, one class, all reads in it, going through the `db`
  handle from `firestore_ref.dart`. No screen talks to Firestore directly.
- A `DashboardProvider` that loads once and exposes loading / loaded / error.
- The dashboard screen, built from `TcHeroHeader` + `TcHeroStatTile`.

**Acceptance:** three visibly distinct states (loading, loaded, error) and a real
error state with a working Retry. Turn wifi off and confirm you get the error
state, not a spinner that never stops.

**The trap, and it is the important one:** read `lib/core/utils/safe_parse.dart`
before you write a single `fromMap`. This data has been written by three
different systems over several years. A field that is an `int` in 99 documents is
a `String` in the hundredth. A field that is a `List` here is a `Map` there. A
field the schema promises is simply absent. **Never** write
`data['grade'] as int`. One bad document should degrade one row, never crash the
screen.

---

## Phase 3 · Classrooms
**Goal:** list the teacher's classrooms, search them, open one.

Build:

- `ClassroomProvider`, the classroom list screen, `TcSearchBar`.
- A classroom card showing name, grade/section, institution and student count.
- Classroom detail: the programmes, and the learning units within each.
- `TcEmptyState` for a teacher with no classrooms.

**Acceptance:** searching "oak" finds the classroom whose *institution* is Test
School Oak, not just ones whose *name* contains "oak". Real teachers search by
school far more often than by class name. The seeded STEM-CLUB with `grade: "ET"`
renders without crashing and without printing "null".

**The trap:** the learning units a classroom is doing, and the workflow used for
each one, live on the **classroom** document, not on the learning unit. The same
activity runs a different workflow in a different classroom. Expect to re-read
`SCHEMA.md` on this one.

---

## Phase 4 · The learning unit
**Goal:** open an activity and walk its steps.

Build:

- `LearningUnit`, `WorkflowStep`, `WorkflowContent` models.
- A horizontal step indicator, and a tab strip for the content within a step.
- Render at least a text content type and an image content type.
- Resolve `learningUnitPreviewImage` (a **Storage path**, not a URL) for the card.

**Acceptance:** steps appear in `sequenceNumber` order even though the seed
stores them out of array order. Selecting step 5 scrolls the indicator so step 5
is actually visible. Switching tabs and coming back does not re-download
anything.

**Three traps, all of which cost the production team real days:**

- **Cache on the Storage path, never on the download URL.** Firebase mints a
  fresh access token into every `getDownloadURL()` result, so the same file
  yields a different URL every call. URL-keyed caching never hits, it looks
  like it works and silently re-downloads forever.
- **Check the cache *before* resolving the URL.** Otherwise a fully cached file
  still costs a network round trip, and still fails offline.
- **A destroyed tab is a re-downloaded tab.** If you only build the active tab,
  every switch rebuilds from scratch. `IndexedStack` plus
  `AutomaticKeepAliveClientMixin` keeps them alive.

---

## Phase 5 · Photo evidence
**Goal:** a teacher photographs the children's work and submits it.

Build:

- Pick from camera **or** gallery, both always offered. Not one or the other.
- Up to 3 photos, 3 MB each, with the limit stated **before** they hit it.
- A **pick → review → submit** flow: thumbnails first, remove any of them, then
  one Submit.
- On submit: upload to
  `activityEvidence/{classroomId}/{luId}/{uid}_{millis}_{index}.jpg`, then write
  `photoUrls` **and** `storagePaths` to
  `Teachers/{uid}/submissions/{classroomId}-{programmeId}`.
- Removal of an already-submitted photo: rewrite the record, then delete the object.

**Nothing reaches Storage until Submit is pressed.** If you upload on pick, every
photo a teacher changes their mind about is an orphan in Storage forever, with
nothing referencing it and no way to find it. The production app had exactly six
of these before this was fixed.

**Acceptance:** after every operation, the Firestore record and the Storage
objects agree, same count, index-aligned. Verify in the Console, not in the UI.
Then submit with wifi off and decide what *should* happen; the production app
queues it.

**The traps:**

- **Store the Storage path alongside the URL.** You cannot derive the path back
  from a tokenised download URL, so without it you can never delete the object.
- **The uid belongs in the path.** Leave it out and you have evidence nobody can
  attribute to a teacher.
- **Guard your submit against re-entry.** An in-flight flag, checked and set
  before any await. There is currently an unexplained production anomaly where a
  removal appears to have triggered a second upload, and a missing re-entry
  guard is one of the candidate causes.

---

## Phase 6 · Make it survive contact
**Goal:** the polish that separates a demo from something a teacher can use.

- Widget tests for the classroom list, the search filter, and the evidence card.
  Test the *contract*, when you change behaviour, rewrite the test to the new
  contract rather than deleting it.
- Every screen has a real error state and a real empty state.
- Nothing non-essential blocks startup. Anything you initialise before
  `runApp` must degrade rather than take the app down. The production app
  shipped a build that hung on a blank splash because one storage key could not
  be decrypted on upgrade, and that bug was invisible in debug, because it only
  arises from **install history**, never from a fresh install.
- Rotate the device on every screen and fix the overflows.
- Set the system font size to maximum and confirm nothing is unreadable or clipped.

---

## Definition of done

- The full path works on a **physical Android device**, not only an emulator.
- `flutter analyze` is clean and the tests pass.
- Firestore and Storage agree after every evidence operation.
- Every string is in `en.json`, and `hi.json` has at least the navigation.
- No secrets in the repo, and no production access was ever needed.
- A short `NOTES.md` in your own words: what the data model does that you did
  not expect, and what you would build differently a second time.

## Pace

Go at whatever pace the work actually takes. The phases are ordered because each
one depends on the last, not because they are timed.

Phases 2 and 4 hold the real difficulty. Phase 2 because the data is messier
than any schema suggests, Phase 4 because caching is easy to get subtly and
invisibly wrong. If those two feel slower than the rest, that is the work being
hard, not you being slow.

Ask early. Time lost to a wrong assumption about the data model is time nobody
needed to spend.
