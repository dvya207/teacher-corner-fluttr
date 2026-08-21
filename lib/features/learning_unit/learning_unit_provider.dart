import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/learning_unit.dart';
import '../../core/models/workflow.dart';
import '../../core/services/firestore_service.dart';

enum LearningUnitStatus { loading, loaded, notFound, error }

const Duration kLearningUnitTimeout = Duration(seconds: 15);

/// Holds one activity as a specific classroom runs it.
///
/// It is loaded with a [workflowId] that the CLASSROOM supplied. There is
/// deliberately no path from a learning unit to its workflow here, because that
/// relationship does not exist in the data: the same unit runs a different
/// workflow in a different classroom.
class LearningUnitProvider extends ChangeNotifier {
  LearningUnitProvider({
    required FirestoreService firestore,
    Duration timeout = kLearningUnitTimeout,
  })  : _firestore = firestore,
        _timeout = timeout;

  final FirestoreService _firestore;
  final Duration _timeout;

  LearningUnitStatus _status = LearningUnitStatus.loading;
  LearningUnit? _unit;
  Workflow? _workflow;
  String? _errorKey;
  int _selectedStep = 0;
  String? _learningUnitId;
  String? _workflowId;
  bool _inFlight = false;
  bool _disposed = false;

  LearningUnitStatus get status => _status;
  LearningUnit? get unit => _unit;
  Workflow? get workflow => _workflow;
  String? get errorKey => _errorKey;

  /// Already ordered by `sequenceNumber`, sorted once at the parse boundary.
  List<WorkflowStep> get steps => _workflow?.steps ?? const [];

  int get selectedStepIndex => _selectedStep;

  WorkflowStep? get selectedStep =>
      (_selectedStep >= 0 && _selectedStep < steps.length)
          ? steps[_selectedStep]
          : null;

  bool get hasNoSteps => _status == LearningUnitStatus.loaded && steps.isEmpty;

  String? get learningUnitId => _learningUnitId;
  String? get workflowId => _workflowId;

  Future<void> load({
    required String learningUnitId,
    required String workflowId,
  }) async {
    if (_learningUnitId == learningUnitId &&
        _workflowId == workflowId &&
        _status != LearningUnitStatus.error) {
      return;
    }
    _learningUnitId = learningUnitId;
    _workflowId = workflowId;
    await _fetch();
  }

  Future<void> retry() async {
    if (_learningUnitId == null || _workflowId == null) return;
    await _fetch();
  }

  void selectStep(int index) {
    if (index < 0 || index >= steps.length) return;
    if (index == _selectedStep) return;
    _selectedStep = index;
    _notify();
  }

  Future<void> _fetch() async {
    if (_inFlight) return;
    _inFlight = true;
    _status = LearningUnitStatus.loading;
    _errorKey = null;
    _notify();

    try {
      // In parallel: neither read depends on the other, and a teacher mid-class
      // should not pay for them in series.
      final unitFuture = _firestore.fetchLearningUnit(_learningUnitId!);
      final workflowFuture = _firestore.fetchWorkflow(_workflowId!);
      final unit = await unitFuture.timeout(_timeout);
      final workflow = await workflowFuture.timeout(_timeout);

      _unit = unit;
      _workflow = workflow;
      if (unit == null || workflow == null) {
        // Either the activity, or the workflow this classroom binds to it, is
        // gone. Retrying will not bring it back.
        _status = LearningUnitStatus.notFound;
      } else {
        _selectedStep = 0;
        _status = LearningUnitStatus.loaded;
      }
    } on TimeoutException {
      _status = LearningUnitStatus.error;
      _errorKey = 'lu.error_offline';
    } catch (e) {
      debugPrint('LearningUnitProvider: load failed: $e');
      _status = LearningUnitStatus.error;
      _errorKey = 'lu.error_generic';
    } finally {
      _inFlight = false;
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
