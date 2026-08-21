import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/services/firestore_service.dart';
import 'package:tc_starter/features/dashboard/dashboard_provider.dart';

/// Overrides the one read the dashboard makes. The real [FirestoreService]
/// resolves its Firestore handle lazily, so constructing this never touches
/// Firebase.
class _FakeFirestoreService extends FirestoreService {
  _FakeFirestoreService({this.teacher, this.throws, this.gate});

  final Teacher? teacher;
  final Object? throws;

  /// When set, the fetch does not complete until the test completes this.
  final Completer<void>? gate;

  int callCount = 0;
  final List<String> requestedUids = [];

  @override
  Future<Teacher?> fetchTeacher(String uid) async {
    callCount++;
    requestedUids.add(uid);
    if (gate != null) await gate!.future;
    if (throws != null) throw throws!;
    return teacher;
  }
}

Teacher aTeacher() => Teacher.fromMap('uid_1', {
      'teacherMeta': {
        'firstName': 'Divya',
        'lastName': 'Jain',
        'institutionName': 'Test School Oak',
      },
      'classrooms': {
        'cls_oak_7a': {
          'programmes': {'prog_tip_2026': <String, dynamic>{}},
        },
        'cls_oak_et': {
          'programmes': {'prog_tip_2026': <String, dynamic>{}},
        },
      },
    });

void main() {
  test('starts in loading, before anything has been asked for', () {
    final provider = DashboardProvider(firestore: _FakeFirestoreService());
    expect(provider.status, DashboardStatus.loading);
    expect(provider.teacher, isNull);
  });

  test('a successful load exposes the teacher and the counts', () async {
    final provider = DashboardProvider(
      firestore: _FakeFirestoreService(teacher: aTeacher()),
    );

    await provider.load('uid_1');

    expect(provider.status, DashboardStatus.loaded);
    expect(provider.teacher!.displayName, 'Divya Jain');
    expect(provider.teacher!.classroomCount, 2);
    // Both classrooms share one programme.
    expect(provider.teacher!.programmeCount, 1);
    expect(provider.errorKey, isNull);
  });

  test('a missing teacher document is loaded-with-no-profile, not an error',
      () async {
    final provider = DashboardProvider(
      firestore: _FakeFirestoreService(),
    );

    await provider.load('uid_1');

    // Signed in, nothing provisioned. Retrying cannot fix it, so it must not
    // present as a failure.
    expect(provider.status, DashboardStatus.loaded);
    expect(provider.hasNoProfile, isTrue);
  });

  test('a thrown read becomes the error state with a generic key', () async {
    final provider = DashboardProvider(
      firestore: _FakeFirestoreService(throws: StateError('boom')),
    );

    await provider.load('uid_1');

    expect(provider.status, DashboardStatus.error);
    expect(provider.errorKey, 'dashboard.error_generic');
    expect(provider.hasNoProfile, isFalse);
  });

  test('a read that never answers times out instead of spinning forever',
      () async {
    // The acceptance check for this phase: wifi off must produce the error
    // state, never a spinner that never stops.
    final gate = Completer<void>();
    final provider = DashboardProvider(
      firestore: _FakeFirestoreService(gate: gate),
      timeout: const Duration(milliseconds: 20),
    );

    await provider.load('uid_1');

    expect(provider.status, DashboardStatus.error);
    expect(provider.errorKey, 'dashboard.error_offline');
    gate.complete();
  });

  group('not refetching needlessly', () {
    test('loading the same uid twice reads once', () async {
      final fake = _FakeFirestoreService(teacher: aTeacher());
      final provider = DashboardProvider(firestore: fake);

      await provider.load('uid_1');
      await provider.load('uid_1');

      // The screen's initState fires on every navigation back to the tab.
      expect(fake.callCount, 1);
    });

    test('a different uid does refetch', () async {
      final fake = _FakeFirestoreService(teacher: aTeacher());
      final provider = DashboardProvider(firestore: fake);

      await provider.load('uid_1');
      await provider.load('uid_2');

      expect(fake.callCount, 2);
      expect(fake.requestedUids, ['uid_1', 'uid_2']);
    });

    test('load retries after a failure', () async {
      final fake = _FakeFirestoreService(throws: StateError('boom'));
      final provider = DashboardProvider(firestore: fake);

      await provider.load('uid_1');
      await provider.load('uid_1');

      // Same uid, but the last attempt failed, so asking again must try again.
      expect(fake.callCount, 2);
    });
  });

  group('retry', () {
    test('always refetches, even after a success', () async {
      final fake = _FakeFirestoreService(teacher: aTeacher());
      final provider = DashboardProvider(firestore: fake);

      await provider.load('uid_1');
      await provider.retry();

      expect(fake.callCount, 2);
    });

    test('does nothing before any uid is known', () async {
      final fake = _FakeFirestoreService(teacher: aTeacher());
      final provider = DashboardProvider(firestore: fake);

      await provider.retry();

      expect(fake.callCount, 0);
    });

    test('repeated taps while a read is in flight start only one read',
        () async {
      // Retry is a button a frustrated teacher taps repeatedly.
      final gate = Completer<void>();
      final fake = _FakeFirestoreService(teacher: aTeacher(), gate: gate);
      final provider = DashboardProvider(firestore: fake);

      final first = provider.load('uid_1');
      final second = provider.retry();
      final third = provider.retry();

      gate.complete();
      await Future.wait([first, second, third]);

      expect(fake.callCount, 1);
    });
  });
}
