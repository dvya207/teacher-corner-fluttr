# Firestore shapes for the vertical slice

## READ THIS FIRST: the database changed, and so did every collection name

This app used to own a private database, `divya-teacher-corner`, seeded with
fixtures. It no longer does. It now reads **`teacher-corner-dev`**, the live
database owned by the Angular Teacher Corner web app in `~/code/teacher-corner`,
so that there is ONE source of truth for a teacher rather than a seeded copy of
one.

Everything below the "Verified live" section documents the **ThinkTac
production** shapes the parsers still tolerate. They are not what this app reads
day to day. `teacher-corner-dev` is close to production but not identical, and
the differences are the whole story.

### What this app may and may not do

| | |
|---|---|
| Reads | `users/{uid}`, `teachers`, `classrooms`, `programmes`, `learningUnits`, `workflows` |
| Writes | `users/{uid}/submissions/*` and Storage under `activityEvidence/*`. **Nothing else.** |
| Rules | Governed by `~/code/teacher-corner/firestore.rules`, deployed **only** from there. This repo has no `firestore.rules` and no `firestore` block in `firebase.json`, on purpose. |
| Seeding | Disabled. `tools/seed.js` refuses to run. The Admin SDK bypasses rules, so a seed here would overwrite live documents. |

### Collection names: lowercase here, capitalised in production

| This app reads | ThinkTac production calls it | Exists in `teacher-corner-dev`? |
|---|---|---|
| `users/{uid}` | `Users/{uid}` | yes, and the doc id IS the Auth uid |
| `teachers/{docId}` | `Teachers/{uid}` | yes, but **keyed differently** (see below) |
| `classrooms/{id}` | `Classrooms/{id}` | yes, same field names |
| `programmes/{id}` | `Programmes/{id}` | yes |
| `learningUnits/{id}` | `LearningUnits/{id}` | collection exists, **0 documents** |
| `workflows/{id}` | `Workflows/{id}` | **does not exist at all** |

### THE UID RELATIONSHIP, which is the one thing to get right

Two documents describe one person, and only one of them is keyed by the uid.

```
users/{uid}                     <- doc id IS the Firebase Auth uid.  DOC GET.
teachers/{clientAllocatedId}    <- doc id is NOT the uid.            QUERY.
  teacherMeta.uid: "<the Auth uid>"   <- stamped in on first sign-in
```

The web app allocates a `teachers` document id when an **admin registers** a
teacher, which happens before that person has an Auth account at all. Their uid
is written into `teacherMeta.uid` later, the first time they sign in with the
registered number (`TeacherService.linkSignedInUid`). So:

```dart
// WRONG. Succeeds, and reports "does not exist" for a teacher whose
// record is sitting right there under another id.
db.collection('teachers').doc(uid).get()

// RIGHT.
db.collection('teachers').where('teacherMeta.uid', isEqualTo: uid).limit(1)
```

`teacherMeta.uid` being **absent** is a normal state, not corruption: it means
nobody has registered that phone number yet. The app reports it as "no teacher
record is linked to this number" and invents nothing.

### Which document wins which question

`users/{uid}` is authoritative for **identity** (name, school), because it is
written from the teacher's own Auth record and their own profile form.
`teachers/{docId}` is authoritative for **teaching** (classrooms, programmes),
because it is the only one that carries them. `TeacherAccount` joins the two.

They **do disagree in live data**. Both are read; the profile wins the name.

### Verified live, in `teacher-corner-dev`

Read-only, at the time of the repoint:

```
root collections   Configuration, OTPVerifications, classrooms,
                   institutions, programmes, teachers, users
                   (no workflows, no learningUnits documents)
users              6 documents
teachers           6 documents, exactly ONE with teacherMeta.uid set
programmes         10 documents
learningUnits      0 documents
submissions        none anywhere; users/{uid} has no subcollections
```

Real differences from the production shapes documented below:

- `teacherMeta` has **no `institutionName`** and **no `designation`**. The school
  is denormalised onto each classroom entry instead, so `Teacher.institutionName`
  falls back to the first classroom that names one.
