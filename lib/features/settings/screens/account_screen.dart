// lib/features/settings/screens/account_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/account_provider.dart';
import '../../../core/services/biometric_lock_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/save_bar.dart';
import '../../../shared/widgets/app_feedback.dart';
import 'organisation_list_screen.dart' show OrganisationsTabBody, createOrganisation;

/// Unified Account & Organisation Settings — Surveyor / Organisations /
/// Connectivity tabs (14 July 2026 walkthrough — a repeat complaint; this
/// was previously split across this screen and a separate Organisations
/// route/screen, which TODO.md §2.16 recorded as a deliberate deferral the
/// surveyor said was "not acceptable, wants it done"). Route/class name
/// (`/account`, AccountScreen) kept as-is — only the content changed —
/// so nothing else that links here needs updating.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _profileDirty = false;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _loadProfile(AccountState s) {
    _nameCtrl.text = s.name;
    _emailCtrl.text = s.email;
    _phoneCtrl.text = s.phone;
    _addressCtrl.text = s.address;
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      await ref.read(accountProvider.notifier).saveProfile(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
          );
      if (mounted) {
        setState(() => _profileDirty = false);
        showSavedToast(context, label: 'Profile saved');
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(accountProvider);

    return accountAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Account'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/cases'),
          ),
        ),
        body: Center(child: Text('Error: $e')),
      ),
      data: (account) {
        // Populate fields on first load without marking dirty
        if (_nameCtrl.text.isEmpty && account.name.isNotEmpty) {
          _loadProfile(account);
        }

        final onOrgTab = _tab.index == 1;

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: const Text('Account & Organisation'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.go('/cases'),
            ),
            bottom: TabBar(
              controller: _tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Surveyor'),
                Tab(text: 'Organisations'),
                Tab(text: 'Connectivity'),
              ],
            ),
          ),
          floatingActionButton: onOrgTab
              ? FloatingActionButton.extended(
                  onPressed: () => createOrganisation(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('New Organisation'),
                )
              : null,
          bottomNavigationBar: onOrgTab
              ? null
              : SaveBar(
                  visible: _profileDirty,
                  saving: _savingProfile,
                  onSave: _saveProfile,
                ),
          body: TabBarView(
            controller: _tab,
            children: [
              // ── Tab 1: Surveyor ───────────────────────────────────────
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _SectionHeader(
                    icon: Icons.person_outline,
                    color: AppColors.midBlue,
                    title: 'Surveyor Profile',
                  ),
                  const SizedBox(height: 10),
                  _ProfileCard(
                    nameCtrl: _nameCtrl,
                    emailCtrl: _emailCtrl,
                    phoneCtrl: _phoneCtrl,
                    addressCtrl: _addressCtrl,
                    onChanged: () => setState(() => _profileDirty = true),
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    icon: Icons.fingerprint,
                    color: AppColors.purple,
                    title: 'App Lock',
                  ),
                  const SizedBox(height: 10),
                  const _BiometricLockCard(),
                  const SizedBox(height: 32),
                ],
              ),

              // ── Tab 2: Organisations ──────────────────────────────────
              const OrganisationsTabBody(),

              // ── Tab 3: Connectivity ───────────────────────────────────
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  const _SectionHeader(
                    icon: Icons.key_outlined,
                    color: AppColors.teal,
                    title: 'API Keys',
                  ),
                  const SizedBox(height: 10),
                  _ApiKeyEditCard(
                    title: 'Anthropic (Claude)',
                    subtitle: 'Used for AI document extraction, drafting and '
                        'OCR throughout the app. Get a key at console.anthropic.com.',
                    icon: Icons.psychology_outlined,
                    iconColor: AppColors.teal,
                    currentKey: account.anthropicApiKey,
                    onSave: (v) => ref
                        .read(accountProvider.notifier)
                        .saveAnthropicApiKey(v),
                  ),
                  const SizedBox(height: 10),
                  _ApiKeyEditCard(
                    title: 'OpenAI',
                    subtitle: 'Reserved for OpenAI-based features. '
                        'Get a key at platform.openai.com.',
                    icon: Icons.auto_awesome_outlined,
                    iconColor: AppColors.purple,
                    currentKey: account.openAiApiKey,
                    onSave: (v) =>
                        ref.read(accountProvider.notifier).saveOpenAiApiKey(v),
                  ),
                  const SizedBox(height: 10),
                  _ApiKeyEditCard(
                    title: 'Google',
                    subtitle: 'Reserved for Google Maps/Places features. '
                        'Get a key at console.cloud.google.com.',
                    icon: Icons.map_outlined,
                    iconColor: AppColors.midBlue,
                    currentKey: account.googleApiKey,
                    onSave: (v) =>
                        ref.read(accountProvider.notifier).saveGoogleApiKey(v),
                  ),

                  const SizedBox(height: 24),

                  const _SectionHeader(
                    icon: Icons.folder_shared_outlined,
                    color: AppColors.amber,
                    title: 'Cloud Storage',
                  ),
                  const SizedBox(height: 10),
                  _ApiKeyEditCard(
                    title: 'Drive Base Folder',
                    subtitle: 'Root folder name in your Google Drive under which '
                        'Cases/ and Admin/ are created — all case photos, '
                        'correspondence, documents and reports are stored there. '
                        'Leave blank to use "My Drive" root directly.',
                    icon: Icons.folder_shared_outlined,
                    iconColor: AppColors.amber,
                    currentKey: account.driveBaseFolder,
                    secret: false,
                    fieldLabel: 'Folder name',
                    saveLabel: 'Save Folder',
                    notSetLabel: 'Not set',
                    onSave: (v) => ref
                        .read(accountProvider.notifier)
                        .saveDriveBaseFolder(v),
                  ),

                  const SizedBox(height: 24),

                  const _SectionHeader(
                    icon: Icons.currency_exchange_outlined,
                    color: AppColors.teal,
                    title: 'FX Rates',
                  ),
                  const SizedBox(height: 10),
                  _ApiKeyEditCard(
                    title: 'openexchangerates.org',
                    subtitle: 'Free-tier App ID from openexchangerates.org, '
                        'used for FX rate conversion.',
                    icon: Icons.currency_exchange_outlined,
                    iconColor: AppColors.teal,
                    currentKey: account.fxApiKey,
                    onSave: (v) =>
                        ref.read(accountProvider.notifier).saveFxApiKey(v),
                  ),

                  const SizedBox(height: 24),

                  const _SectionHeader(
                    icon: Icons.mic_outlined,
                    color: AppColors.purple,
                    title: 'Speech & Transcription',
                  ),
                  const SizedBox(height: 10),
                  _NavTile(
                    icon: Icons.record_voice_over_outlined,
                    label: 'Speech Models & Settings',
                    subtitle:
                        'Choose model, decoding method, endpoint sensitivity',
                    onTap: () => context.go('/speech-settings'),
                  ),

                  const SizedBox(height: 24),

                  const _SectionHeader(
                    icon: Icons.manage_accounts_outlined,
                    color: AppColors.amber,
                    title: 'External Accounts',
                  ),
                  const SizedBox(height: 10),
                  if (account.externalAccounts.isEmpty)
                    _EmptyAccounts()
                  else
                    ...account.externalAccounts.map((a) => _AccountCard(
                          account: a,
                          onEdit: () => _showAccountSheet(context, a),
                          onDelete: () => _confirmDelete(context, a),
                        )),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showAccountSheet(context, null),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.amber,
                      side: const BorderSide(color: AppColors.amber),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAccountSheet(BuildContext context, ExternalAccount? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountSheet(
        existing: existing,
        onSave: (account) async {
          if (existing == null) {
            await ref.read(accountProvider.notifier).addAccount(account);
          } else {
            await ref.read(accountProvider.notifier).updateAccount(account);
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, ExternalAccount account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Remove "${account.label}" credentials?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(accountProvider.notifier).deleteAccount(account.id);
            },
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Biometric app-lock toggle ──────────────────────────────────────────────
// 14 July 2026 walkthrough — "add a 2FA toggle... biometrics accepted as
// the second factor, not just OTP/authenticator". This is a local device
// gate (Face ID/fingerprint/Windows Hello via local_auth), checked at app
// start and on every resume — see biometric_lock_gate.dart.

class _BiometricLockCard extends StatefulWidget {
  const _BiometricLockCard();

  @override
  State<_BiometricLockCard> createState() => _BiometricLockCardState();
}

class _BiometricLockCardState extends State<_BiometricLockCard> {
  bool _loading = true;
  bool _supported = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supported = await BiometricLockService.isSupported();
    final enabled = await BiometricLockService.isEnabled();
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      // Verify biometrics actually work on this device before committing
      // to the setting — otherwise a broken sensor could lock the
      // surveyor out with no way back in.
      final ok = await BiometricLockService.authenticate();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Could not verify biometrics — app lock not enabled.')));
        }
        return;
      }
    }
    await BiometricLockService.setEnabled(value);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.fingerprint,
              size: 18, color: AppColors.purple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Require biometric unlock',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(
                _supported
                    ? 'Face ID / fingerprint / device credential, checked at '
                        'app start and on resume.'
                    : 'No biometrics available on this device.',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Switch(
          value: _enabled,
          onChanged: _supported ? _toggle : null,
        ),
      ]),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
  });
  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    ]);
  }
}

