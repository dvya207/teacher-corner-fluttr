import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/assignment_evidence.dart';
import 'package:tc_starter/core/services/evidence_storage.dart';
import 'package:tc_starter/core/services/photo_picker.dart';
import 'package:tc_starter/features/evidence/evidence_provider.dart';

import '../../support/fakes.dart';

const _uid = 'uid_teacher';
const _classroom = 'cls_oak_7a';
const _programme = 'prog_tip_2026';
const _lu = 'lu_magnetic_pen_stand';
const _assignment = 'asg_mps_evidence';
const _millis = 1787132584464;

/// Records every call, in order, into a shared log.
class RecordingStorage implements EvidenceStorage {
  RecordingStorage({this.log, this.failUploadAtIndex, this.failDelete = false});

  final List<String>? log;

  /// Makes the nth upload of a batch throw, to exercise partial failure.
  final int? failUploadAtIndex;
  final bool failDelete;

  final List<String> uploaded = [];
  final List<String> deleted = [];

  @override
  Future<String> upload({
    required String storagePath,
    required File file,
    String contentType = 'image/jpeg',
  }) async {
    log?.add('upload:$storagePath');
    if (failUploadAtIndex != null && uploaded.length == failUploadAtIndex) {
      throw StateError('upload blew up');
    }
    uploaded.add(storagePath);
    // A tokenised URL, different every time, exactly like the real thing.
    return 'https://firebasestorage/$storagePath?token=${uploaded.length}';
  }

  @override
  Future<void> delete(String storagePath) async {
    log?.add('delete:$storagePath');
    if (failDelete) throw StateError('delete blew up');
    deleted.add(storagePath);
  }
}

class QueuePicker implements PhotoPicker {
  QueuePicker(this.queue, {this.throwsOnPick = false});

  final List<PickedPhoto?> queue;
  final bool throwsOnPick;
  final List<PhotoSource> calls = [];

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    calls.add(source);
    if (throwsOnPick) throw StateError('picker blew up');
    if (queue.isEmpty) return null;
    return queue.removeAt(0);
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tc_evidence');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  var fileSeq = 0;
  PickedPhoto photo({int bytes = 1024}) {
    final file = File('${tempDir.path}/p${fileSeq++}.jpg')
      ..writeAsBytesSync(List<int>.filled(bytes, 0));
    return PickedPhoto(file: file, sizeBytes: bytes);
  }

  ({
    EvidenceProvider provider,
    RecordingStorage storage,
    QueuePicker picker,
    FakeFirestoreService firestore,
    List<String> log,
  }) build({
    List<PickedPhoto?> queue = const [],
    AssignmentEvidence? existing,
    int? failUploadAtIndex,
    bool failDelete = false,
    Object? throwsOnWrite,
    Object? throwsOnFetch,
    bool pickerThrows = false,
  }) {
    final log = <String>[];
    final storage = RecordingStorage(
      log: log,
      failUploadAtIndex: failUploadAtIndex,
      failDelete: failDelete,
    );
    final picker = QueuePicker(List.of(queue), throwsOnPick: pickerThrows);
    final firestore = FakeFirestoreService(
      evidence: existing,
      throwsOnWriteEvidence: throwsOnWrite,
      throwsOnFetchEvidence: throwsOnFetch,
      log: log,
    );
    return (
      provider: EvidenceProvider(
        firestore: firestore,
        storage: storage,
        picker: picker,
        uid: _uid,
        classroomId: _classroom,
        programmeId: _programme,
        learningUnitId: _lu,
        assignmentId: _assignment,
        displayName: 'Photo evidence',
        clock: () => _millis,
      ),
      storage: storage,
      picker: picker,
      firestore: firestore,
      log: log,
    );
  }

