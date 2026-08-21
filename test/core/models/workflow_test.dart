import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/workflow.dart';

/// `Workflows/wf_mps_v1` exactly as seeded: six steps, stored OUT of array
/// order on purpose, s2 first.
Map<String, dynamic> seededWorkflow() => {
  'steps': [
    {
      'workflowStepId': 's2',
      'workflowStepName': 'Gather materials',
      'workflowStepType': 'MATERIALS',
      'sequenceNumber': 2,
      'workflowStepDuration': 5,
      'canSkipWorkflowStep': true,
      'allowArtefactUpload': false,
      'contents': [
        {
          'contentName': 'Material List',
          'contentCategory': 'material',
          'contentType': 'image',
          'resourcePath': 'luContent/divya-teacher-corner/mps_materials.png',
        },
      ],
    },
    {
      'workflowStepId': 's1',
      'workflowStepName': 'Introduce the problem',
      'workflowStepType': 'INTRO',
      'sequenceNumber': 1,
      'workflowStepDuration': 10,
      'canSkipWorkflowStep': false,
      'allowArtefactUpload': false,
      'contents': [
        {
          'contentName': 'Guide',
          'contentCategory': 'guide',
          'contentType': 'guide',
          'resourcePath': '',
        },
      ],
    },
    {
      'workflowStepId': 's3',
      'workflowStepName': 'Build it',
      'sequenceNumber': 3,
      'allowArtefactUpload': false,
      // Two contents: one real image, one deliberately empty, so the tab strip
      // has both a positive render and the nothing-attached state.
      'contents': [
        {
          'contentName': 'Assembly',
          'contentCategory': 'image',
          'contentType': 'image',
          'resourcePath': 'luContent/divya-teacher-corner/mps_step3_assembly.png',
        },
        {
          'contentName': 'Teacher notes',
          'contentCategory': 'guide',
          'contentType': 'guide',
          'resourcePath': '',
        },
      ],
    },
    {
      'workflowStepId': 's4',
      'workflowStepName': 'Observe',
      'sequenceNumber': 4,
      'allowArtefactUpload': false,
      'contents': <dynamic>[],
    },
    {
      'workflowStepId': 's5',
      'workflowStepName': 'Discuss',
      'sequenceNumber': 5,
      'canSkipWorkflowStep': true,
      'allowArtefactUpload': false,
      'contents': <dynamic>[],
    },
    {
      'workflowStepId': 's6',
      'workflowStepName': 'Capture evidence',
      'workflowStepType': 'ASSIGNMENT',
      'sequenceNumber': 6,
      'allowArtefactUpload': true,
      'assignmentId': 'asg_mps_evidence',
      'contents': [
        {
          'contentName': 'Photo evidence',
          'contentCategory': 'assignment',
          'assignmentType': 'UPLOAD',
          'assignmentId': 'asg_mps_evidence',
          'resourcePath': '',
        },
      ],
    },
  ],
};

