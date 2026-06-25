// lib/features/settings/screens/account_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/account_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/save_bar.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _profileDirty = false;
  bool _savingProfile = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _loadProfile(AccountState s) {
    _nameCtrl.text    = s.name;
    _emailCtrl.text   = s.email;
    _phoneCtrl.text   = s.phone;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
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

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: const Text('Account'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.go('/cases'),
            ),
          ),
          bottomNavigationBar: SaveBar(
            visible: _profileDirty,
            saving: _savingProfile,
            onSave: _saveProfile,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Surveyor Profile ──────────────────────────────────────
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

              // ── API Keys ──────────────────────────────────────────────
              const _SectionHeader(
                icon: Icons.key_outlined,
                color: AppColors.teal,
                title: 'API Status',
              ),
              const SizedBox(height: 10),
              _ApiKeyCard(),

              const SizedBox(height: 24),

              // ── Speech & Transcription ────────────────────────────────
              const _SectionHeader(
                icon: Icons.mic_outlined,
                color: AppColors.purple,
                title: 'Speech & Transcription',
              ),
              const SizedBox(height: 10),
              _NavTile(
                icon:     Icons.record_voice_over_outlined,
                label:    'Speech Models & Settings',
                subtitle: 'Choose model, decoding method, endpoint sensitivity',
                onTap:    () => context.go('/speech-settings'),
              ),

              const SizedBox(height: 24),

              // ── External Accounts ─────────────────────────────────────
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
              const SizedBox(height: 32),
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
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
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
          decoration: dec('Office / Postal Address',
              icon: Icons.location_on_outlined),
        ),
      ]),
    );
  }
}

// ── API key card ───────────────────────────────────────────────────────────

class _ApiKeyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const key = AppConfig.anthropicApiKey;
    final masked = key.length > 6
        ? '••••••••••${key.substring(key.length - 6)}'
        : key.isEmpty
            ? 'Not configured'
            : '••••••';

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
            color: AppColors.lightTeal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.psychology_outlined,
              size: 18, color: AppColors.teal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Anthropic (Claude)',
                  style: TextStyle(
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
            color: key.isNotEmpty ? AppColors.lightTeal : AppColors.lightCoral,
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
      ]),
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
              child:
                  Text('Delete', style: TextStyle(color: AppColors.error)),
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
        id:       widget.existing?.id,
        type:     _type,
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
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700),
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
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
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
  final IconData     icon;
  final String       label;
  final String       subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: AppColors.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        AppColors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.purple),
            ),
            title: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.textTertiary),
            onTap: onTap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
}
