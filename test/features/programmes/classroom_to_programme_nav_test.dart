import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/programme.dart';
import 'package:tc_starter/core/services/firestore_service.dart';
import 'package:tc_starter/core/theme/app_theme.dart';
import 'package:tc_starter/features/classrooms/classroom_detail_provider.dart';
import 'package:tc_starter/features/classrooms/classroom_detail_screen.dart';
import 'package:tc_starter/features/programmes/programme_detail_provider.dart';
import 'package:tc_starter/features/programmes/programme_detail_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

/// Classroom detail -> programme detail, driven through a REAL GoRouter.
///
/// The route is exercised rather than the callback: the thing most likely to
/// break is the path string, and a test that calls `onTap` directly would pass
/// with a route that does not exist.

const String kClassroomId = 'cls_test_0001';
const String kProgrammeAlpha = 'prg_alpha_0001';
const String kProgrammeBeta = 'prg_beta_0002';

/// A classroom running two programmes, with no `workflowIds` — which is the
/// shape every real classroom in `teacher-corner-dev` has.
Classroom classroomWithTwoProgrammes() => Classroom.fromMap(kClassroomId, {
  'classroomName': '9 B',
  'type': 'CLASSROOM',
  'grade': '9',
  'section': 'B',
  'board': 'CBSE',
  'institutionName': 'Sunrise Public School',
  'studentCounter': 0,
  'programmes': {
    kProgrammeAlpha: {'displayName': 'Alpha'},
    kProgrammeBeta: {'displayName': 'Beta'},
  },
});

Programme programmeDoc(
  String id, {
  required String name,
  required String code,
  String? description,
  List<String> grades = const ['4', '5', '6'],
  String status = 'LIVE',
  String type = 'REGULAR',
}) =>
    Programme.fromMap(id, {
      'displayName': name,
      'programmeName': name,
      'programmeCode': code,
      'programmeDescription': description ?? 'About $name.',
      'institutionName': 'Sunrise Public School',
      'grades': grades,
      'age': <String>[],
      'learningUnitsIds': <String>[],
      'assignmentIds': <String>[],
      'programmeStatus': status,
      'type': type,
      'programmeImagePath': '',
    });

FakeFirestoreService firestoreWith({List<Programme>? programmes}) =>
    FakeFirestoreService(
      classrooms: [classroomWithTwoProgrammes()],
      programmes: programmes ??
          [
            programmeDoc(kProgrammeAlpha, name: 'Alpha', code: 'P10001'),
            programmeDoc(kProgrammeBeta, name: 'Beta', code: 'P10002'),
          ],
    );

