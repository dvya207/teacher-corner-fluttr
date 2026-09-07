import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/learning_unit.dart';
import 'package:tc_starter/core/models/resource_kind.dart';
import 'package:tc_starter/core/models/workflow.dart';

/// A unit's `resources` map holds two unrelated kinds of value, and this file
/// is about telling them apart.
///
/// Everything here is copied out of `learningUnits/2awVLuyYaxFqMFuVp3Ny`
/// (Sterling Point) and the workflow bound to it,
/// `workflows/xHcyOmsSYLmyNT7QJxRv`, in teacher-corner-dev. That is the
/// activity in the screenshots where six tabs read "no content attached yet"
/// while every one of these files was uploaded.
LearningUnit sterlingPoint() => LearningUnit.fromMap('2awVLuyYaxFqMFuVp3Ny', {
  'learningUnitDisplayName': 'Sterling Point',
  'Maturity': 'Gold',
  'resources': {
    // Store one's pointer: a DOCUMENT ID, not a file.
    'gold': '1eXvhUXV7stAgLMV8BA0',
    // Store two: the External Resources, files and links on the unit itself.
    'guidePath': 'learningUnits/2awVLuyYaxFqMFuVp3Ny/impeccable-skill-guide.pdf',
    'materialPath':
        'learningUnits/2awVLuyYaxFqMFuVp3Ny/impeccable-skill-guide.pdf',
    'observationPath': 'learningUnits/2awVLuyYaxFqMFuVp3Ny/Sample.pdf',
    'topicGuidePath': 'learningUnits/2awVLuyYaxFqMFuVp3Ny/Sample.pdf',
    'varGuidePath': 'learningUnits/2awVLuyYaxFqMFuVp3Ny/Sample.pdf',
    'videoUrl': 'https://www.youtube.com/watch?v=lY2yjAdbvdQ'
        '&list=RDlY2yjAdbvdQ&start_radio=1',
    'templatePath': '',
  },
});

/// The step contents, with the exact category and subCategory the workflow
/// stores. All five of step 1, in document order.
const materialList = WorkflowContent(
  contentName: 'Material list',
  contentCategory: 'externalResources',
  contentSubCategory: 'materialPath',
  resourcePath: '',
);

const observationSheet = WorkflowContent(
  contentName: 'Observation Sheet',
  contentCategory: 'externalResources',
  contentSubCategory: 'observationPath',
  resourcePath: '',
);

const stepThreeGuide = WorkflowContent(
  contentName: 'Activity Guide',
  contentCategory: 'externalResources',
  contentSubCategory: 'guidePath',
  resourcePath: '',
);

/// The one whose category IS a maturity category, for contrast.
const activityGuide = WorkflowContent(
  contentName: 'Activity Guide',
  contentCategory: 'tacDev',
  contentSubCategory: 'devGuidePdf',
  resourcePath: '',
);

void main() {
  group('the category says which store to look in', () {
    test('an externalResources content is recognised', () {
      expect(materialList.isExternalResources, isTrue);
      expect(observationSheet.isExternalResources, isTrue);
    });

    test('the spacing and casing the field is written with do not matter', () {
      for (final spelling in [
        'externalResources',
        'external resources',
        'External Resources',
        'externalresources',
      ]) {
        expect(
          WorkflowContent(
            contentCategory: spelling,
            contentSubCategory: 'materialPath',
          ).isExternalResources,
          isTrue,
          reason: spelling,
        );
      }
    });

    test('a maturity category is not mistaken for an external one', () {
      expect(activityGuide.isExternalResources, isFalse);
    });
  });

  group('the External Resources resolve', () {
    test('Material List finds the file the web app uploaded', () {
      // READ "no content attached yet" BEFORE THIS. The file was there the
      // whole time; nothing was looking on the unit document.
      expect(
        sterlingPoint().externalResourcePath(materialList.contentSubCategory),
        'learningUnits/2awVLuyYaxFqMFuVp3Ny/impeccable-skill-guide.pdf',
      );
    });

    test('Observation Sheet finds its file', () {
      expect(
        sterlingPoint().externalResourcePath(
          observationSheet.contentSubCategory,
        ),
        'learningUnits/2awVLuyYaxFqMFuVp3Ny/Sample.pdf',
      );
    });

    test('the step-3 Activity Guide finds its own, different file', () {
      // Step 1's guide is tacDev.devGuidePdf and step 3's is
      // externalResources.guidePath. Two slots, two files, one tab name.
      expect(
        sterlingPoint().externalResourcePath(stepThreeGuide.contentSubCategory),
        'learningUnits/2awVLuyYaxFqMFuVp3Ny/impeccable-skill-guide.pdf',
      );
    });

    test('and they classify into the viewers that can show them', () {
      final unit = sterlingPoint();

      expect(
        ResolvedResource.of(unit.externalResourcePath('materialPath'))!.kind,
        ResourceKind.pdf,
      );
      expect(
        ResolvedResource.of(unit.externalResourcePath('videoUrl'))!.kind,
        ResourceKind.youTube,
      );
    });
  });

  group('what must never come back from the external lookup', () {
    test('a maturity key, because that value is a document id', () {
      // `resources.gold` is "1eXvhUXV7stAgLMV8BA0". Returned as a path it
      // becomes an object-not-found against Storage, or worse, a viewer
      // spinning on a file that does not exist.
      final unit = sterlingPoint();

      expect(unit.externalResourcePath('gold'), isNull);
      expect(unit.externalResourcePath('Gold'), isNull);
      // The rung is still readable where it MEANS something.
      expect(unit.resourceIdForMaturity, '1eXvhUXV7stAgLMV8BA0');
    });

    test('an empty slot, which is not the same as a missing one', () {
      final unit = sterlingPoint();

      // Present on the document and blank: the editor created the row and
      // nobody has uploaded to it.
      expect(unit.externalResourcePath('templatePath'), isNull);
      // Never on the document at all.
      expect(unit.externalResourcePath('varVideoUrl'), isNull);
      expect(unit.externalResourcePath(null), isNull);
      expect(unit.externalResourcePath(''), isNull);
    });
  });
}