  group('nothing reaches Storage until Submit', () {
    test('picking uploads nothing at all', () async {
      final t = build(queue: [photo(), photo()]);
      await t.provider.load();

      await t.provider.pick(PhotoSource.camera);
      await t.provider.pick(PhotoSource.gallery);

      // The whole reason uploads wait: a photo the teacher changes their mind
      // about would otherwise be an orphan in Storage forever.
      expect(t.storage.uploaded, isEmpty);
      expect(t.firestore.writes, isEmpty);
      expect(t.provider.pending, hasLength(2));
      expect(t.provider.submitted, isEmpty);
    });

    test('removing a pick before submit leaves nothing behind', () async {
      final t = build(queue: [photo(), photo()]);
      await t.provider.load();
      await t.provider.pick(PhotoSource.camera);
      await t.provider.pick(PhotoSource.gallery);

      t.provider.removePending(0);

      expect(t.provider.pending, hasLength(1));
      expect(t.storage.uploaded, isEmpty);
      expect(t.storage.deleted, isEmpty);
    });

    test('both camera and gallery are usable', () async {
      final t = build(queue: [photo(), photo()]);
      await t.provider.load();

      await t.provider.pick(PhotoSource.camera);
      await t.provider.pick(PhotoSource.gallery);

      expect(t.picker.calls, [PhotoSource.camera, PhotoSource.gallery]);
    });
  });

  group('the limits, stated before they are hit', () {
    test('a fourth photo is refused without opening the camera', () async {
      final t = build(queue: [photo(), photo(), photo(), photo()]);
      await t.provider.load();
      for (var i = 0; i < 3; i++) {
        await t.provider.pick(PhotoSource.camera);
      }

      expect(t.provider.remainingSlots, 0);
      final callsBefore = t.picker.calls.length;

      await t.provider.pick(PhotoSource.camera);

      // Not invited to take a photo that would be thrown away.
      expect(t.picker.calls.length, callsBefore);
      expect(t.provider.pending, hasLength(3));
      expect(t.provider.errorKey, 'evidence.error_limit');
    });

    test('already-submitted photos count towards the three', () async {
      final t = build(
        queue: [photo(), photo()],
        existing: const AssignmentEvidence(
          assignmentId: _assignment,
          photoUrls: ['u1', 'u2'],
          storagePaths: ['p1', 'p2'],
        ),
      );
      await t.provider.load();

      expect(t.provider.remainingSlots, 1);

      await t.provider.pick(PhotoSource.camera);
      expect(t.provider.remainingSlots, 0);

      await t.provider.pick(PhotoSource.camera);
      expect(t.provider.errorKey, 'evidence.error_limit');
      expect(t.provider.totalCount, 3);
    });

    test('a photo over 3 MB is rejected and not kept', () async {
      final t = build(queue: [photo(bytes: kMaxEvidenceBytes + 1)]);
      await t.provider.load();

      await t.provider.pick(PhotoSource.camera);

      expect(t.provider.pending, isEmpty);
      expect(t.provider.errorKey, 'evidence.error_too_large');
      expect(t.provider.errorArgs, ['3']);
    });

    test('a photo exactly at the cap is accepted', () async {
      final t = build(queue: [photo(bytes: kMaxEvidenceBytes)]);
      await t.provider.load();

      await t.provider.pick(PhotoSource.camera);

      expect(t.provider.pending, hasLength(1));
      expect(t.provider.errorKey, isNull);
    });

    test('a cancelled pick is not an error', () async {
      final t = build(queue: [null]);
      await t.provider.load();

      await t.provider.pick(PhotoSource.gallery);

      expect(t.provider.pending, isEmpty);
      expect(t.provider.errorKey, isNull);
    });
  });