- `teacherMeta` carries **both** `phone` and `phoneNumber`, same digits, and the
  dial code separately in `countryCode`.
- A classroom entry's `programmes` is an **ARRAY**, not a map keyed by id.
  `KeyedEntries` already tolerates both.
- `grade` is a **string**, and not always numeric: `'9'`, but also
  `'Pre-primary 2'`. It parses to `null`, which means "no grade", never zero.
- `workflowIds` is **absent** on every classroom programme entry, so no classroom
  currently names any activity.
- `studentCounter` is `0` on every classroom. Zero is a fact here, not a missing
  read.

---

## The production shapes, which the parsers still tolerate

Below is the original reference. The collection NAMES in these headings are
production's capitalised ones and are **not** what this app queries; the field
names inside are accurate for both, which is why the parsers work against either.

## `Teachers/{uid}`

The signed-in teacher. `uid` is the Firebase Auth uid.

```
Teachers/lVjaw…bt42
  name:            "Divya Jain"          // fallback if teacherMeta absent
  teacherMeta: {                          // nested map, NOT a subcollection
    firstName:     "Divya"
    lastName:      "Jain"
    phoneNumber:   "+919999900000"
    email:         "divya.jain@intern.ispf.ngo"
    institutionName: "Test School Oak"
    designation:   "Teacher"
  }
  classrooms: {                           // MAP keyed by classroom id
    "cls_oak_7a": {
      classroomId:   "cls_oak_7a"
      classroomName: "7 A"
      type:          "CLASSROOM"          // or "STEM-CLUB"
      grade:         7                    // int
      section:       "A"
      institutionName: "Test School Oak"
      programmes: {                        // map OR list, tolerate both
        "prog_tip_2026": {
          programmeId: "prog_tip_2026"
          displayName: "TIP 2026"
        }
      }
    }
  }
```

**Gotcha.** `grade` is an `int` here, but the production data has at least one
classroom where it is the **string** `"ET"`. Parse it as `int?` and let null
mean "no grade", rather than crashing or defaulting to 0.

**Gotcha.** `classrooms` and `programmes` are maps keyed by id, not arrays. The
key IS the id; the nested `classroomId`/`programmeId` field is a duplicate of it
and is sometimes missing. Prefer the key.

---

## `Classrooms/{classroomId}`

The authoritative classroom doc. The copy nested under the teacher is a
denormalised summary, read this one when you need the full picture.

```
Classrooms/cls_oak_7a
  classroomName:   "7 A"                  // "name" in older docs
  stemClubName:    null                   // used INSTEAD of classroomName when type == "STEM-CLUB"
  type:            "CLASSROOM"
  grade:           7
  section:         "A"
  board:           "CBSE"
  institutionName: "Test School Oak"
  studentCounter:  32                     // note the name: counter, not count
  programmes: {
    "prog_tip_2026": {
      displayName: "TIP 2026"
      workflowIds: [                       // list OR map, tolerate both
        { learningUnitId: "lu_magnetic_pen_stand", workflowId: "wf_mps_v1" }
      ]
    }
  }
```

**Gotcha.** The learning units a classroom is doing, and the workflow used for
each, live **here on the classroom**, not on the learning unit. The same
learning unit can run a different workflow in a different classroom. This is the
single most counter-intuitive thing in the data model.

---

## `LearningUnits/{luId}`

The activity itself. Shared across classrooms.

```
LearningUnits/lu_magnetic_pen_stand
  learningUnitDisplayName: "Magnetic Pen Stand"   // then learningUnitName, then name
  type:                    "TACtivity"
  shortDescription:        "Build a pen stand that holds itself up with magnets."
  longDescription:         "…"
  stepCount:               6
  subjectName:             "Science"
  learningUnitPreviewImage: "luImages/mps_200x200.png"   // STORAGE PATH, not a URL
  Maturity:                "gold"
  resources: { gold: "lur_mps_gold" }             // -> LearningUnitResources doc id
```

