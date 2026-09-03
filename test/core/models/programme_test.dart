import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/programme.dart';
import 'package:tc_starter/core/utils/parse_diagnostics.dart';

/// A `programmes/{id}` document with the field set every document in
/// `teacher-corner-dev` actually has — verified by dumping the field union
/// across all ten of them, not by sampling one.
Map<String, dynamic> programmeDoc() => {
  'age': <String>[],
  'assignmentIds': <String>[],
  'displayName': 'xyz',
  'docId': 'prg_alpha',
  'grades': ['4', '5', '6', '7', '8', '9'],
  'institutionId': 'inst_1',
  'institutionName': 'Sunrise Public School',
  'learningUnitsIds': <String>[],
  'ownerId': 'uid_admin_0001',
  'programmeCode': 'P10017',
  'programmeDescription': 'A short description, as stored.',
  'programmeId': 'prg_alpha',
  'programmeImagePath': '',
  'programmeName': 'xyz',
  'programmeStatus': 'LIVE',
  'type': 'REGULAR',
};

void main() {
  setUp(() {
    ParseDiagnostics.captured = <ParseDiagnosticRecord>[];
    ParseDiagnostics.reset();
  });

  tearDown(() {
    ParseDiagnostics.captured = null;
  });

  group('parsing a real document', () {
    test('reads every field the catalogue carries', () {
      final p = Programme.fromMap('prg_alpha', programmeDoc());

      expect(p.programmeId, 'prg_alpha');
      expect(p.displayName, 'xyz');
      expect(p.programmeName, 'xyz');
      expect(p.programmeCode, 'P10017');
      expect(p.description, 'A short description, as stored.');
      expect(p.institutionId, 'inst_1');
      expect(p.institutionName, 'Sunrise Public School');
      expect(p.grades, ['4', '5', '6', '7', '8', '9']);
      expect(p.ages, isEmpty);
      expect(p.type, 'REGULAR');
      expect(p.status, 'LIVE');
      expect(p.learningUnitIds, isEmpty);
      expect(p.assignmentIds, isEmpty);
      expect(p.isLive, isTrue);
      expect(p.isStemClub, isFalse);
    });

    test('the document id wins over the id fields inside', () {
      // programmeId and docId are mirrors of the path and can disagree with it.
      // The id a document was READ BY is the only one that cannot be wrong.
      final data = programmeDoc()
        ..['programmeId'] = 'WRONG'
        ..['docId'] = 'ALSO_WRONG';

      expect(Programme.fromMap('prg_alpha', data).programmeId, 'prg_alpha');
    });

    test('an empty image path is null, not the empty string', () {
      // Every live document stores ''. An empty path is not a path, and a
      // caller checking for null would otherwise try to resolve it.
      expect(Programme.fromMap('prg_alpha', programmeDoc()).imagePath, isNull);
    });

    test('a completely empty document still parses', () {
      // Not expected in this database, but a model that throws on a thin
      // document takes the screen down rather than degrading.
      final p = Programme.fromMap('prg_thin', const <String, dynamic>{});

      expect(p.programmeId, 'prg_thin');
      expect(p.label, 'prg_thin');
      expect(p.grades, isEmpty);
      expect(p.gradeRange, isNull);
      expect(p.isLive, isFalse);
    });
  });

  group('label resolution', () {
    test('prefers displayName over programmeName', () {
      // A live document is named "Stiles fun" and displays as "Funnn". The two
      // are genuinely different fields, not a fallback chain by accident.
      final data = programmeDoc()
        ..['displayName'] = 'Funnn'
        ..['programmeName'] = 'Stiles fun';

      expect(Programme.fromMap('prg_alpha', data).label, 'Funnn');
    });

    test('falls back to programmeName when displayName is blank', () {
      final data = programmeDoc()..['displayName'] = '   ';
      expect(Programme.fromMap('prg_alpha', data).label, 'xyz');
    });

    test('falls back to the id, never to the string "null"', () {
      final data = programmeDoc()
        ..remove('displayName')
        ..remove('programmeName');

      expect(Programme.fromMap('prg_alpha', data).label, 'prg_alpha');
    });
  });

  group('status is read defensively', () {
    test('only the literal LIVE is live', () {
      for (final status in ['DEVELOPEMENT', 'ARCHIVED', 'anything', '']) {
        final data = programmeDoc()..['programmeStatus'] = status;
        expect(
          Programme.fromMap('prg_alpha', data).isLive,
          isFalse,
          reason: '"$status" must not read as live',
        );
      }
    });

    test('case is ignored, so a lowercase live still counts', () {
      final data = programmeDoc()..['programmeStatus'] = 'live';
      expect(Programme.fromMap('prg_alpha', data).isLive, isTrue);
    });

    test('STEM-CLUB is recognised as its own type', () {
      final data = programmeDoc()..['type'] = 'STEM-CLUB';
      expect(Programme.fromMap('prg_alpha', data).isStemClub, isTrue);
    });
  });

  group('grades are stored expanded and summarised for display', () {
    test('a contiguous run collapses to a range', () {
      expect(Programme.fromMap('p', programmeDoc()).gradeRange, '4 - 9');
    });

    test('a run with gaps is listed, not misreported as a range', () {
      final data = programmeDoc()..['grades'] = ['4', '6', '9'];
      expect(Programme.fromMap('p', data).gradeRange, '4, 6, 9');
    });

    test('out-of-order values are sorted before summarising', () {
      final data = programmeDoc()..['grades'] = ['9', '7', '8'];
      expect(Programme.fromMap('p', data).gradeRange, '7 - 9');
    });

    test('a single grade is not rendered as a range', () {
      final data = programmeDoc()..['grades'] = ['5'];
      expect(Programme.fromMap('p', data).gradeRange, '5');
    });

    test('non-numeric grades are listed verbatim', () {
      // The same field holds '9' and 'Pre-primary 2' across the data, so a
      // numeric range cannot be assumed.
      final data = programmeDoc()
        ..['grades'] = ['Pre-primary 1', 'Pre-primary 2'];
      expect(
        Programme.fromMap('p', data).gradeRange,
        'Pre-primary 1, Pre-primary 2',
      );
    });

    test('no grades yields null, so the caller omits the line', () {
      final data = programmeDoc()..['grades'] = <String>[];
      expect(Programme.fromMap('p', data).gradeRange, isNull);
    });

    test('an age band is read when grades are empty', () {
      final data = programmeDoc()
        ..['grades'] = <String>[]
        ..['age'] = ['6', '7'];
      final p = Programme.fromMap('p', data);

      expect(p.gradeRange, isNull);
      expect(p.ageRange, '6, 7');
    });
  });

  /// `assignmentIds` is a MAP, and used not to be read as one.
  ///
  /// It was parsed with `asStringList`, which returns nothing for a map, so the
  /// field read as empty on every document and the model's own comment recorded
  /// that as a fact about the data. It was a fact about the parser: 2 of the 20
  /// programmes in this database carry the field, both as maps, and production has
  /// it on 2715 of 14240.

  group('assignmentIds', () {
    /// Shaped exactly as the live document `programmes/bfmwYr9cTpzXFIoWsQlY`.
    Map<String, dynamic> withAssignments() => {
      'programmeId': 'p1',
      'assignmentIds': {
        'BpZaZnFfbdJgp2Cx0Pdw': {
          'assignmentId': 'BpZaZnFfbdJgp2Cx0Pdw',
          'assignmentDueDate': Timestamp.fromDate(DateTime.utc(2026, 6, 3)),
        },
        'a4E9ffKLLduvnEj50W4X': {
          'assignmentId': 'a4E9ffKLLduvnEj50W4X',
          'assignmentDueDate': null,
        },
      },
    };

    test('reads the map, which the old list parser could not', () {
      final p = Programme.fromMap('p1', withAssignments());

      expect(p.assignmentIds, hasLength(2));
      expect(p.assignmentIds, contains('BpZaZnFfbdJgp2Cx0Pdw'));
    });

    test('carries the due date the programme set', () {
      final p = Programme.fromMap('p1', withAssignments());

      expect(p.assignments['BpZaZnFfbdJgp2Cx0Pdw'], DateTime.utc(2026, 6, 3));
      expect(p.assignments['a4E9ffKLLduvnEj50W4X'], isNull);
    });

    test('tolerates a plain array, reading ids with no date', () {
      // A hand-edited document, or production's --schema-- artefact.
      final p = Programme.fromMap('p1', {
        'programmeId': 'p1',
        'assignmentIds': ['x1', 'x2'],
      });

      expect(p.assignmentIds, ['x1', 'x2']);
      expect(p.assignments['x1'], isNull);
    });

    test('is empty when the field is absent, which most programmes are', () {
      final p = Programme.fromMap('p1', {'programmeId': 'p1'});

      expect(p.assignmentIds, isEmpty);
    });
  });
}
