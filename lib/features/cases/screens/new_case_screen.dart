// lib/features/cases/screens/new_case_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/cases_provider.dart';
import '../models/case_model.dart';
import '../../../shared/theme/app_theme.dart';

class NewCaseScreen extends ConsumerStatefulWidget {
  const NewCaseScreen({super.key});
  @override
  ConsumerState<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends ConsumerState<NewCaseScreen> {
  final _jobCtrl   = TextEditingController();
  final _claimCtrl = TextEditingController();
  CaseType  _type   = CaseType.hm;
  OutputFormat _fmt = OutputFormat.abl;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Case')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _jobCtrl,
              decoration: const InputDecoration(
                  labelText: 'Job Number *', hintText: 'e.g. AU-M53-056789')),
          const SizedBox(height: 16),
          TextField(controller: _claimCtrl,
              decoration: const InputDecoration(
                  labelText: 'Claim Reference',
                  hintText: 'e.g. GARD-2025O123456')),
          const SizedBox(height: 16),
          DropdownButtonFormField<CaseType>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Survey Type'),
            items: CaseType.values.map((t) =>
                DropdownMenuItem(value: t, child: Text(t.label))).toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<OutputFormat>(
            value: _fmt,
            decoration: const InputDecoration(labelText: 'Report Format'),
            items: OutputFormat.values.map((f) =>
                DropdownMenuItem(value: f, child: Text(f.label))).toList(),
            onChanged: (v) => setState(() => _fmt = v!),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _create,
              child: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Create Case'),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _create() async {
    if (_jobCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final c = await ref.read(casesProvider.notifier).createCase(
        jobNumber: _jobCtrl.text.trim(),
        caseType: _type,
        outputFormat: _fmt,
        claimReference: _claimCtrl.text.trim().isEmpty
            ? null : _claimCtrl.text.trim(),
      );
      if (mounted) context.go('/cases/${c.caseId}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