// ── Profile card ───────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.onChanged,
  });
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.midBlue, width: 1.5),
    );
    InputDecoration dec(String label, {IconData? icon}) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          border: border,
          enabledBorder: border,
          focusedBorder: focusBorder,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          prefixIcon: icon != null
              ? Icon(icon, size: 16, color: AppColors.textTertiary)
              : null,
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        TextField(
          controller: nameCtrl,
          onChanged: (_) => onChanged(),
          style: const TextStyle(fontSize: 13),
          decoration: dec('Full Name', icon: Icons.person_outline),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: emailCtrl,
          onChanged: (_) => onChanged(),
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 13),
          decoration: dec('Email Address', icon: Icons.email_outlined),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: phoneCtrl,
          onChanged: (_) => onChanged(),
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 13),
          decoration: dec('Phone Number', icon: Icons.phone_outlined),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: addressCtrl,
          onChanged: (_) => onChanged(),
          minLines: 2,
          maxLines: 4,
          style: const TextStyle(fontSize: 13),
          decoration:
              dec('Office / Postal Address', icon: Icons.location_on_outlined),
        ),
      ]),
    );
  }
}

// ── API key edit card ──────────────────────────────────────────────────────
// Shared by every service key on this screen (Anthropic, OpenAI, Google, FX).
// Keys are synced to the `profiles` table (see AccountNotifier) so they can
// be changed here without a rebuild, rather than baked in via --dart-define.
// Also reused for non-secret single values (e.g. the Drive base folder) via
// `secret: false`, which turns off masking/obscuring and relabels the field.

