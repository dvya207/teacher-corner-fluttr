import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_empty_state.dart';
import '../auth/auth_provider.dart';
import '../../core/services/firestore_service.dart';
import 'quiz_player_provider.dart';
import 'quiz_player_screen.dart';
import 'quizzes_provider.dart';

/// Which chip is showing.
enum QuizzesTab { classrooms, contests, events }

/// Quizzes & Contests — every classroom, with the assignments set on it.
///
/// THE SHAPE IS THE PRODUCTION ANDROID APP'S, deliberately: a row of chips with
/// counts, then one expandable card per classroom that reveals its assignments
/// or says there are none. A teacher moving between the two apps should not have
/// to relearn the screen.
///
/// CONTESTS AND EVENTS ARE PRESENT AND HONEST. Production has both, and this
/// rebuild reads neither collection. Hiding the chips would make the screen look
/// finished; showing them empty says what is missing, which is the same choice
/// [NotBuiltScreen] makes for a whole tab.
class QuizzesScreen extends StatefulWidget {
  const QuizzesScreen({super.key});

  @override
  State<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends State<QuizzesScreen> {
  QuizzesTab _tab = QuizzesTab.classrooms;

  @override
  void initState() {
    super.initState();

    /*
     * AFTER THE FIRST FRAME, not during build. Reading another provider and
     * kicking off a load synchronously here would notify listeners while the
     * widget tree is still building, which Flutter rejects.
     *
     * THE ACCOUNT COMES FROM AuthProvider, which is what already holds the
     * signed-in teacher and their teaching record. It can legitimately be null
     * for a signed-in account with no teaching record at all; the provider then
     * has no classrooms to group by and the screen says so.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final account = context.read<AuthProvider>().account;

      if (account == null) return;

      unawaited(context.read<QuizzesProvider>().load(account));
    });
  }

  /// Which classroom cards are open, by classroom id.
  ///
  /// HELD BY ID RATHER THAN INDEX, so a reload that reorders or drops a
  /// classroom cannot leave a different one expanded.
  final Set<String> _open = <String>{};

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizzesProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(title: 'quizzes.title'.tr()),
      body: Column(
        children: [
          _Chips(
            tab: _tab,
            classroomCount: provider.classroomCount,
            assignmentCount: provider.assignmentCount,
            onChanged: (tab) => setState(() => _tab = tab),
          ),
          Expanded(child: _body(provider)),
        ],
      ),
    );
  }

  /// Opens the player, then refreshes on return.
  ///
  /// RELOADS AFTERWARDS because an attempt changes what the list should say: the
  /// summary's `attemptsCount` has moved, and a quiz whose cap is now spent must
  /// not look untouched.
  Future<void> _openQuiz(
    BuildContext context,
    ClassroomAssignments classroom,
    AssignmentInClassroom entry,
  ) async {
    final account = context.read<AuthProvider>().account;
    final teacherDocId = account?.teaching?.docId;
    final uid = account?.uid;

    // NO TEACHER RECORD MEANS NOWHERE TO WRITE. Said before the quiz opens
    // rather than after it is answered: losing a completed attempt to a
    // permission the app already knew about is the worse failure.
    if (account == null || teacherDocId == null || uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('quizzes.no_teacher_record'.tr())));

      return;
    }

    final firestore = context.read<FirestoreService>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<QuizPlayerProvider>(
          create: (_) => QuizPlayerProvider(
            firestore: firestore,
            assignment: entry.assignment,
            teacherDocId: teacherDocId,
            uid: uid,
            classroomId: classroom.classroom.classroomId,
            programmeId: entry.programmeId,
          ),
          child: const QuizPlayerScreen(),
        ),
      ),
    );

    if (!context.mounted) return;

    await context.read<QuizzesProvider>().load(account);
  }

  Widget _body(QuizzesProvider provider) {
    switch (_tab) {
      case QuizzesTab.contests:
        // REUSES THE APP'S OWN "not in this build" WORDING rather than adding
        // two more strings for ten locales to translate. It is the same fact
        // NotBuiltScreen states for a whole tab, and it is already vetted in
        // every language.
        return TcEmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'common.not_built_title'.tr(),
          subtitle: 'common.not_built_subtitle'.tr(),
        );
      case QuizzesTab.events:
        return TcEmptyState(
          icon: Icons.event_outlined,
          title: 'common.not_built_title'.tr(),
          subtitle: 'common.not_built_subtitle'.tr(),
        );
      case QuizzesTab.classrooms:
        break;
    }

    switch (provider.status) {
      case QuizzesStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case QuizzesStatus.error:
        return TcEmptyState(
          icon: Icons.error_outline,
          title: 'common.error_title'.tr(),
          subtitle: (provider.errorKey ?? 'errors.generic').tr(),
        );
      case QuizzesStatus.empty:
        return TcEmptyState(
          icon: Icons.school_outlined,
          title: 'quizzes.no_classrooms_title'.tr(),
          subtitle: 'quizzes.no_classrooms_subtitle'.tr(),
        );
      case QuizzesStatus.loaded:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: provider.rows.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, at) {
            final row = provider.rows[at];
            final id = row.classroom.classroomId;

            return _ClassroomCard(
              row: row,
              expanded: _open.contains(id),
              onToggle: () => setState(
                () => _open.contains(id) ? _open.remove(id) : _open.add(id),
              ),
              onOpen: (entry) => _openQuiz(context, row, entry),
            );
          },
        );
    }
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.tab,
    required this.classroomCount,
    required this.assignmentCount,
    required this.onChanged,
  });

  final QuizzesTab tab;
  final int classroomCount;
  final int assignmentCount;
  final ValueChanged<QuizzesTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _Chip(
            label: 'quizzes.tab_classrooms'.tr(),
            // The count is CLASSROOMS, matching the production app's own chip.
            count: classroomCount,
            selected: tab == QuizzesTab.classrooms,
            onTap: () => onChanged(QuizzesTab.classrooms),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'quizzes.tab_contests'.tr(),
            count: null,
            selected: tab == QuizzesTab.contests,
            onTap: () => onChanged(QuizzesTab.contests),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'quizzes.tab_events'.tr(),
            count: null,
            selected: tab == QuizzesTab.events,
            onTap: () => onChanged(QuizzesTab.events),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.skyBlue : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? AppColors.skyBlue : AppColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassroomCard extends StatelessWidget {
  const _ClassroomCard({
    required this.row,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
  });

  final ClassroomAssignments row;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<AssignmentInClassroom> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_outlined, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.classroom.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        if (row.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            row.subtitle,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: row.isEmpty
                  ? Text(
                      'quizzes.none_in_classroom'.tr(),
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  : Column(
                      children: [
                        for (final entry in row.assignments)
                          _AssignmentRow(row: entry, onOpen: onOpen),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.row, required this.onOpen});

  final AssignmentInClassroom row;
  final ValueChanged<AssignmentInClassroom> onOpen;

  @override
  Widget build(BuildContext context) {
    final assignment = row.assignment;
    final due = assignment.dueDate;

    /*
     * ONLY A QUIZ OPENS. Uploads and forms are listed because they are set on
     * the classroom and a teacher should see them, but this app can answer
     * neither, and a row that looks tappable and does nothing is worse than one
     * that plainly is not.
     */
    final openable = assignment.isQuiz;

    return InkWell(
      onTap: openable ? () => onOpen(row) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(_icon(assignment.type), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    due == null
                        ? 'quizzes.no_due'.tr()
                        : 'quizzes.due'.tr(
                            args: [DateFormat.yMMMd().format(due)],
                          ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (assignment.isQuiz && assignment.questions.isNotEmpty)
              Text(
                'quizzes.questions'.tr(
                  args: ['${assignment.questions.length}'],
                ),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            if (openable) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _icon(String type) {
    switch (type.toUpperCase()) {
      case 'QUIZ':
        return Icons.quiz_outlined;
      case 'UPLOAD':
        return Icons.upload_file_outlined;
      case 'FORM':
        return Icons.assignment_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}
