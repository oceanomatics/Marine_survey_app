// lib/features/settings/screens/usage_screen.dart
//
// Token usage and cost tracking screen.
// Reads from the `token_usage` Supabase table and shows totals,
// per-feature breakdown, and per-case breakdown.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_theme.dart';

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

enum _Period { thisMonth, last3Months, allTime }

extension on _Period {
  String get label => switch (this) {
        _Period.thisMonth    => 'This month',
        _Period.last3Months  => 'Last 3 months',
        _Period.allTime      => 'All time',
      };

  DateTime get since {
    final now = DateTime.now();
    return switch (this) {
      _Period.thisMonth   => DateTime(now.year, now.month, 1),
      _Period.last3Months => DateTime(now.year, now.month - 3, now.day),
      _Period.allTime     => DateTime(2024, 1, 1),
    };
  }
}

// Human-readable labels for feature identifiers.
const _featureLabels = <String, String>{
  'report_extraction':    'Report extraction',
  'certificate_extraction': 'Certificate extraction',
  'vessel_particulars':   'Vessel particulars',
  'occurrence_narrative': 'Narrative draft',
  'cause_consideration':  'Cause consideration',
  'invoice_extraction':   'Invoice extraction',
  'photo_classification': 'Photo classification',
  'voice_routing':        'Voice note routing',
  'email_classification': 'Email classification',
  'api_call':             'Other API call',
};

typedef _TokenTotals = ({int input, int output, double cost});

class _UsageScreenState extends State<UsageScreen> {
  _Period _period = _Period.thisMonth;
  bool _loading   = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  Map<String, String> _caseLabels     = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await SupabaseService.client
          .from('token_usage')
          .select()
          .gte('created_at', _period.since.toIso8601String())
          .order('created_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(rows as List);

      // Resolve case labels — wrapped separately so a deleted/missing case
      // never prevents usage data from showing.
      final caseIds = records
          .map((r) => r['case_id'] as String?)
          .whereType<String>()
          .toSet();

      Map<String, String> caseLabels = {};
      if (caseIds.isNotEmpty) {
        try {
          final cases = await SupabaseService.client
              .from('cases')
              .select('case_id, vessel_name, technical_file_no')
              .inFilter('case_id', caseIds.toList());
          caseLabels = {
            for (final c in cases as List)
              c['case_id'] as String:
                  '${c['vessel_name'] ?? 'Unknown vessel'} — ${c['technical_file_no'] ?? ''}',
          };
        } catch (_) {
          // Cases may have been deleted — proceed with empty labels; the
          // _byCase view will show "Deleted case — …" for orphaned records.
        }
      }

      setState(() {
        _records    = records;
        _caseLabels = caseLabels;
        _loading    = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Aggregations ────────────────────────────────────────────────────────────

  _TokenTotals get _totals {
    int input = 0, output = 0;
    double cost = 0;
    for (final r in _records) {
      input  += (r['input_tokens']  as num? ?? 0).toInt();
      output += (r['output_tokens'] as num? ?? 0).toInt();
      cost   += (r['cost_usd']      as num? ?? 0).toDouble();
    }
    return (input: input, output: output, cost: cost);
  }

  Map<String, _TokenTotals> get _byFeature {
    final map = <String, ({int input, int output, double cost})>{};
    for (final r in _records) {
      final key = r['feature'] as String? ?? 'api_call';
      final e = map[key];
      map[key] = (
        input:  (e?.input  ?? 0) + (r['input_tokens']  as num? ?? 0).toInt(),
        output: (e?.output ?? 0) + (r['output_tokens'] as num? ?? 0).toInt(),
        cost:   (e?.cost   ?? 0) + (r['cost_usd']      as num? ?? 0).toDouble(),
      );
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.cost.compareTo(a.value.cost)));
  }

  Map<String, _TokenTotals> get _byCase {
    final map = <String, ({int input, int output, double cost})>{};
    for (final r in _records) {
      final caseId = r['case_id'] as String?;
      if (caseId == null) continue;
      final e = map[caseId];
      map[caseId] = (
        input:  (e?.input  ?? 0) + (r['input_tokens']  as num? ?? 0).toInt(),
        output: (e?.output ?? 0) + (r['output_tokens'] as num? ?? 0).toInt(),
        cost:   (e?.cost   ?? 0) + (r['cost_usd']      as num? ?? 0).toDouble(),
      );
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.cost.compareTo(a.value.cost)));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Usage'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/cases');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(children: [
        _PeriodBar(
          selected: _period,
          onChanged: (p) { setState(() => _period = p); _load(); },
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(error: _error!, onRetry: _load)
                  : _Body(
                      totals:     _totals,
                      byFeature:  _byFeature,
                      byCase:     _byCase,
                      caseLabels: _caseLabels,
                      recordCount: _records.length,
                    ),
        ),
      ]),
    );
  }
}

