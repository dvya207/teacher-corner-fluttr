# Teacher Corner: intern rebuild starter

You are going to build a working slice of the ThinkTac Teacher Corner Android
app, from scratch, in Flutter. This repo is the boilerplate you do **not** need
to write: the design system, the shared widget library, the theme, the router
skeleton, and the i18n scaffold. Everything that makes the app actually *do*
something, you write yourself.

What is deliberately **not** here: no services, no providers, no data models,
no feature screens, no authentication. Those are the exercise.

Read `PLAN.md` for the phase-by-phase brief and `SCHEMA.md` for the Firestore
shapes. Start here for setup.

---

## 1. Prerequisites

| | |
|---|---|
| Flutter | 3.44.1 stable (`flutter --version`). Dart 3.12 |
| Java | **17.** Not 21. The Android Gradle plugin config expects 17. |
| Android Studio | for the SDK + an emulator, or a physical device with USB debugging |
| Node | 20+, for the seed script only |

Verify before you start:

```bash
flutter doctor -v
```

Resolve every ✗ against Android before going further. A half-configured
Android toolchain produces build errors that look like code errors.

## 2. Generate the Android platform

This starter ships `lib/` and `assets/` only, there is no `android/` directory,
because the Android package name has to be yours, not a copy of someone else's.
Generate it once, from the project root:

```bash
flutter create --platforms=android --org com.thinktac.tc --project-name tc_starter .
```

That creates `android/` with applicationId `com.thinktac.tc.tc_starter`. It will
not touch `lib/`. Check `git status` afterwards and revert anything it changed
that you did not expect, in particular it likes to rewrite `pubspec.yaml`.

## 3. Get it running

```bash
flutter pub get
flutter analyze          # must print "No issues found!"
```

If `flutter analyze` is not clean on a fresh clone, something is wrong with
your toolchain, not with this code.

## 4. Point it at Firebase

