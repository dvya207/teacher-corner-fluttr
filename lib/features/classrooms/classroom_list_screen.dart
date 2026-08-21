import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/tc_app_bar.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_empty_state.dart';
import '../../core/widgets/tc_loading.dart';
import '../../core/widgets/tc_search_bar.dart';
import '../../core/widgets/tc_status_message.dart';
import '../auth/auth_provider.dart';
import 'classroom_provider.dart';
import 'widgets/classroom_card.dart';

class ClassroomListScreen extends StatefulWidget {
  const ClassroomListScreen({super.key});

  @override
  State<ClassroomListScreen> createState() => _ClassroomListScreenState();
}

class _ClassroomListScreenState extends State<ClassroomListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Post-frame: load() notifies listeners, and notifying during build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().uid;
      if (uid != null) context.read<ClassroomProvider>().load(uid);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classrooms = context.watch<ClassroomProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TcAppBar(title: 'classrooms.title'.tr()),
      body: switch (classrooms.status) {
        ClassroomListStatus.loading => TcLoading(message: 'common.loading'.tr()),
        ClassroomListStatus.error => _ErrorState(
            messageKey: classrooms.errorKey ?? 'classrooms.error_generic',
            onRetry: classrooms.retry,
          ),
        ClassroomListStatus.loaded => _LoadedState(
            provider: classrooms,
            searchController: _searchController,
          ),
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.messageKey, required this.onRetry});

  final String messageKey;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TcStatusBanner(
              type: TcMsgType.error,
              title: 'classrooms.error_title'.tr(),
              message: messageKey.tr(),
            ),
            SizedBox(height: AppDimensions.spacing24),
            TcButton(label: 'common.retry'.tr(), onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _LoadedState extends StatelessWidget {
  const _LoadedState({
    required this.provider,
    required this.searchController,
  });

  final ClassroomProvider provider;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    // No classrooms at all: the search bar would be furniture with nothing to
    // filter, so it is not shown.
    if (provider.isEmpty) {
      return TcEmptyState(
        icon: Icons.class_outlined,
        title: 'classrooms.empty_title'.tr(),
        subtitle: 'classrooms.empty_subtitle'.tr(),
      );
    }

    final visible = provider.visible;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.spacing16,
            AppDimensions.spacing12,
            AppDimensions.spacing16,
            AppDimensions.spacing8,
          ),
          child: TcSearchBar(
            hint: 'classrooms.search_hint'.tr(),
            controller: searchController,
            onChanged: provider.search,
          ),
        ),
        Expanded(
          // Distinct from the no-classrooms state: there ARE classrooms, the
          // query just hides them, and the wording has to say so or the teacher
          // thinks their classrooms are gone.
          child: provider.hasNoMatches
              ? TcEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'classrooms.no_results_title'.tr(),
                  subtitle: 'classrooms.no_results_subtitle'.tr(),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppDimensions.spacing16,
                    AppDimensions.spacing8,
                    AppDimensions.spacing16,
                    AppDimensions.spacing24,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: AppDimensions.spacing12),
                  itemBuilder: (context, index) {
                    final classroom = visible[index];
                    return ClassroomCard(
                      classroom: classroom,
                      onTap: () => context.go(
                        '/classrooms/${classroom.classroomId}',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