  group('submit', () {
    test('uploads every pending photo, then writes the record once', () async {
      final t = build(queue: [photo(), photo()]);
      await t.provider.load();
      await t.provider.pick(PhotoSource.camera);
      await t.provider.pick(PhotoSource.gallery);

      await t.provider.submit();

      expect(t.storage.uploaded, hasLength(2));
      expect(t.firestore.writes, hasLength(1));
      // Every upload precedes the single write.
      expect(t.log.indexOf('writeEvidence'),
          greaterThan(t.log.lastIndexWhere((e) => e.startsWith('upload:'))));
      expect(t.provider.pending, isEmpty);
      expect(t.provider.submitted, hasLength(2));
    });

    test('the Storage path carries the uid, classroom, unit and index',
        () async {
      final t = build(queue: [photo(), photo()]);
      await t.provider.load();
      await t.provider.pick(PhotoSource.camera);
      await t.provider.pick(PhotoSource.camera);

      await t.provider.submit();

      expect(t.storage.uploaded, [
        'teacher_submissions/$_uid/${_classroom}_${_lu}_${_millis}_0.jpg',
        'teacher_submissions/$_uid/${_classroom}_${_lu}_${_millis}_1.jpg',
      ]);
      // THE UID IS THE SECOND SEGMENT, not just present somewhere in the
      // string. The deployed rule binds it as {teacherId} and compares it to
      // request.auth.uid, so a uid that moved into the filename would leave
      // the object at a path the rule refuses. Asserted positionally for that
      // reason rather than with `contains`.
      for (final path in t.storage.uploaded) {
        expect(path.split('/')[1], _uid);
        // Exactly three segments: the rule's {fileName} binds ONE, so any
        // extra slash puts the object where no rule claims it.
        expect(path.split('/').length, 3);
      }
    });

    test('photoUrls and storagePaths are index-aligned', () async {
      final t = build(queue: [photo(), photo(), photo()]);
      await t.provider.load();
      for (var i = 0; i < 3; i++) {
        await t.provider.pick(PhotoSource.camera);
      }

      await t.provider.submit();

      final written = t.firestore.writes.single;
      expect(written.photoUrls, hasLength(3));
      expect(written.storagePaths, hasLength(3));
      expect(written.isMisaligned, isFalse);
      for (var i = 0; i < 3; i++) {
        // Each URL is the one minted for the path at the same index.
        expect(written.photoUrls[i], contains(written.storagePaths[i]));
      }
    });

    test('appends to an existing record rather than replacing it', () async {
      final t = build(
        queue: [photo()],
        existing: const AssignmentEvidence(
          assignmentId: _assignment,
          photoUrls: ['old_url'],
          storagePaths: ['old_path'],
        ),
      );
      await t.provider.load();
      await t.provider.pick(PhotoSource.camera);

      await t.provider.submit();

      final written = t.firestore.writes.single;
      expect(written.photoUrls.first, 'old_url');
      expect(written.storagePaths.first, 'old_path');
      expect(written.photoUrls, hasLength(2));
      expect(written.storagePaths, hasLength(2));
    });

    test('carries the assignment metadata the schema expects', () async {
      final t = build(queue: [photo()]);
      await t.provider.load();
      await t.provider.pick(PhotoSource.camera);

      await t.provider.submit();

      final map = t.firestore.writes.single.toMap();
      expect(map['luId'], _lu);
      expect(map['type'], 'UPLOAD');
      expect(map['contentType'], 'image/jpeg');
      expect(map['displayName'], 'Photo evidence');
    });

    test('a second concurrent submit is refused by the re-entry guard',
        () async {
      final t = build(queue: [photo()]);
      await t.provider.load();
      await t.provider.pick(PhotoSource.camera);

      // Both started before either awaits to completion.
      final first = t.provider.submit();
      final second = t.provider.submit();
      await Future.wait([first, second]);

      // One upload, one write. A missing guard here is a candidate cause of the
      // production anomaly where a removal appeared to trigger a second upload.
      expect(t.storage.uploaded, hasLength(1));
      expect(t.firestore.writes, hasLength(1));
    });

    test('submitting with nothing pending does nothing', () async {
      final t = build();
      await t.provider.load();

      await t.provider.submit();

      expect(t.storage.uploaded, isEmpty);
      expect(t.firestore.writes, isEmpty);
    });
  });

  group('when submit fails', () {
    test('a mid-batch upload failure leaves no orphans in Storage', () async {
      final t = build(queue: [photo(), photo(), photo()], failUploadAtIndex: 2);
      await t.provider.load();
      for (var i = 0; i < 3; i++) {
        await t.provider.pick(PhotoSource.camera);
      }

      await t.provider.submit();

      // The two that got through are unreferenced, so they are removed.
      expect(t.storage.uploaded, hasLength(2));
      expect(t.storage.deleted, equals(t.storage.uploaded));
      expect(t.firestore.writes, isEmpty);
    });

    test('the photos stay so the teacher can retry', () async {
      final t = build(queue: [photo(), photo()], failUploadAtIndex: 1);
      await t.provider.load();
      await t.provider.pick(PhotoSource.camera);
      await t.provider.pick(PhotoSource.camera);

      await t.provider.submit();

      expect(t.provider.pending, hasLength(2));
      expect(t.provider.errorKey, 'evidence.error_upload_failed');
    });

    test('a failing write also cleans up what was uploaded', () async {
      final t = build(queue: [photo()], throwsOnWrite: StateError('no write'));
      await t.provider.load();
      await t.provider.pick(PhotoSource.camera);

      await t.provider.submit();

      // Uploaded but never referenced, so it must not be left behind.
      expect(t.storage.deleted, hasLength(1));
      expect(t.provider.submitted, isEmpty);
      expect(t.provider.pending, hasLength(1));
    });

    test('a network failure reads as offline, not as a generic error',
        () async {
      final t = build(
        queue: [photo()],
        throwsOnWrite: TimeoutException('network unavailable'),
      );
      await t.provider.load();
      await t.provider.pick(PhotoSource.camera);

      await t.provider.submit();

      expect(t.provider.errorKey, 'evidence.error_offline');
      // Kept, so pressing submit again when back online is all it takes.
      expect(t.provider.pending, hasLength(1));
    });
  });