The project is **`helix-staging-india`**. You do not get access to production,
and you will not need it.

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=helix-staging-india --platforms=android
```

That registers a new Android app in the project, overwrites the stub at
`lib/firebase_options.dart`, and writes `android/app/google-services.json`.
Both files are gitignored. **Never commit them, and never commit anything that
looks like a key, token or password**, not in Dart, not in a config file, not
"just temporarily".

There is no Android app registered in that project yet, so you are creating the
first one. Give it a package name of your own: `com.thinktac.tc.divya`.

## 5. The Firestore database: `teacher-corner-dev`, and it is not ours

This app reads the **existing** Teacher Corner Dev database. It does not have one
of its own any more.

```dart
// lib/core/firebase/firestore_ref.dart
const String kDatabaseId = 'teacher-corner-dev';
```

`helix-staging-india` holds several named databases: `(default)`, `bugpulse`,
`ezblog`, `sidteachercorner` and `teacher-corner-dev`.
The last one belongs to the **live Angular Teacher Corner web app** in
`~/code/teacher-corner`, and it holds real teachers, classrooms and programmes
that real people are using. This app is a guest in it, so that a teacher's
details have ONE source of truth rather than a seeded copy.

`divya-teacher-corner` is the database this app used to own. It was **deleted on
2026-08-24**, after the `tcDivya*` OTP functions were repointed at
`teacher-corner-dev` and redeployed, so this app now uses one database for
everything it touches. Their `OTPVerifications` documents are therefore SHARED with the web
app's own `tcDevSendOtp` / `tcDevVerifyOtp`, which key a document on the same
normalized phone number. For a number used in both apps that means one challenge
at a time, one send cap and one attempt cap between them; the header of
`functions-otp/src/index.ts` sets out exactly what that costs and why it was
accepted. The old database no longer exists, so pointing `kDatabaseId` back at
it would not fall back to anything; every read and write would simply fail.

**This is the single biggest trap in this project.** `FirebaseFirestore.instance`
*always* talks to the `(default)` database. It does not error, it does not warn,
it just silently reads and writes the wrong place. Every query in this app must
go through the `db` handle in `firestore_ref.dart`. If the Console shows nothing
after a write that "succeeded", this is why.

### The three rules of being a guest

**1. Read only, except evidence.** The only thing this app writes is
`users/{uid}/submissions/*` plus its Storage objects. Nothing here rewrites a
teacher, a classroom, a programme or a learning unit.

**2. No rules deploy from this repo, ever.** There is no `firestore.rules` here
and no `firestore` block in `firebase.json`, and both absences are deliberate.
The rules governing this data live in `~/code/teacher-corner/firestore.rules` and
are deployed only from there. A rules deploy **replaces** a database's whole
ruleset rather than merging into it, so one careless `firebase deploy` from this
directory could revoke the live web app's own access. With no block at all,
`firebase deploy --only firestore` from here has nothing to target and fails
instead of succeeding destructively.

The app needs no rules change anyway: the web app's deployed ruleset already
grants every signed-in user read on `classrooms`, `programmes`, `learningUnits`
and `teachers`, and grants `users/{uid}/{document=**}` to that uid.

**3. No seeding.** `tools/seed.js` and `tools/seed_dryrun.js` refuse to run. The
Admin SDK **bypasses security rules**, so a seed here is not blocked by anything:
`set()` on a fixed document id would overwrite a live document, and fixtures that
did not collide would still add invented rows to collections the web app lists.

## 6. Sign in, and where the data comes from

There is nothing to seed. Sign in with the phone number an administrator has
registered in the web app, and the app reads what is already there.

The uid relationship is the one thing to understand, because getting it wrong
fails **silently**:

```
users/{uid}                     <- doc id IS your Auth uid.  A DOC GET.
teachers/{clientAllocatedId}    <- doc id is NOT your uid.   A QUERY on
  teacherMeta.uid: "<your uid>"    teacherMeta.uid.
```

An admin registers a teacher before that person has an Auth account, so the
`teachers` document id is allocated then and the uid is stamped into
`teacherMeta.uid` on their first sign-in. `doc(uid).get()` on `teachers` does not
error, it cheerfully reports "does not exist".

If the dashboard shows **"no teacher record is linked to this number yet"**, that
is the honest state and not a bug: no `teachers` document carries your uid.
An administrator fixes it by registering your number against a classroom in the
web app. Do not write fixtures to work around it.

To see what is actually in the database, read it. Reads are always safe:

```bash
gcloud auth application-default login   # once
# then a short read-only Admin SDK script using
# getFirestore(app, 'teacher-corner-dev')
```

### What the six screens can and cannot show

The web app has no workflow feature and no learning unit documents yet, so:

| Screen | State |
|---|---|
| Splash, login | works |
| Dashboard | your name, school, classroom and programme counts, classroom rows |
| Classroom list, classroom detail | works, including each classroom's programmes |
| Profile | works |
| Learning unit | `workflows` does not exist in this database, so it lands on the missing-workflow screen |
| Evidence | writes to `users/{uid}/submissions/*`, reachable only once a workflow exists |

---

## What is in here

```
lib/core/theme/       Design tokens, colours, typography, spacing, radii.
                      DO NOT hardcode a colour or a font size anywhere else.
lib/core/widgets/     15 tc_* components. Compose these before writing new ones.
lib/core/utils/       safe_parse.dart, defensive Firestore parsing. Read it.
lib/core/firebase/    The one Firestore handle. See §5.
lib/core/router/      go_router skeleton: shell + guard wired, screens stubbed.
lib/features/shell/   Bottom-nav shell.
assets/l10n/          en + hi. Every user-facing string goes here, from day one.
assets/fonts/         Montserrat (headings) + Noto Sans (body). Bundled, not fetched.
tools/seed.js         DISABLED. Refuses to run; see §5.
```

### The two rules that will bite you

**1. Build the `GoRouter` once.** In `initState`, held in a field. If you
construct it inside `build()` or a `Consumer`, it is recreated on every
`notifyListeners()` and the entire navigation stack is wiped, the user gets
thrown back to the first screen mid-task. `main.dart` already does this
correctly; keep it that way.

**2. `ScreenUtilInit` sits above `MaterialApp`.** Every `.sp`/`.w`/`.h`/`.r` is
evaluated after it initialises. That is also why the tokens in
`app_dimensions.dart` and `app_typography.dart` are **getters, not constants** -
a `static const` using `.sp` throws a `LateInitializationError`. If you add a
token, make it a getter.

### Style

Read `analysis_options.yaml`. Keep `flutter analyze` at zero issues, not
"mostly clean". Write the comment that explains *why*, not *what*: the code
already says what it does.
