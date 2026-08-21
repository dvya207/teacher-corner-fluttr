import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/assignment_evidence.dart';
import 'package:tc_starter/core/services/evidence_storage.dart';
import 'package:tc_starter/core/services/photo_picker.dart';
import 'package:tc_starter/features/evidence/evidence_panel.dart';
import 'package:tc_starter/features/evidence/evidence_provider.dart';
import 'package:tc_starter/features/evidence/widgets/evidence_thumbnail.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _NoopStorage implements EvidenceStorage {
  final List<String> uploaded = [];

  @override
  Future<String> upload({
    required String storagePath,
    required File file,
    String contentType = 'image/jpeg',
  }) async {
    uploaded.add(storagePath);
    return 'https://example/$storagePath?token=1';
  }

  @override
  Future<void> delete(String storagePath) async {}
}

class _QueuePicker implements PhotoPicker {
  _QueuePicker(this.queue);
  final List<PickedPhoto?> queue;
  int calls = 0;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    calls++;
    return queue.isEmpty ? null : queue.removeAt(0);
  }
}

void main() {
  setUp(initLocalizationForTest);

  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('tc_panel'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  var seq = 0;
  PickedPhoto photo({int bytes = 1024}) {
    final file = File('${tempDir.path}/p${seq++}.jpg')..writeAsBytesSync(_png);
    return PickedPhoto(file: file, sizeBytes: bytes);
  }

  Future<EvidenceProvider> pumpPanel(
    WidgetTester tester, {
    List<PickedPhoto?> queue = const [],
    AssignmentEvidence? existing,
    Size surfaceSize = const Size(360, 800),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    final provider = EvidenceProvider(
      firestore: FakeFirestoreService(evidence: existing),
      storage: _NoopStorage(),
      picker: _QueuePicker(List.of(queue)),
      uid: 'uid_teacher',
      classroomId: 'cls_oak_7a',
      programmeId: 'prog_tip_2026',
      learningUnitId: 'lu_magnetic_pen_stand',
      assignmentId: 'asg_mps_evidence',
      displayName: 'Photo evidence',
      clock: () => 1787132584464,
    );
    await pumpScreen(
      tester,
      surfaceSize: surfaceSize,
      textScaler: textScaler,
      providers: [
        ChangeNotifierProvider<EvidenceProvider>.value(value: provider),
      ],
      child: const EvidencePanel(),
    );
    return provider;
  }

  group('the limit is stated before it is hit', () {
    testWidgets('shows the photo and size caps on arrival', (tester) async {
      await pumpPanel(tester);

      expect(
        find.text('You can add up to 3 photos, 3 MB each.'),
        findsOneWidget,
      );
      expect(find.text('0 of 3 added'), findsOneWidget);
    });

    testWidgets('the counter tracks what has been added', (tester) async {
      final provider = await pumpPanel(tester, queue: [photo()]);

      await provider.pick(PhotoSource.camera);
      await tester.pumpAndSettle();

      expect(find.text('1 of 3 added'), findsOneWidget);
    });
  });

  group('both sources are always offered', () {
    testWidgets('camera and gallery are both present', (tester) async {
      await pumpPanel(tester);

      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
    });

    testWidgets('both are disabled once three photos are held', (tester) async {
      final provider = await pumpPanel(
        tester,
        existing: const AssignmentEvidence(
          assignmentId: 'asg_mps_evidence',
          photoUrls: ['u0', 'u1', 'u2'],
          storagePaths: ['p0', 'p1', 'p2'],
        ),
      );
      await tester.pumpAndSettle();

      expect(provider.remainingSlots, 0);
      // Disabled rather than inviting a photo that would be refused.
      for (final label in ['Camera', 'Gallery']) {
        final button = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(button.onPressed, isNull, reason: '$label was still enabled');
      }
    });
  });

  group('pick then review then submit', () {
    testWidgets('an empty state until something is added', (tester) async {
      await pumpPanel(tester);

      expect(find.text('No photos yet'), findsOneWidget);
      expect(find.textContaining('Submit'), findsNothing);
    });

    testWidgets('a pick shows a thumbnail and says it is not uploaded',
        (tester) async {
      final provider = await pumpPanel(tester, queue: [photo()]);

      await provider.pick(PhotoSource.camera);
      await tester.pumpAndSettle();

      expect(find.byType(EvidenceThumbnail), findsOneWidget);
      // TcSectionLabel upper-cases its label.
      expect(find.text('READY TO SUBMIT'), findsOneWidget);
      expect(
        find.text('Not uploaded yet. Nothing is sent until you press Submit.'),
        findsOneWidget,
      );
    });

    testWidgets('the submit label counts the photos', (tester) async {
      final provider = await pumpPanel(tester, queue: [photo(), photo()]);

      await provider.pick(PhotoSource.camera);
      await tester.pumpAndSettle();
      expect(find.text('Submit 1 photo'), findsOneWidget);

      await provider.pick(PhotoSource.gallery);
      await tester.pumpAndSettle();
      expect(find.text('Submit 2 photos'), findsOneWidget);
    });

    testWidgets('a pending photo can be removed before submitting',
        (tester) async {
      final provider = await pumpPanel(tester, queue: [photo()]);
      await provider.pick(PhotoSource.camera);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(EvidenceThumbnail), findsNothing);
      expect(find.text('No photos yet'), findsOneWidget);
    });

    testWidgets('submitting moves the photo into the submitted section',
        (tester) async {
      final provider = await pumpPanel(tester, queue: [photo()]);
      await provider.pick(PhotoSource.camera);
      await tester.pumpAndSettle();

      await provider.submit();
      await tester.pumpAndSettle();

      expect(find.text('SUBMITTED'), findsOneWidget);
      expect(find.text('READY TO SUBMIT'), findsNothing);
      expect(provider.submitted, hasLength(1));
    });
  });

  group('errors', () {
    testWidgets('an oversized photo is explained, with the cap named',
        (tester) async {
      final provider = await pumpPanel(
        tester,
        queue: [photo(bytes: kMaxEvidenceBytes + 1)],
      );

      await provider.pick(PhotoSource.camera);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('larger than 3 MB'),
        findsOneWidget,
      );
      expect(find.byType(EvidenceThumbnail), findsNothing);
    });
  });

  group('surviving the device', () {
    testWidgets('does not overflow in landscape', (tester) async {
      final provider = await pumpPanel(
        tester,
        queue: [photo()],
        surfaceSize: const Size(800, 360),
      );
      await provider.pick(PhotoSource.camera);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at the clamped maximum font size',
        (tester) async {
      final provider = await pumpPanel(
        tester,
        queue: [photo()],
        textScaler: const TextScaler.linear(3.0),
      );
      await provider.pick(PhotoSource.camera);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('submitted thumbnails', () {
    testWidgets('render by Storage PATH, not by the stored URL',
        (tester) async {
      await pumpPanel(
        tester,
        existing: const AssignmentEvidence(
          assignmentId: 'asg_mps_evidence',
          photoUrls: ['https://example/p0?token=stale'],
          storagePaths: ['activityEvidence/cls/lu/uid_1_0.jpg'],
        ),
      );
      await tester.pumpAndSettle();

      final thumb = tester.widget<EvidenceThumbnail>(
        find.byType(EvidenceThumbnail),
      );
      // The path is the stable identity; the URL carries a token and is not.
      expect(thumb.storagePath, 'activityEvidence/cls/lu/uid_1_0.jpg');
      expect(thumb.file, isNull);
    });
  });
}