  group('removing an already-submitted photo', () {
    AssignmentEvidence three() => const AssignmentEvidence(
          assignmentId: _assignment,
          photoUrls: ['u0', 'u1', 'u2'],
          storagePaths: ['p0', 'p1', 'p2'],
        );

    test('rewrites Firestore BEFORE deleting the object', () async {
      final t = build(existing: three());
      await t.provider.load();

      await t.provider.removeSubmitted(1);

      final write = t.log.indexOf('writeEvidence');
      final delete = t.log.indexOf('delete:p1');
      expect(write, isNonNegative);
      expect(delete, isNonNegative);
      // The other order leaves a record pointing at a deleted object.
      expect(write, lessThan(delete));
    });

    test('drops exactly the right pair and stays aligned', () async {
      final t = build(existing: three());
      await t.provider.load();

      await t.provider.removeSubmitted(1);

      final written = t.firestore.writes.single;
      expect(written.photoUrls, ['u0', 'u2']);
      expect(written.storagePaths, ['p0', 'p2']);
      expect(written.isMisaligned, isFalse);
      expect(t.storage.deleted, ['p1']);
    });

    test('a failed Firestore write changes nothing and deletes nothing',
        () async {
      final t = build(existing: three(), throwsOnWrite: StateError('nope'));
      await t.provider.load();

      await t.provider.removeSubmitted(1);

      expect(t.storage.deleted, isEmpty);
      expect(t.provider.submitted, hasLength(3));
      expect(t.provider.errorKey, 'evidence.error_remove_failed');
    });

    test('a failed object delete still leaves the record correct', () async {
      final t = build(existing: three(), failDelete: true);
      await t.provider.load();

      await t.provider.removeSubmitted(0);

      // The record no longer references it, which is the recoverable side.
      expect(t.provider.submitted, hasLength(2));
      expect(t.provider.errorKey, isNull);
    });

    test('an out-of-range index is ignored', () async {
      final t = build(existing: three());
      await t.provider.load();

      await t.provider.removeSubmitted(99);

      expect(t.firestore.writes, isEmpty);
      expect(t.storage.deleted, isEmpty);
    });
  });

  group('reading what was already submitted', () {
    test('a misaligned record is truncated to the coherent pairs', () async {
      // A URL with no path cannot be deleted; a path with no URL cannot be
      // shown. Either means an earlier write did not finish.
      final t = build(
        existing: const AssignmentEvidence(
          assignmentId: _assignment,
          photoUrls: ['u0', 'u1', 'u2'],
          storagePaths: ['p0'],
        ),
      );
      await t.provider.load();

      expect(t.provider.submitted, hasLength(1));
      expect(t.provider.submitted.single.storagePath, 'p0');
    });

    test('a failed read surfaces as an error state', () async {
      final t = build(throwsOnFetch: StateError('denied'));

      await t.provider.load();

      expect(t.provider.status, EvidenceStatus.error);
      expect(t.provider.errorKey, 'evidence.error_load');
    });

    test('no existing document is the normal starting state', () async {
      final t = build();

      await t.provider.load();

      expect(t.provider.status, EvidenceStatus.ready);
      expect(t.provider.isEmpty, isTrue);
      expect(t.provider.remainingSlots, kMaxEvidencePhotos);
    });
  });
}