/// The same route shape `AppRouter` declares: the programme nested under the
/// classroom, so back returns to the classroom.
Future<void> pumpFlow(
  WidgetTester tester, {
  required FirestoreService firestore,
}) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final router = GoRouter(
    initialLocation: '/classrooms/$kClassroomId',
    routes: [
      GoRoute(
        path: '/classrooms/:id',
        builder: (context, state) => ChangeNotifierProvider<
            ClassroomDetailProvider>(
          create: (ctx) =>
              ClassroomDetailProvider(firestore: ctx.read<FirestoreService>()),
          child: ClassroomDetailScreen(
            classroomId: state.pathParameters['id']!,
          ),
        ),
        routes: [
          GoRoute(
            path: 'programmes/:programmeId',
            builder: (context, state) => ChangeNotifierProvider<
                ProgrammeDetailProvider>(
              create: (ctx) => ProgrammeDetailProvider(
                firestore: ctx.read<FirestoreService>(),
              ),
              child: ProgrammeDetailScreen(
                programmeId: state.pathParameters['programmeId']!,
                classroomName: state.uri.queryParameters['classroomName'],
              ),
            ),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    Provider<FirestoreService>.value(
      value: firestore,
      child: ScreenUtilInit(
        designSize: const Size(360, 800),
        minTextAdapt: true,
        fontSizeResolver: FontSizeResolvers.width,
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps the header's own back control.
///
/// NOT `tester.pageBack()`: that hunts for a Material or Cupertino AppBar back
/// button, and these screens use the back affordance inside [TcHeroHeader]. The
/// helper exercises the control a teacher actually taps.
Future<void> tapHeaderBack(WidgetTester tester) async {
  final back = find.byIcon(Icons.arrow_back_rounded);
  expect(back, findsOneWidget, reason: 'no header back control on screen');
  await tester.tap(back);
  await tester.pumpAndSettle();
}

void main() {
  setUp(initLocalizationForTest);

  group('the classroom lists its programmes as tappable rows', () {
    testWidgets('both programmes are shown', (tester) async {
      await pumpFlow(tester, firestore: firestoreWith());

      expect(find.text('9 B'), findsWidgets);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('no empty-activities banner is rendered', (tester) async {
      // learningUnits has no documents and workflows does not exist, so every
      // programme would otherwise carry an identical "nothing here" line.
      await pumpFlow(tester, firestore: firestoreWith());

      expect(find.textContaining('activities'), findsNothing);
    });
  });

  group('tapping a programme opens its details', () {
    testWidgets('the alpha programme resolves through the route',
        (tester) async {
      final firestore = firestoreWith();
      await pumpFlow(tester, firestore: firestore);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      // The catalogue document was read, by the id the classroom named.
      expect(firestore.requestedProgrammeIds, [kProgrammeAlpha]);
      // Fields that exist ONLY on the catalogue document, so their presence
      // proves the detail screen is rendering the real read.
      expect(find.text('P10001'), findsOneWidget);
      expect(find.text('About Alpha.'), findsOneWidget);
      expect(find.text('4 - 6'), findsOneWidget);
    });

    testWidgets('the classroom name travels through as a breadcrumb',
        (tester) async {
      await pumpFlow(tester, firestore: firestoreWith());

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      // Passed in the query string rather than re-read: a round trip for one
      // line of text would be wasteful.
      expect(find.text('9 B'), findsWidgets);
      expect(find.text('P10002'), findsOneWidget);
    });

    testWidgets('each programme opens its own details, not the other\'s',
        (tester) async {
      final firestore = firestoreWith();
      await pumpFlow(tester, firestore: firestore);

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(find.text('P10002'), findsOneWidget);
      expect(find.text('P10001'), findsNothing);

      // Back to the classroom, then into the other one.
      await tapHeaderBack(tester);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('P10001'), findsOneWidget);
      expect(find.text('P10002'), findsNothing);

      expect(firestore.requestedProgrammeIds, [kProgrammeBeta, kProgrammeAlpha]);
    });

    testWidgets('back returns to the classroom, not to the list',
        (tester) async {
      await pumpFlow(tester, firestore: firestoreWith());

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('P10001'), findsOneWidget);

      await tapHeaderBack(tester);

      // Both programmes visible again means we are on the classroom screen.
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });
  });

  group('the detail screen shows only what the document holds', () {
    testWidgets('a draft programme reads as a draft', (tester) async {
      await pumpFlow(
        tester,
        firestore: firestoreWith(programmes: [
          programmeDoc(
            kProgrammeAlpha,
            name: 'Alpha',
            code: 'P10001',
            status: 'DEVELOPEMENT',
          ),
          programmeDoc(kProgrammeBeta, name: 'Beta', code: 'P10002'),
        ]),
      );

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Live'), findsNothing);
    });

    testWidgets('a STEM club programme is labelled as one', (tester) async {
      await pumpFlow(
        tester,
        firestore: firestoreWith(programmes: [
          programmeDoc(
            kProgrammeAlpha,
            name: 'Alpha',
            code: 'P10001',
            type: 'STEM-CLUB',
            grades: const [],
          ),
          programmeDoc(kProgrammeBeta, name: 'Beta', code: 'P10002'),
        ]),
      );

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(find.text('STEM Club programme'), findsOneWidget);
      // No grades stored, so no grades line at all rather than an empty one.
      expect(find.text('Grades'), findsNothing);
    });

    testWidgets('it says so when a programme has no learning units',
        (tester) async {
      await pumpFlow(tester, firestore: firestoreWith());

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No learning units have been added'),
        findsOneWidget,
      );
    });

    testWidgets('a programme the catalogue no longer has is not-found',
        (tester) async {
      // The classroom still names both, but only Beta exists.
      await pumpFlow(
        tester,
        firestore: firestoreWith(
          programmes: [programmeDoc(kProgrammeBeta, name: 'Beta', code: 'P10002')],
        ),
      );

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(find.text('Programme not available'), findsOneWidget);
      // Not an error, so no Retry.
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a failed read offers a Retry', (tester) async {
      await pumpFlow(
        tester,
        firestore: FakeFirestoreService(
          classrooms: [classroomWithTwoProgrammes()],
          throwsOnProgramme: StateError('boom'),
        ),
      );

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load this programme'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
