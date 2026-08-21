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

## 5. Pick your own Firestore database

`helix-staging-india` has several named Firestore databases in it, including
other people's work (`sidteachercorner`, `teacher-corner-dev`). **Create your
own** in the Firebase Console. Firestore → the database dropdown → Create
database, and name it something unambiguous like `divya-teacher-corner`.

Then set it in one place:

```dart
// lib/core/firebase/firestore_ref.dart
const String kDatabaseId = 'divya-teacher-corner';
```

**This is the single biggest trap in this project.** `FirebaseFirestore.instance`
*always* talks to the `(default)` database. It does not error, it does not warn,
it just silently reads and writes the wrong place. Every query in this app must
go through the `db` handle in `firestore_ref.dart`. If the Console shows nothing
after a write that "succeeded", this is why.

## 6. Seed some data

You cannot build a data-driven app against an empty database.

```bash
cd tools && npm install firebase-admin && cd ..
gcloud auth application-default login
node tools/seed.js --database=divya-teacher-corner --uid=<your-auth-uid>
```

Get your uid by signing in once and printing
`FirebaseAuth.instance.currentUser!.uid`, or from Console → Authentication.

The seed is idempotent, re-run it as often as you like. It deliberately
includes awkward data (a classroom whose `grade` is the string `"ET"`, one
`workflowIds` as a list and one as a map) because the real data is like that and
your parsing needs to survive it.

It also uploads the image fixtures the learning unit screen needs, because a
Storage path in Firestore with no object behind it is not a fixture, it is a
broken link that looks like an app bug. Those objects are namespaced by database
id (`luImages/<your-db>/…`), since every developer's named database shares one
Storage bucket in this project and an un-namespaced fixture would overwrite
everyone else's. Add `--skip-storage` to seed Firestore only, for instance if
you do not have write access to the bucket.

To see exactly what the seed would write, with no credentials and no network:

```bash
node tools/seed_dryrun.js
```

Its last section lists any Storage path referenced in Firestore that has no
object, which is the mistake worth catching.

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
tools/seed.js         Sample data.
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
