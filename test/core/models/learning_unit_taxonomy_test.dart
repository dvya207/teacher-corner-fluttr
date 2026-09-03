import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/learning_unit.dart';
import 'package:tc_starter/core/models/learning_unit_taxonomy.dart';

/// The production rows these tests lean on, verified against
/// `thinktac-india-production/LearningUnits` rather than invented:
///
///   BO07  clean          domain B/Biology, sub-domain O/Other, subject S/Science
///   BA05  CONTRADICTS    code says B/A; the document stores subDomainCode 'E'
///   PL06  empty strings  domainCode '' and subDomainCode ''
///   FE05  absent         no domain fields on the document at all
void main() {
  setUp(LearningUnitTaxonomy.resetDefault);
  tearDown(LearningUnitTaxonomy.resetDefault);

  group('the static table', () {
    test('carries all 44 rows, one per letter pair', () {
      expect(kLearningUnitTaxonomy, hasLength(44));

      final pairs = kLearningUnitTaxonomy.map((r) => r.compositeCode).toSet();
      expect(
        pairs,
        hasLength(44),
        reason:
            'the pair is the lookup key, so a duplicate makes one row '
            'unreachable',
      );
    });

    test('every row is a single letter per code, as the lookup assumes', () {
      for (final row in kLearningUnitTaxonomy) {
        expect(row.domainCode, hasLength(1), reason: row.compositeCode);
        expect(row.subDomainCode, hasLength(1), reason: row.compositeCode);
        expect(row.subjectName, isNotEmpty, reason: row.compositeCode);
        expect(row.subDomainName, isNotEmpty, reason: row.compositeCode);
      }
    });

    test('SM is the one row with no domainName, and it is meant to be', () {
      // Production's Configuration/learningUnitDomains stores `domainName: ''`
      // for the pair SM. The web app copied it verbatim rather than inventing a
      // name, and so does this file. Pinned so that filling it in upstream
      // shows up here as a failing test rather than as a silent change.
      final blank = kLearningUnitTaxonomy
          .where((r) => r.domainName.trim().isEmpty)
          .toList();

      expect(blank, hasLength(1));
      expect(blank.single.compositeCode, 'SM');
      expect(blank.single.subDomainName, 'Motors');
    });
  });

  group('the code pattern', () {
    test('accepts two letters then two digits', () {
      for (final code in ['BO07', 'AE04', 'GH11', 'ZZ99']) {
        expect(kLearningUnitCodePattern.hasMatch(code), isTrue, reason: code);
      }
    });

    test('is anchored at BOTH ends', () {
      // The web app's pattern is unanchored at the start and leans on a
      // maxlength attribute. This one must not.
      for (final code in ['xxBO07', 'BO077', 'BO7', 'bo07', 'B007', '']) {
        expect(kLearningUnitCodePattern.hasMatch(code), isFalse, reason: code);
      }
    });
  });

  group('rowForCode', () {
    final taxonomy = LearningUnitTaxonomy.static_;

    test('reads the first two characters and ignores the digits', () {
      final a = taxonomy.rowForCode('BO07');
      final b = taxonomy.rowForCode('BO99');

      expect(a, isNotNull);
      expect(a!.domainName, 'Biology');
      expect(a.subDomainName, 'Other');
      expect(b?.compositeCode, a.compositeCode);
    });

    test('trims and upper-cases before looking up', () {
      expect(taxonomy.rowForCode('  bo07 ')?.domainName, 'Biology');
    });

    test('returns null for a malformed code', () {
      for (final code in [null, '', 'B07', 'BOO7', 'nonsense']) {
        expect(taxonomy.rowForCode(code), isNull, reason: '$code');
      }
    });

    test('returns null for a well-formed code with no row', () {
      // Well-formed, but no row defines the pair QQ.
      expect(kLearningUnitCodePattern.hasMatch('QQ01'), isTrue);
      expect(taxonomy.rowForCode('QQ01'), isNull);
    });
  });

  group('resolve derives from the code first', () {
    final taxonomy = LearningUnitTaxonomy.static_;

    test('BA05: the code beats a contradicting stored field', () {
      // This is the case the whole class exists for.
      final result = taxonomy.resolve(
        code: 'BA05',
        storedDomainCode: 'B',
        storedSubDomainCode: 'E',
        storedSubDomainName: 'Ecosystem',
      );

      expect(result.source, CategorisationSource.derived);
      expect(result.subDomainCode, 'A', reason: 'the code says A, not E');
      expect(result.subDomainName, 'Animal');
      expect(result.domainName, 'Biology');
      expect(result.compositeCode, 'BA');
    });

    test('BO07: a clean row resolves to the full categorisation', () {
      final result = taxonomy.resolve(code: 'BO07');

      expect(result.source, CategorisationSource.derived);
      expect(result.subjectCode, 'S');
      expect(result.subjectName, 'Science');
      expect(result.domainCode, 'B');
      expect(result.domainName, 'Biology');
      expect(result.subDomainCode, 'O');
      expect(result.subDomainName, 'Other');
    });

    test('a good code needs no stored fields at all', () {
      final result = taxonomy.resolve(code: 'AE04');

      expect(result.source, CategorisationSource.derived);
      expect(result.domainName, 'Algebra');
      expect(result.subDomainName, 'Equations');
      expect(result.subjectName, 'Mathematics');
    });
  });

  group('resolve and the SM hole in the table', () {
    final taxonomy = LearningUnitTaxonomy.static_;

    test('a blank cell in a matched row defers to the stored name', () {
      final result = taxonomy.resolve(
        code: 'SM01',
        storedDomainName: 'Simple Machines',
      );

      expect(result.source, CategorisationSource.derived);
      expect(result.subDomainName, 'Motors', reason: 'the row has this');
      expect(
        result.domainName,
        'Simple Machines',
        reason: 'the row does NOT, so the document must fill it',
      );
    });

    test('the codes still come from the row, never from the document', () {
      final result = taxonomy.resolve(
        code: 'SM01',
        storedDomainCode: 'X',
        storedSubDomainCode: 'Y',
      );

      expect(result.domainCode, 'S');
      expect(result.subDomainCode, 'M');
      expect(result.domainName, isNull, reason: 'nothing to fall back on');
    });
  });

  group('resolve falls back when the code cannot carry it', () {
    final taxonomy = LearningUnitTaxonomy.static_;

    test('no code at all: the stored names come through', () {
      final result = taxonomy.resolve(
        storedSubjectName: 'Science',
        storedDomainName: 'Biology',
      );

      expect(result.source, CategorisationSource.stored);
      expect(result.subjectName, 'Science');
      expect(result.domainName, 'Biology');
    });

    test('PL06-style empty strings are treated as absent, not as values', () {
      final result = taxonomy.resolve(
        code: '   ',
        storedDomainCode: '',
        storedDomainName: '   ',
        storedSubjectName: 'Science',
      );

      expect(result.domainCode, isNull);
      expect(result.domainName, isNull);
      expect(result.subjectName, 'Science');
    });

    test('FE05-style absent everything resolves to unknown', () {
      final result = taxonomy.resolve(code: null);

      expect(result.source, CategorisationSource.none);
      expect(result.isKnown, isFalse);
      expect(result.domainName, isNull);
      expect(result.compositeCode, isNull);
    });

    test('an unknown pair still yields its own two letters', () {
      // QQ01 is well-formed but has no row. The letters are still better
      // evidence than a stored field that may contradict them.
      final result = taxonomy.resolve(
        code: 'QQ01',
        storedDomainCode: 'Z',
        storedDomainName: 'Whatever',
      );

      expect(result.source, CategorisationSource.stored);
      expect(result.domainCode, 'Q');
      expect(result.subDomainCode, 'Q');
      // The NAME is not derivable, so the stored one is all there is.
      expect(result.domainName, 'Whatever');
    });
  });

  group('TaxonomyRow.fromMap', () {
    test('accepts the seeded document\'s lowercase subdomainName', () {
      // Verified against Configuration/learningUnitDomains: the name is
      // spelled subdomainName while the code beside it is subDomainCode.
      final row = TaxonomyRow.fromMap(const {
        'compositeCode': 'AE',
        'domainCode': 'A',
        'domainName': 'Algebra',
        'subDomainCode': 'E',
        'subdomainName': 'Equations',
        'subjectCode': 'M',
        'subjectName': 'Mathematics',
      });

      expect(row.subDomainName, 'Equations');
      expect(row.compositeCode, 'AE');
    });

    test('accepts the camelCase spelling too', () {
      final row = TaxonomyRow.fromMap(const {
        'domainCode': 'A',
        'subDomainCode': 'E',
        'subDomainName': 'Equations',
      });

      expect(row.subDomainName, 'Equations');
    });
  });

  group('replaceDefault', () {
    test('a console edit wins over the static rows', () {
      final installed = LearningUnitTaxonomy.replaceDefault([
        const TaxonomyRow(
          subjectCode: 'S',
          subjectName: 'Science',
          domainCode: 'B',
          domainName: 'Life Sciences',
          subDomainCode: 'O',
          subDomainName: 'Other',
        ),
      ]);

      expect(installed, isTrue);
      expect(
        LearningUnitTaxonomy.instance.rowForCode('BO07')?.domainName,
        'Life Sciences',
      );
    });

    test('an empty read is IGNORED rather than installed', () {
      expect(LearningUnitTaxonomy.replaceDefault(const []), isFalse);
      expect(LearningUnitTaxonomy.instance.rows, hasLength(44));
    });

    test('rows without a letter pair are dropped, and an all-blank read is '
        'refused', () {
      const blank = TaxonomyRow(
        subjectCode: 'S',
        subjectName: 'Science',
        domainCode: '',
        domainName: 'Biology',
        subDomainCode: '',
        subDomainName: 'Other',
      );

      expect(LearningUnitTaxonomy.replaceDefault(const [blank]), isFalse);
      expect(LearningUnitTaxonomy.instance.rows, hasLength(44));
    });
  });

  group('LearningUnit.categorisation', () {
    test('derives from the document\'s learningUnitCode', () {
      final lu = LearningUnit.fromMap('00HfMpdwnJ7UMark0B7b', const {
        'learningUnitDisplayName': 'Magnetic Pen Stand',
        'learningUnitCode': 'BO07',
      });

      expect(lu.learningUnitCode, 'BO07');
      expect(lu.categorisation.domainName, 'Biology');
      expect(lu.resolvedSubjectName, 'Science');
    });

    test('the BA05 document does not get to report the wrong sub-domain', () {
      final lu = LearningUnit.fromMap('someAutoId', const {
        'learningUnitCode': 'BA05',
        'subDomainCode': 'E',
        'subdomainName': 'Ecosystem',
        'subjectName': 'Science',
      });

      expect(lu.subDomainCode, 'E', reason: 'the raw field is still readable');
      expect(lu.categorisation.subDomainCode, 'A');
      expect(lu.categorisation.subDomainName, 'Animal');
    });

    test('a document with no code falls back to its stored subject', () {
      final lu = LearningUnit.fromMap('someAutoId', const {
        'subjectName': 'Toys and Tales',
      });

      expect(lu.categorisation.source, CategorisationSource.stored);
      expect(lu.resolvedSubjectName, 'Toys and Tales');
    });

    test('picks up a Firestore override installed after parsing', () {
      final lu = LearningUnit.fromMap('someAutoId', const {
        'learningUnitCode': 'BO07',
      });
      expect(lu.categorisation.domainName, 'Biology');

      LearningUnitTaxonomy.replaceDefault([
        const TaxonomyRow(
          subjectCode: 'S',
          subjectName: 'Science',
          domainCode: 'B',
          domainName: 'Life Sciences',
          subDomainCode: 'O',
          subDomainName: 'Other',
        ),
      ]);

      expect(lu.categorisation.domainName, 'Life Sciences');
    });
  });
}
