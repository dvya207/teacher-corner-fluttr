import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/programme.dart';
import 'package:tc_starter/features/programmes/programme_detail_provider.dart';

import '../../support/fakes.dart';

Programme programme(String id, {String name = 'Alpha', String? code}) =>
    Programme.fromMap(id, {
      'displayName': name,
      'programmeName': name,
      'programmeCode': code ?? 'P10001',
      'programmeDescription': 'Description for $name.',
      'institutionName': 'Sunrise Public School',
      'grades': ['4', '5', '6'],
      'age': <String>[],
      'learningUnitsIds': <String>[],
      'assignmentIds': <String>[],
      'programmeStatus': 'LIVE',
      'type': 'REGULAR',
      'programmeImagePath': '',
    });

void main() {
  test('starts in loading, before anything has been asked for', () {
    final provider = ProgrammeDetailProvider(firestore: FakeFirestoreService());

    expect(provider.status, ProgrammeDetailStatus.loading);
    expect(provider.programme, isNull);
  });

  test('a successful load exposes the programme', () async {
    final firestore = FakeFirestoreService(programmes: [programme('prg_a')]);
    final provider = ProgrammeDetailProvider(firestore: firestore);

    await provider.load('prg_a');

    expect(provider.status, ProgrammeDetailStatus.loaded);
    expect(provider.programme!.label, 'Alpha');
    expect(provider.programme!.programmeCode, 'P10001');
    expect(provider.errorKey, isNull);
    expect(firestore.requestedProgrammeIds, ['prg_a']);
  });

  test('a missing document is notFound, not an error', () async {
    // A classroom can name a programme whose catalogue entry has been removed.
    // Retry cannot fix that, so it must not present as a failure.
    final firestore = FakeFirestoreService(programmes: [programme('prg_a')]);
    final provider = ProgrammeDetailProvider(firestore: firestore);

    await provider.load('prg_gone');

    expect(provider.status, ProgrammeDetailStatus.notFound);
    expect(provider.programme, isNull);
    expect(provider.errorKey, isNull);
  });

  test('a thrown read becomes the error state with a generic key', () async {
    final provider = ProgrammeDetailProvider(
      firestore: FakeFirestoreService(throwsOnProgramme: StateError('boom')),
    );

    await provider.load('prg_a');

    expect(provider.status, ProgrammeDetailStatus.error);
    expect(provider.errorKey, 'programme.error_generic');
  });

  test('a read that never answers times out instead of spinning', () async {
    final gate = Completer<void>();
    final provider = ProgrammeDetailProvider(
      firestore: FakeFirestoreService(
        programmes: [programme('prg_a')],
        gate: gate,
      ),
      timeout: const Duration(milliseconds: 40),
    );

    await provider.load('prg_a');

    expect(provider.status, ProgrammeDetailStatus.error);
    expect(provider.errorKey, 'programme.error_offline');

    gate.complete();
  });

  test('loading the same id twice reads once', () async {
    final firestore = FakeFirestoreService(programmes: [programme('prg_a')]);
    final provider = ProgrammeDetailProvider(firestore: firestore);

    await provider.load('prg_a');
    await provider.load('prg_a');

    expect(firestore.programmeReads, 1);
  });

  test('retry refetches, unlike load', () async {
    final firestore = FakeFirestoreService(programmes: [programme('prg_a')]);
    final provider = ProgrammeDetailProvider(firestore: firestore);

    await provider.load('prg_a');
    await provider.retry();

    expect(firestore.programmeReads, 2);
  });

  test('retry before any load does nothing', () async {
    final firestore = FakeFirestoreService(programmes: [programme('prg_a')]);
    final provider = ProgrammeDetailProvider(firestore: firestore);

    await provider.retry();

    expect(firestore.programmeReads, 0);
  });

  test('a second programme replaces the first, with no bleed-through',
      () async {
    final firestore = FakeFirestoreService(
      programmes: [
        programme('prg_a', name: 'Alpha', code: 'P10001'),
        programme('prg_b', name: 'Beta', code: 'P10002'),
      ],
    );
    final provider = ProgrammeDetailProvider(firestore: firestore);

    await provider.load('prg_a');
    expect(provider.programme!.label, 'Alpha');

    // The old programme is dropped SYNCHRONOUSLY, before the new read resolves,
    // so no frame shows Alpha's details under Beta's heading.
    final pending = provider.load('prg_b');
    expect(provider.programme, isNull);
    expect(provider.status, ProgrammeDetailStatus.loading);

    await pending;
    expect(provider.programme!.label, 'Beta');
    expect(provider.programme!.programmeCode, 'P10002');
  });
}