void main() {
  group('ordering', () {
    test('steps come out in sequenceNumber order, not array order', () {
      // The seed puts s2 in the array first, deliberately.
      final workflow = Workflow.fromMap('wf_mps_v1', seededWorkflow());

      expect(workflow.steps.map((s) => s.workflowStepId), [
        's1',
        's2',
        's3',
        's4',
        's5',
        's6',
      ]);
    });

    test('array order alone would have been wrong', () {
      // Guards against someone removing the sort as redundant.
      final raw = seededWorkflow()['steps'] as List;
      expect(raw.first['workflowStepId'], 's2');
    });

    test('a step with no sequenceNumber sorts last, not first', () {
      final workflow = Workflow.fromMap('wf', {
        'steps': [
          {'workflowStepId': 'no_number'},
          {'workflowStepId': 'second', 'sequenceNumber': 2},
          {'workflowStepId': 'first', 'sequenceNumber': 1},
        ],
      });

      expect(workflow.steps.map((s) => s.workflowStepId), [
        'first',
        'second',
        'no_number',
      ]);
    });

    test('duplicate sequence numbers keep a stable, repeatable order', () {
      // Two reads of the same document must not present the steps differently.
      Map<String, dynamic> doc() => {
        'steps': [
          {'workflowStepId': 'a', 'sequenceNumber': 1},
          {'workflowStepId': 'b', 'sequenceNumber': 1},
          {'workflowStepId': 'c', 'sequenceNumber': 1},
        ],
      };

      expect(Workflow.fromMap('wf', doc()).steps.map((s) => s.workflowStepId), [
        'a',
        'b',
        'c',
      ]);
      expect(Workflow.fromMap('wf', doc()).steps.map((s) => s.workflowStepId), [
        'a',
        'b',
        'c',
      ]);
    });

    test('a sequenceNumber stored as a String still sorts numerically', () {
      final workflow = Workflow.fromMap('wf', {
        'steps': [
          {'workflowStepId': 'ten', 'sequenceNumber': '10'},
          {'workflowStepId': 'two', 'sequenceNumber': 2},
        ],
      });

      // Not lexicographic: "10" must not come before 2.
      expect(workflow.steps.map((s) => s.workflowStepId), ['two', 'ten']);
    });

    test('the step list cannot be sorted in place by a widget', () {
      final workflow = Workflow.fromMap('wf_mps_v1', seededWorkflow());
      expect(() => workflow.steps.removeLast(), throwsUnsupportedError);
    });
  });

  group('the seeded steps', () {
    test('parse their durations, skip flags and contents', () {
      final workflow = Workflow.fromMap('wf_mps_v1', seededWorkflow());
      final intro = workflow.steps.first;

      expect(intro.label, 'Introduce the problem');
      expect(intro.workflowStepType, 'INTRO');
      expect(intro.durationMinutes, 10);
      expect(intro.canSkip, isFalse);
      expect(workflow.steps[4].canSkip, isTrue);
      expect(intro.contents.single.contentName, 'Guide');
    });

    test('an empty resourcePath is not mistaken for a resource', () {
      // Step 1's Guide is present but carries nothing renderable, which is a
      // real seeded state and not an oversight.
      final workflow = Workflow.fromMap('wf_mps_v1', seededWorkflow());
      expect(workflow.steps.first.contents.single.hasResource, isFalse);
    });

    test('the seeded image contents resolve as images with real paths', () {
      final workflow = Workflow.fromMap('wf_mps_v1', seededWorkflow());

      final materials = workflow.steps[1].contents.single;
      expect(materials.isImage, isTrue);
      expect(materials.hasResource, isTrue);
      // A Storage path, never a URL.
      expect(materials.resourcePath, isNot(startsWith('http')));

      final build = workflow.steps[2].contents;
      expect(build, hasLength(2));
      expect(build.first.isImage, isTrue);
      expect(build.first.hasResource, isTrue);
      expect(build.last.hasResource, isFalse);
    });

    test('the evidence step is findable without hardcoding step 6', () {
      final workflow = Workflow.fromMap('wf_mps_v1', seededWorkflow());
      final upload = workflow.uploadStep;

      expect(upload, isNotNull);
      expect(upload!.workflowStepId, 's6');
      expect(upload.assignmentId, 'asg_mps_evidence');
      expect(upload.contents.single.isUploadAssignment, isTrue);
    });

    test(
      'a workflow with no upload step returns null rather than guessing',
      () {
        final workflow = Workflow.fromMap('wf', {
          'steps': [
            {'workflowStepId': 's1', 'sequenceNumber': 1},
          ],
        });
        expect(workflow.uploadStep, isNull);
      },
    );
  });

  group('degrading', () {
    test('a missing steps field yields no steps rather than throwing', () {
      expect(Workflow.fromMap('wf', const {}).steps, isEmpty);
    });

    test('steps stored as a map instead of a list still parse', () {
      final workflow = Workflow.fromMap('wf', {
        'steps': {
          '1': {'workflowStepId': 'b', 'sequenceNumber': 2},
          '0': {'workflowStepId': 'a', 'sequenceNumber': 1},
        },
      });
      expect(workflow.steps.map((s) => s.workflowStepId), ['a', 'b']);
    });

    test('a step with no id at all gets a distinct fallback id', () {
      final workflow = Workflow.fromMap('wf', {
        'steps': [
          {'sequenceNumber': 1},
          {'sequenceNumber': 2},
        ],
      });
      // Distinct, so the two steps cannot collide in a keyed widget list.
      expect(workflow.steps.map((s) => s.workflowStepId).toSet(), hasLength(2));
    });

    test('one malformed step does not lose the others', () {
      final workflow = Workflow.fromMap('wf', {
        'steps': [
          'this should have been a map',
          {'workflowStepId': 's1', 'sequenceNumber': 1},
        ],
      });
      expect(workflow.steps.map((s) => s.workflowStepId), ['s1']);
    });
  });

  group('content types', () {
    WorkflowContent content(Map<String, dynamic> data) =>
        WorkflowContent.fromMap(data, docId: 'wf', field: 'steps.contents');

    test('an image is recognised from its declared type', () {
      expect(
        content({'contentType': 'image', 'resourcePath': 'a/b.bin'}).isImage,
        isTrue,
      );
    });

    test('an image is recognised from its file extension', () {
      // The seeded documents label some images only by file name.
      for (final path in [
        'luImages/mps.png',
        'luImages/mps.JPG',
        'luImages/mps.jpeg',
        'luImages/mps.webp',
      ]) {
        expect(content({'resourcePath': path}).isImage, isTrue, reason: path);
      }
    });

    test('a document is not mistaken for an image', () {
      final guide = content({
        'contentCategory': 'guide',
        'resourcePath': 'guides/mps.pdf',
      });
      expect(guide.isImage, isFalse);
      expect(guide.isDocument, isTrue);
    });

    test('the upload assignment is not treated as a picture to display', () {
      // Its name mentions photos, but it is a place to PUT photos.
      final assignment = content({
        'contentName': 'Photo evidence',
        'contentCategory': 'assignment',
        'assignmentType': 'UPLOAD',
        'resourcePath': '',
      });
      expect(assignment.isUploadAssignment, isTrue);
      expect(assignment.isImage, isFalse);
    });

    test('an empty resourcePath is neither image nor document', () {
      // Present but useless, which is what every seeded content has.
      final empty = content({'contentName': 'Guide', 'resourcePath': ''});
      expect(empty.hasResource, isFalse);
      expect(empty.isImage, isFalse);
      expect(empty.isDocument, isFalse);
    });
  });
}