**Gotcha.** `learningUnitPreviewImage` is a **Storage path**, not a download
URL. You resolve it with `getDownloadURL()`, and see the caching note in the
plan before you do that in a list.

---

## `workflows/{workflowId}`

**THIS COLLECTION DOES NOT EXIST IN `teacher-corner-dev`.** The web app has no
workflow feature. Its classroom programme entries have a `workflowIds` array
whose rows carry a `workflowId`, but there is nothing for those strings to point
at, and in the live data the array is absent anyway.

A read therefore returns "does not exist", which `fetchWorkflow` reports as null
and which the learning unit route renders as the missing-workflow screen. That is
the intended behaviour, not a bug to work around. The constant is spelled
lowercase to match the database's convention, so the day workflows land there
this starts working with no code change.

The shape below is production's, for whenever that happens.

The ordered steps a teacher walks through in class.

```
Workflows/wf_mps_v1
  steps: [
    {
      workflowStepId:    "s1"
      workflowStepName:  "Introduce the problem"
      workflowStepType:  "INTRO"
      sequenceNumber:    1
      workflowStepDuration: 10
      canSkipWorkflowStep: false
      allowArtefactUpload: false
      contents: [
        { contentName: "Guide", contentCategory: "guide",
          contentType: "guide", resourcePath: "guides/mps.pdf" }
      ]
    },
    {
      workflowStepId:    "s6"
      workflowStepName:  "Capture evidence"
      sequenceNumber:    6
      allowArtefactUpload: true
      assignmentId:      "asg_mps_evidence"
      contents: [
        { contentName: "Photo evidence", contentCategory: "assignment",
          assignmentType: "UPLOAD", assignmentId: "asg_mps_evidence" }
      ]
    }
  ]
```

**Gotcha.** `sequenceNumber` is the display order. Do not rely on array order -
seed them out of order once, on purpose, and make sure your UI still sorts right.

---

## `users/{uid}/submissions/{classroomId}-{programmeId}`

Where evidence is recorded. One document per classroom+programme, with a map
per assignment inside it.

**UNDER `users`, NOT `teachers`, and this one is not production's shape.** Two
reasons, both decisive:

- `teachers/{docId}` is not keyed by uid, so there is no `teachers/{uid}` to nest
  under. Writing one would add a junk top-level document to a collection the live
  web app lists.
- The web app's deployed rules already grant `users/{uid}/{document=**}` to that
  uid and nobody else, so this path needs **no rules change and no deploy from
  this repo**. Its own `firestore-paths.ts` documents this shape
  (`userSubcollection`) as the intended home for anything private to one teacher.

The web app has no submissions, no evidence and no Storage wiring of any kind,
which was verified before choosing this location. Nothing it uses is touched.

```
users/7vbKdBSqG3YRI6X1GzFNeQD24Rm1/submissions/0BjL4c151I9W3xZ34ZEP-96HxMlMZzyGhyh0vpQhl
  asg_mps_evidence: {
    displayName:  "Photo evidence"
    luId:         "lu_magnetic_pen_stand"
    type:         "UPLOAD"
    contentType:  "image/jpeg"
    photoUrls:    ["https://firebasestorage…", "…"]
    storagePaths: ["activityEvidence/cls_oak_7a/lu_magnetic_pen_stand/uid_1787132584464_0.jpg", "…"]
  }
```

**Why both `photoUrls` and `storagePaths`.** The URL is what you render. The
path is what you need to **delete** the object later, you cannot reliably
derive one from the other, because Firebase mints a fresh access token into
every `getDownloadURL()` result. Store both, always, and keep the two lists
index-aligned. Getting this wrong is how you end up with orphaned objects in
Storage that nothing references and nobody can find.

Storage layout for evidence:

```
activityEvidence/{classroomId}/{luId}/{uid}_{millisSinceEpoch}_{index}.jpg
```

The uid in the path is what makes a submission attributable. Leave it out and
you have an image nobody can trace to a teacher.
