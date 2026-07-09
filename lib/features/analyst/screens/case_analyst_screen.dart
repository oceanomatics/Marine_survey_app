// lib/features/analyst/screens/case_analyst_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/supabase_client.dart';
import '../../../core/services/model_manager.dart';
import '../../../core/services/sherpa_service.dart';
import '../../settings/providers/speech_settings_provider.dart';
import '../../../core/services/case_context_builder.dart';
import '../../../features/accounts/providers/accounts_provider.dart';
import '../../../features/cases/providers/cases_provider.dart';
import '../../../features/survey/providers/damage_provider.dart';
import '../../../features/surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../../features/vessel/providers/vessel_provider.dart' show vesselForCaseProvider;
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/back_app_bar.dart';

// ── Accent colour ─────────────────────────────────────────────────────────

const _kAccent = Color(0xFF1E3A5F);

// ── Screen ────────────────────────────────────────────────────────────────

class CaseAnalystScreen extends ConsumerStatefulWidget {
  const CaseAnalystScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<CaseAnalystScreen> createState() => _CaseAnalystScreenState();
}

class _CaseAnalystScreenState extends ConsumerState<CaseAnalystScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _sherpa     = SherpaService.instance;

  final List<_Msg> _messages = [];
  bool _sending   = false;
  bool _listening = false;
  bool _modelReady = false;

  StreamSubscription<SherpaResult>? _sherpaSub;
  String _committedText = '';

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    if (_sherpa.isInitialized) {
      if (mounted) setState(() => _modelReady = true);
      return;
    }
    try {
      final settings = await ref.read(speechSettingsProvider.future);
      final paths    = await ModelManager.instance.ensureModel(settings.modelId);
      await _sherpa.initialize(paths, settings);
      if (mounted) setState(() => _modelReady = true);
    } catch (_) {
      // Voice input unavailable — chat still works
    }
  }

  @override
  void dispose() {
    _sherpaSub?.cancel();
    _sherpa.stop();
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _buildContext() {
    return CaseContextBuilder.build(
      caseData: ref.read(caseProvider(widget.caseId)).valueOrNull,
      vessel: ref.read(vesselForCaseProvider(widget.caseId)).valueOrNull,
      damage: ref.read(damageProvider(widget.caseId)).valueOrNull,
      notes: ref.read(surveyorNotesProvider(widget.caseId)).valueOrNull,
      repairDocuments: ref.read(repairDocumentsProvider(widget.caseId)).valueOrNull,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send ─────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _sending) return;
    _controller.clear();

    setState(() {
      _messages.add(_Msg(role: 'user', content: q));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final context = _buildContext();
      // Build history excluding the message we just added
      final history = _messages
          .sublist(0, _messages.length - 1)
          .where((m) => m.role != 'error')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final result = await SupabaseService.client.functions.invoke(
        'case-analyst',
        body: {
          'question': q,
          'context': context,
          'history': history,
          'case_id': widget.caseId,
        },
      );

      final data = result.data as Map<String, dynamic>?;
      if (data == null || data['reply'] == null) {
        throw Exception(data?['error'] ?? 'No response from server');
      }
      setState(() => _messages.add(
            _Msg(role: 'assistant', content: data['reply'] as String),
          ));
    } catch (e) {
      setState(() => _messages.add(
            _Msg(role: 'error', content: 'Error: $e'),
          ));
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  // ── Voice ─────────────────────────────────────────────────────────────────

  Future<void> _toggleVoice() async {
    if (_listening) {
      final trailing = await _sherpa.stop();
      _sherpaSub?.cancel();
      _sherpaSub = null;
      if (trailing.isNotEmpty) {
        final existing = _controller.text.trimRight();
        _controller.text =
            existing.isEmpty ? trailing : '$existing $trailing';
      }
      setState(() => _listening = false);
      return;
    }

    if (!_modelReady) return;

    _committedText = _controller.text.trimRight();
    setState(() => _listening = true);
    _sherpaSub = _sherpa.startStreaming().listen((result) {
      final sep = _committedText.isEmpty ? '' : ' ';
      if (result.isFinal) {
        _committedText = '$_committedText$sep${result.text}';
        _controller.text = _committedText;
      } else {
        _controller.text = '$_committedText$sep${result.text}';
      }
      _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length));
    }, onDone: () {
      if (mounted) setState(() => _listening = false);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch providers so we know when they're loaded
    final caseAsync    = ref.watch(caseProvider(widget.caseId));
    final vesselAsync  = ref.watch(vesselForCaseProvider(widget.caseId));
    final damageAsync  = ref.watch(damageProvider(widget.caseId));
    final notesAsync   = ref.watch(surveyorNotesProvider(widget.caseId));
    final accountsAsync = ref.watch(repairDocumentsProvider(widget.caseId));

    final allLoaded = caseAsync.hasValue &&
        vesselAsync.hasValue &&
        damageAsync.hasValue &&
        notesAsync.hasValue &&
        accountsAsync.hasValue;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Case Analyst',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(
              allLoaded ? 'Context loaded — ask anything' : 'Loading case data…',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
        actions: [
          if (!allLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(
                    loaded: allLoaded,
                    onSuggestion: (q) {
                      _controller.text = q;
                      _send();
                    },
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _messages.length) {
                        return const _TypingIndicator();
                      }
                      return _Bubble(msg: _messages[i]);
                    },
                  ),
          ),
          _InputBar(
            controller: _controller,
            listening: _listening,
            sending: _sending,
            speechAvailable: _modelReady,
            enabled: allLoaded,
            onSend: _send,
            onVoice: _toggleVoice,
          ),
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────

class _Msg {
  const _Msg({required this.role, required this.content});
  final String role; // 'user' | 'assistant' | 'error'
  final String content;
}

// ── Chat bubble ───────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    final isError = msg.role == 'error';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2, right: 8),
              decoration: BoxDecoration(
                color: _kAccent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 15, color: Colors.white),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isUser
                    ? _kAccent
                    : isError
                        ? const Color(0xFFFFEDED)
                        : AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 2),
                  bottomRight: Radius.circular(isUser ? 2 : 12),
                ),
                border: isError
                    ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                    : !isUser
                        ? Border.all(color: AppColors.border)
                        : null,
              ),
              child: isUser || isError
                  ? Text(
                      msg.content,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isUser
                            ? Colors.white
                            : Colors.red.shade700,
                      ),
                    )
                  : MarkdownBody(
                      data: msg.content,
                      shrinkWrap: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textPrimary,
                        ),
                        h1: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                        h2: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                        h3: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                        strong: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        em: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary,
                        ),
                        code: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: _kAccent,
                          backgroundColor:
                              _kAccent.withValues(alpha: 0.08),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: _kAccent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _kAccent.withValues(alpha: 0.15)),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                                color: _kAccent.withValues(alpha: 0.4),
                                width: 3),
                          ),
                        ),
                        blockquote: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        listBullet: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        tableHead: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        tableBody: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                        horizontalRuleDecoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        pPadding: const EdgeInsets.only(bottom: 4),
                        h1Padding: const EdgeInsets.only(top: 8, bottom: 4),
                        h2Padding: const EdgeInsets.only(top: 6, bottom: 4),
                        h3Padding: const EdgeInsets.only(top: 4, bottom: 2),
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.auto_awesome, size: 15, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
                    final opacity = (0.3 + 0.7 * (0.5 - (t - 0.5).abs() * 2).clamp(0.0, 1.0));
                    return Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: opacity),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state with suggestions ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loaded, required this.onSuggestion});
  final bool loaded;
  final void Function(String) onSuggestion;

  static const _suggestions = [
    'What is the primary occurrence and its apparent cause?',
    'Summarise the damage register',
    'What context cues are flagged as important?',
    'Is there anything in the notes concerning average?',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 28, color: _kAccent),
            ),
            const SizedBox(height: 14),
            const Text(
              'Case Analyst',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _kAccent),
            ),
            const SizedBox(height: 6),
            Text(
              loaded
                  ? 'Ask anything about this case'
                  : 'Loading case data…',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            if (loaded) ...[
              const SizedBox(height: 20),
              ...List.generate(_suggestions.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => onSuggestion(_suggestions[i]),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _kAccent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _suggestions[i],
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_ios,
                              size: 10,
                              color: _kAccent.withValues(alpha: 0.5)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Input bar ──────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.listening,
    required this.sending,
    required this.speechAvailable,
    required this.enabled,
    required this.onSend,
    required this.onVoice,
  });

  final TextEditingController controller;
  final bool listening;
  final bool sending;
  final bool speechAvailable;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (speechAvailable)
            GestureDetector(
              onTap: enabled ? onVoice : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: listening
                      ? Colors.red.withValues(alpha: 0.1)
                      : _kAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: listening
                        ? Colors.red.withValues(alpha: 0.4)
                        : _kAccent.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  listening ? Icons.mic : Icons.mic_none,
                  size: 18,
                  color: listening ? Colors.red : _kAccent,
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: enabled
                    ? 'Ask a question about this case…'
                    : 'Loading case data…',
                hintStyle: const TextStyle(
                    fontSize: 13, color: AppColors.textTertiary),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kAccent, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: (enabled && !sending) ? onSend : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (enabled && !sending)
                    ? _kAccent
                    : _kAccent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      size: 17, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
