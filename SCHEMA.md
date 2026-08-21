# Firestore shapes for the vertical slice

Only the collections the slice needs. The production app touches 25; you need 4.

Every field below is what the real app reads. Where a field has two or three
possible names, that is not a typo, the data was written by three different
systems over several years and the app tolerates all of them. You should seed
only the **preferred** name, but write your parsing so a missing field degrades
instead of throwing.

---

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

## `Workflows/{workflowId}`

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

## `Teachers/{uid}/submissions/{classroomId}-{programmeId}`

Where evidence is recorded. One document per classroom+programme, with a map
per assignment inside it.

```
Teachers/lVjaw…bt42/submissions/cls_oak_7a-prog_tip_2026
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
