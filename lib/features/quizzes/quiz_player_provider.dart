import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/assignment.dart';
import '../../core/models/quiz_scoring.dart';
import '../../core/services/firestore_service.dart';

enum QuizPlayerStatus { answering, submitting, submitted, error }

/// Holds one attempt while it is being answered, and writes it once.
///
/// THE ANSWERS LIVE HERE AND NOWHERE ELSE UNTIL SUBMIT. Nothing is written per
/// question: a half-finished attempt is not a submission, and writing as you go
/// would burn one of a strictly limited number of allowed attempts the moment
/// somebody opened the quiz to look at it.
class QuizPlayerProvider extends ChangeNotifier {
  QuizPlayerProvider({
    required FirestoreService firestore,
    required this.assignment,
    required this.teacherDocId,
    required this.uid,
    required this.classroomId,
    required this.programmeId,
    this.workflowId = '',
    this.userAgent = 'tc_starter (Flutter)',
  }) : _firestore = firestore,
       _answers = List.generate(
         assignment.questions.length,
         (_) => const QuizAnswer(),
       );

  final FirestoreService _firestore;
  final Assignment assignment;
  final String teacherDocId;
  final String uid;
  final String classroomId;
  final String programmeId;
  final String workflowId;
  final String userAgent;

  final List<QuizAnswer> _answers;

  QuizPlayerStatus _status = QuizPlayerStatus.answering;
  int _at = 0;
  String? _errorKey;
  QuizAttemptResult? _result;
  bool _capReached = false;

  QuizPlayerStatus get status => _status;
  int get index => _at;
  String? get errorKey => _errorKey;
  QuizAttemptResult? get result => _result;

  /// Whether the failure was the attempt cap rather than anything transient.
  ///
  /// Told apart because the remedy differs: a cap is final and a network failure
  /// is worth retrying, and offering Retry on the first is a lie.
  bool get capReached => _capReached;

  List<QuizQuestion> get questions => assignment.questions;
  QuizQuestion? get current =>
      _at >= 0 && _at < questions.length ? questions[_at] : null;
  QuizAnswer get currentAnswer =>
      _at < _answers.length ? _answers[_at] : const QuizAnswer();

  bool get hasPrevious => _at > 0;
  bool get hasNext => _at < questions.length - 1;
  int get answeredCount => _answers.where((a) => a.isAnswered).length;

  /// The score AS IT STANDS, for the result screen. Computed rather than stored,
  /// so it cannot disagree with what was written.
  AttemptMarks get marks => attemptMarks(questions, _answers);

  void goTo(int at) {
    if (at < 0 || at >= questions.length) return;

    _at = at;
    notifyListeners();
  }

  void next() => goTo(_at + 1);
  void previous() => goTo(_at - 1);

  /// Toggles an MCQ option.
  ///
  /// SINGLE-CHOICE REPLACES, MULTI-CHOICE TOGGLES, and which applies is the
  /// question's own `oneCorrectOption`. Getting this wrong is not cosmetic: the
  /// scorer requires the chosen set to match the correct set EXACTLY, so leaving
  /// a stale selection behind on a single-choice question scores zero.
  void toggleOption(int optionAt) {
    final question = current;

    if (question == null) return;

    final answer = currentAnswer;
    final chosen = [...answer.chosen];

    if (question.oneCorrectOption) {
      chosen
        ..clear()
        ..add(optionAt);
    } else if (chosen.contains(optionAt)) {
      chosen.remove(optionAt);
    } else {
      chosen.add(optionAt);
    }

    _answers[_at] = answer.copyWith(chosen: chosen);
    notifyListeners();
  }

  void setText(String text) {
    _answers[_at] = currentAnswer.copyWith(text: text);
    notifyListeners();
  }

  void setBlank(String key, String value) {
    _answers[_at] = currentAnswer.copyWith(
      blanks: {...currentAnswer.blanks, key: value},
    );
    notifyListeners();
  }

  /// Writes the attempt. Idempotent against double-tap: a submit already in
  /// flight is ignored rather than queued.
  Future<void> submit() async {
    if (_status == QuizPlayerStatus.submitting ||
        _status == QuizPlayerStatus.submitted) {
      return;
    }

    _status = QuizPlayerStatus.submitting;
    _errorKey = null;
    _capReached = false;
    notifyListeners();

    try {
      _result = await _firestore.saveQuizAttempt(
        teacherDocId: teacherDocId,
        uid: uid,
        classroomId: classroomId,
        programmeId: programmeId,
        workflowId: workflowId,
        assignment: assignment,
        answers: List.unmodifiable(_answers),
        userAgent: userAgent,
      );

      _status = QuizPlayerStatus.submitted;
    } catch (error) {
      _capReached = error.toString().contains(
        FirestoreService.maxAttemptsReached,
      );
      _errorKey = _capReached ? 'quizzes.cap_reached' : 'quizzes.submit_failed';
      _status = QuizPlayerStatus.error;
    }

    notifyListeners();
  }
}