class _ApiKeyEditCard extends ConsumerStatefulWidget {
  const _ApiKeyEditCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.currentKey,
    required this.onSave,
    this.secret = true,
    this.fieldLabel = 'API Key',
    this.saveLabel = 'Save API Key',
    this.notSetLabel = 'Not configured',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String currentKey;
  final Future<void> Function(String key) onSave;

  /// Whether the stored value is a secret (masked in the summary and obscured
  /// while editing). Set false for non-sensitive values like a folder name.
  final bool secret;

  /// Label on the edit field (e.g. "API Key" vs "Folder name").
  final String fieldLabel;

  /// Label on the save button (e.g. "Save API Key" vs "Save Folder").
  final String saveLabel;

  /// Summary wording when nothing is stored yet ("Not configured" / "Not set").
  final String notSetLabel;

  @override
  ConsumerState<_ApiKeyEditCard> createState() => _ApiKeyEditCardState();
}

class _ApiKeyEditCardState extends ConsumerState<_ApiKeyEditCard> {
  final _ctrl = TextEditingController();
  bool _editing = false;
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_ctrl.text.trim());
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.currentKey;
    final String masked;
    if (key.isEmpty) {
      masked = widget.notSetLabel;
    } else if (!widget.secret) {
      // Non-secret values (e.g. a folder name) are shown in the clear.
      masked = key;
    } else if (key.length > 6) {
      masked = '••••••••••${key.substring(key.length - 6)}';
    } else {
      masked = '••••••';
    }

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: widget.iconColor, width: 1.5),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, size: 18, color: widget.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    masked,
                    style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    key.isNotEmpty ? AppColors.lightTeal : AppColors.lightCoral,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                key.isNotEmpty ? 'Active' : 'Missing',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: key.isNotEmpty ? AppColors.teal : AppColors.coral,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _editing ? Icons.close : Icons.edit_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _editing = !_editing;
                  if (_editing) _ctrl.text = key;
                });
              },
            ),
          ]),
          if (_editing) ...[
            const SizedBox(height: 12),
            Text(
              widget.subtitle,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              obscureText: widget.secret && _obscure,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: widget.fieldLabel,
                labelStyle: const TextStyle(fontSize: 12),
                border: border,
                enabledBorder: border,
                focusedBorder: focusBorder,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: widget.secret
                    ? IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.iconColor,
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(widget.saveLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── External account card ──────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onEdit,
    required this.onDelete,
  });
  final ExternalAccount account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.lightAmber,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              account.label.isEmpty ? '?' : account.label[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.amber,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                account.username,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert,
              size: 18, color: AppColors.textSecondary),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ]),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyAccounts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(children: [
        Icon(Icons.lock_outline, size: 20, color: AppColors.textTertiary),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'No external accounts saved yet. Add Equasis or other site credentials here.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ]),
    );
  }
}

// ── Add/edit account bottom sheet ─────────────────────────────────────────

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({this.existing, required this.onSave});
  final ExternalAccount? existing;
  final Future<void> Function(ExternalAccount) onSave;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  late ExternalAccountType _type;
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _type = a?.type ?? ExternalAccountType.equasis;
    if (a != null) {
      _usernameCtrl.text = a.username;
      _passwordCtrl.text = a.password;
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_usernameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username / email is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final account = ExternalAccount(
        id: widget.existing?.id,
        type: _type,
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await widget.onSave(account);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
    );
    InputDecoration dec(String label) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          border: border,
          enabledBorder: border,
          focusedBorder: focusBorder,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        );

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.existing == null ? 'Add Account' : 'Edit Account',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Credentials are stored securely on this device.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: dec('Account type'),
            child: DropdownButton<ExternalAccountType>(
              value: _type,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              items: ExternalAccountType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _usernameCtrl,
            style: const TextStyle(fontSize: 13),
            keyboardType: TextInputType.emailAddress,
            decoration: dec('Username / Email'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordCtrl,
            style: const TextStyle(fontSize: 13),
            obscureText: _obscurePassword,
            decoration: dec('Password').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(widget.existing == null ? 'Add Account' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navigation tile ────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.purple),
            ),
            title: Text(label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: onTap,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
}
