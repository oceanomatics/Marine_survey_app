// lib/features/cases/screens/cases_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/cases_provider.dart';
import '../models/case_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';

class CasesListScreen extends ConsumerWidget {
  const CasesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(casesProvider);
    return Scaffold(
      appBar: BackAppBar(
        title: const Text('Cases'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inbox_outlined, color: Colors.white),
            onPressed: () => context.go('/inbox'),
            tooltip: 'Inbox',
          ),
          IconButton(
            icon: const Icon(Icons.access_time_outlined, color: Colors.white),
            onPressed: () => context.go('/timesheet'),
            tooltip: 'Timesheet',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined, color: Colors.white),
            onPressed: () => context.go('/usage'),
            tooltip: 'API usage',
          ),
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined,
                color: Colors.white),
            onPressed: () => context.go('/account'),
            tooltip: 'Account',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/cases/new'),
        backgroundColor: AppColors.navy,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Case', style: TextStyle(color: Colors.white)),
      ),
      body: casesAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => AppErrorWidget(
          error: e.toString(),
          onRetry: () => ref.invalidate(casesProvider),
        ),
        data: (cases) => cases.isEmpty
            ? _EmptyState(onNew: () => context.go('/cases/new'))
            : RefreshIndicator(
                onRefresh: () => ref.read(casesProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CaseCard(survey: cases[i]),
                ),
              ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.survey});
  final CaseModel survey;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/cases/${survey.caseId}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.lightPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.folder_outlined,
                  color: AppColors.purple, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(survey.title ?? survey.vesselName ?? survey.technicalFileNo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(survey.technicalFileNo,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                if (survey.clientName != null)
                  Text(survey.clientName!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(survey.status.label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.midBlue,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Text(survey.caseType.label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.folder_open_outlined,
          size: 64, color: AppColors.textTertiary),
      const SizedBox(height: 16),
      const Text('No cases yet',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onNew,
        icon: const Icon(Icons.add),
        label: const Text('Create first case'),
      ),
    ]));
  }
}