// ── Period selector ──────────────────────────────────────────────────────────

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.selected, required this.onChanged});
  final _Period selected;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: _Period.values.map((p) {
          final active = p == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(p.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: active ? Colors.white : AppColors.textSecondary)),
              selected: active,
              onSelected: (_) => onChanged(p),
              selectedColor: AppColors.navy,
              backgroundColor: AppColors.surface,
              showCheckmark: false,
              side: BorderSide(
                  color: active ? AppColors.navy : AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Main scrollable body ─────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.totals,
    required this.byFeature,
    required this.byCase,
    required this.caseLabels,
    required this.recordCount,
  });

  final _TokenTotals totals;
  final Map<String, _TokenTotals> byFeature;
  final Map<String, _TokenTotals> byCase;
  final Map<String, String> caseLabels;
  final int recordCount;

  @override
  Widget build(BuildContext context) {
    if (recordCount == 0) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [_ApiKeyStatusCard(), SizedBox(height: 12), _EmptyState()],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _ApiKeyStatusCard(),
        const SizedBox(height: 12),
        _TotalsCard(totals: totals, recordCount: recordCount),
        const SizedBox(height: 20),
        const _SectionHeader('By feature', Icons.category_outlined),
        const SizedBox(height: 8),
        ...byFeature.entries.map((e) => _FeatureRow(
              label: _featureLabels[e.key] ?? e.key,
              totals: e.value,
              grandTotal: totals.cost,
            )),
        if (byCase.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionHeader('By case', Icons.folder_outlined),
          const SizedBox(height: 8),
          ...byCase.entries.map((e) {
                final label = caseLabels[e.key]
                    ?? 'Deleted case — …${e.key.length > 8 ? e.key.substring(e.key.length - 8) : e.key}';
                return _CaseRow(label: label, totals: e.value, deleted: !caseLabels.containsKey(e.key));
              }),
        ],
        const SizedBox(height: 20),
        _PricingNote(),
      ],
    );
  }
}

// ── Totals card ──────────────────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals, required this.recordCount});
  final _TokenTotals totals;
  final int recordCount;

  @override
  Widget build(BuildContext context) {
    final costFmt = NumberFormat('\$#,##0.0000', 'en_AU');
    final tokenFmt = NumberFormat('#,###');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.midBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.monetization_on_outlined,
                color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              'Estimated cost — $recordCount API call${recordCount == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            '${costFmt.format(totals.cost)} USD',
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _StatChip(
              label: 'Input',
              value: '${tokenFmt.format(totals.input)} tok',
              unitCost: '\$3.00/M',
            ),
            const SizedBox(width: 10),
            _StatChip(
              label: 'Output',
              value: '${tokenFmt.format(totals.output)} tok',
              unitCost: '\$15.00/M',
            ),
            const SizedBox(width: 10),
            _StatChip(
              label: 'Total',
              value:
                  '${tokenFmt.format(totals.input + totals.output)} tok',
              unitCost: '',
            ),
          ]),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.unitCost,
  });
  final String label, value, unitCost;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
            if (unitCost.isNotEmpty)
              Text(unitCost,
                  style: const TextStyle(
                      fontSize: 9, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8),
        ),
      ]);
}

// ── Feature row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.label,
    required this.totals,
    required this.grandTotal,
  });
  final String label;
  final _TokenTotals totals;
  final double grandTotal;

  @override
  Widget build(BuildContext context) {
    final fraction = grandTotal > 0 ? totals.cost / grandTotal : 0.0;
    final costFmt  = NumberFormat('\$#,##0.0000', 'en_AU');
    final tokenFmt = NumberFormat('#,###');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Text(
              costFmt.format(totals.cost),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: AppColors.surface,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.midBlue),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${tokenFmt.format(totals.input)} in + ${tokenFmt.format(totals.output)} out',
            style: const TextStyle(
                fontSize: 10, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Case row ─────────────────────────────────────────────────────────────────

class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.label, required this.totals, this.deleted = false});
  final String label;
  final _TokenTotals totals;
  final bool deleted;

  @override
  Widget build(BuildContext context) {
    final costFmt  = NumberFormat('\$#,##0.0000', 'en_AU');
    final tokenFmt = NumberFormat('#,###');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(deleted ? Icons.folder_off_outlined : Icons.folder_outlined,
            size: 16, color: deleted ? AppColors.textTertiary : AppColors.textTertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(
                '${tokenFmt.format(totals.input + totals.output)} tokens',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
        Text(
          costFmt.format(totals.cost),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navy),
        ),
      ]),
    );
  }
}

// ── Pricing note ──────────────────────────────────────────────────────────────

class _PricingNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightBlue.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.midBlue.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 14, color: AppColors.midBlue),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'claude-sonnet-4-6 pricing: \$3.00 / 1M input tokens, \$15.00 / 1M output tokens (USD). '
              'Cost estimates are calculated locally and stored per API call.',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.midBlue,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── API key status card ───────────────────────────────────────────────────────

class _ApiKeyStatusCard extends StatelessWidget {
  const _ApiKeyStatusCard();

  @override
  Widget build(BuildContext context) {
    final ok = AppConfig.isAnthropicKeySet;
    final color = ok ? const Color(0xFF2E7D32) : AppColors.error;
    final bg    = ok ? const Color(0xFFE8F5E9) : AppColors.lightCoral;
    final border = ok ? const Color(0xFFA5D6A7) : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(
          ok ? Icons.vpn_key_outlined : Icons.key_off_outlined,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ok ? 'Anthropic API key active' : 'Anthropic API key NOT set',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
              Text(
                ok
                    ? 'Key ending ${AppConfig.anthropicKeyHint} — loaded via --dart-define'
                    : 'Run the app from the Android/Chrome launch config in VS Code, not via hot restart.',
                style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bar_chart_outlined,
                size: 48, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text('No usage data yet',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            SizedBox(height: 6),
            Text(
              'API usage will appear here after the first\ncertificate import or AI-assisted action.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ]),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
}
