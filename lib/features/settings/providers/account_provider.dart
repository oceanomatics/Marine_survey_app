// lib/features/settings/providers/account_provider.dart
//
// Manages surveyor profile and external service credentials.
// Profile fields sync to Supabase `profiles` table; SharedPreferences is the
// offline cache. External account passwords stay in flutter_secure_storage only
// — credentials are never sent to the remote database.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/config/app_config.dart';

// ── External account type ──────────────────────────────────────────────────

enum ExternalAccountType {
  equasis('Equasis'),
  dnv('DNV'),
  bureauVeritas('Bureau Veritas'),
  lloyds("Lloyd's Register"),
  marineTraffic('MarineTraffic'),
  clarkson('Clarkson Research'),
  other('Other');

  const ExternalAccountType(this.displayName);
  final String displayName;

  // Resolve from whatever string is stored in the DB (old free-text or enum name).
  static ExternalAccountType fromStoredLabel(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.isEmpty) return ExternalAccountType.other;
    // Match by enum .name first (new format), then by displayName, then by
    // substring so old free-text entries like "equasis.org" still resolve.
    for (final t in values) {
      if (t.name.toLowerCase() == lower) return t;
    }
    for (final t in values) {
      if (t.displayName.toLowerCase() == lower) return t;
    }
    for (final t in values) {
      if (lower.contains(t.name.toLowerCase())) return t;
    }
    return ExternalAccountType.other;
  }
}

// ── External account model ─────────────────────────────────────────────────

class ExternalAccount {
  ExternalAccount({
    String? id,
    required this.type,
    required this.username,
    required this.password,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final ExternalAccountType type;
  final String username;
  final String password;

  String get label => type.displayName;
  bool get isEquasis => type == ExternalAccountType.equasis;

  ExternalAccount copyWith({
    ExternalAccountType? type,
    String? username,
    String? password,
  }) =>
      ExternalAccount(
        id: id,
        type: type ?? this.type,
        username: username ?? this.username,
        password: password ?? this.password,
      );

  factory ExternalAccount.fromJson(Map<String, dynamic> j) => ExternalAccount(
        id: j['id'] as String?,
        type: ExternalAccountType.fromStoredLabel(j['label'] as String? ?? ''),
        username: j['username'] as String? ?? '',
        password: j['password'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': type.name, // store the enum name — consistent key
        'url': '',
        'username': username,
        'password': password,
      };
}

// ── Account state ──────────────────────────────────────────────────────────

class AccountState {
  const AccountState({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.externalAccounts = const [],
    this.fxApiKey = '',
    this.anthropicApiKey = '',
    this.openAiApiKey = '',
    this.googleApiKey = '',
    this.driveBaseFolder = '',
  });

  final String name;
  final String email;
  final String phone;
  final String address;
  final List<ExternalAccount> externalAccounts;

  /// openexchangerates.org App ID (free tier).
  final String fxApiKey;
  final String anthropicApiKey;
  final String openAiApiKey;
  final String googleApiKey;

  /// Root Drive folder name under which Cases/ and Admin/ live — empty
  /// means directly under "My Drive" (see DriveStorageService).
  final String driveBaseFolder;

  bool get hasFxApiKey => fxApiKey.isNotEmpty;

  AccountState copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    List<ExternalAccount>? externalAccounts,
    String? fxApiKey,
    String? anthropicApiKey,
    String? openAiApiKey,
    String? googleApiKey,
    String? driveBaseFolder,
  }) =>
      AccountState(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        externalAccounts: externalAccounts ?? this.externalAccounts,
        fxApiKey: fxApiKey ?? this.fxApiKey,
        anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
        openAiApiKey: openAiApiKey ?? this.openAiApiKey,
        googleApiKey: googleApiKey ?? this.googleApiKey,
        driveBaseFolder: driveBaseFolder ?? this.driveBaseFolder,
      );

  ExternalAccount? get equasisAccount =>
      externalAccounts.where((a) => a.isEquasis).firstOrNull;
}

// ── Notifier ───────────────────────────────────────────────────────────────

class AccountNotifier extends AsyncNotifier<AccountState> {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<AccountState> build() => _load();

  Future<AccountState> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = await _storage.read(key: 'external_accounts') ?? '[]';
    final fxApiKey = await _storage.read(key: 'fx_api_key') ?? '';
    final accounts = (jsonDecode(accountsJson) as List)
        .map((e) => ExternalAccount.fromJson(e as Map<String, dynamic>))
        .toList();

    // Try remote first; fall back to local cache if offline or error.
    String name = prefs.getString('profile_name') ?? '';
    String email = prefs.getString('profile_email') ?? '';
    String phone = prefs.getString('profile_phone') ?? '';
    String address = prefs.getString('profile_address') ?? '';
    List<ExternalAccount> remoteAccounts = accounts; // default to local

    // API keys — local secure-storage cache is the offline fallback; the
    // `profiles` row (synced across devices/builds) wins when reachable.
    String anthropicApiKey =
        await _storage.read(key: 'anthropic_api_key') ?? '';
    String openAiApiKey = await _storage.read(key: 'openai_api_key') ?? '';
    String googleApiKey = await _storage.read(key: 'google_api_key') ?? '';
    String driveBaseFolder = prefs.getString('drive_base_folder') ?? '';

    try {
      final userId = SupabaseService.userId;

      // Profile
      final row = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row != null) {
        name = row['name'] as String? ?? name;
        email = row['email'] as String? ?? email;
        phone = row['phone'] as String? ?? phone;
        address = row['address'] as String? ?? address;
        await prefs.setString('profile_name', name);
        await prefs.setString('profile_email', email);
        await prefs.setString('profile_phone', phone);
        await prefs.setString('profile_address', address);

        final remoteAnthropic = row['anthropic_api_key'] as String?;
        final remoteOpenAi = row['openai_api_key'] as String?;
        final remoteGoogle = row['google_api_key'] as String?;
        final remoteDriveBase = row['drive_base_folder'] as String?;
        if (remoteAnthropic != null && remoteAnthropic.isNotEmpty) {
          anthropicApiKey = remoteAnthropic;
          await _storage.write(
              key: 'anthropic_api_key', value: remoteAnthropic);
        }
        if (remoteOpenAi != null && remoteOpenAi.isNotEmpty) {
          openAiApiKey = remoteOpenAi;
          await _storage.write(key: 'openai_api_key', value: remoteOpenAi);
        }
        if (remoteGoogle != null && remoteGoogle.isNotEmpty) {
          googleApiKey = remoteGoogle;
          await _storage.write(key: 'google_api_key', value: remoteGoogle);
        }
        if (remoteDriveBase != null && remoteDriveBase.isNotEmpty) {
          driveBaseFolder = remoteDriveBase;
          await prefs.setString('drive_base_folder', remoteDriveBase);
        }
      }

      // External accounts
      final rows = await SupabaseService.client
          .from('external_accounts')
          .select()
          .eq('user_id', userId)
          .order('created_at');
      remoteAccounts = (rows as List)
          .map((r) => ExternalAccount.fromJson(r as Map<String, dynamic>))
          .toList();
      // Keep secure storage in sync for offline use.
      final json = jsonEncode(remoteAccounts.map((a) => a.toJson()).toList());
      await _storage.write(key: 'external_accounts', value: json);
    } catch (_) {
      // Offline or not authenticated — use cached values above.
    }

    // Make the keys available to the AI/service clients for the rest of
    // this app session (they read AppConfig fresh on every request).
    if (anthropicApiKey.isNotEmpty) AppConfig.anthropicApiKey = anthropicApiKey;
    if (openAiApiKey.isNotEmpty) AppConfig.openAiApiKey = openAiApiKey;
    if (googleApiKey.isNotEmpty) AppConfig.googleApiKey = googleApiKey;
    AppConfig.driveBaseFolder =
        driveBaseFolder.isNotEmpty ? driveBaseFolder : null;

    return AccountState(
      name: name,
      email: email,
      phone: phone,
      address: address,
      externalAccounts: remoteAccounts,
      fxApiKey: fxApiKey,
      anthropicApiKey: anthropicApiKey,
      openAiApiKey: openAiApiKey,
      googleApiKey: googleApiKey,
      driveBaseFolder: driveBaseFolder,
    );
  }

  Future<void> saveFxApiKey(String key) async {
    await _storage.write(key: 'fx_api_key', value: key);
    final cur = state.value ?? const AccountState();
    state = AsyncData(cur.copyWith(fxApiKey: key));
  }

  Future<void> _saveServiceApiKey({
    required String column,
    required String storageKey,
    required String key,
    required AccountState Function(AccountState cur) applyToState,
  }) async {
    await _storage.write(key: storageKey, value: key);
    await SupabaseService.client.from('profiles').upsert({
      'user_id': SupabaseService.userId,
      column: key,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    final cur = state.value ?? const AccountState();
    state = AsyncData(applyToState(cur));
  }

  Future<void> saveAnthropicApiKey(String key) async {
    AppConfig.anthropicApiKey = key;
    await _saveServiceApiKey(
      column: 'anthropic_api_key',
      storageKey: 'anthropic_api_key',
      key: key,
      applyToState: (cur) => cur.copyWith(anthropicApiKey: key),
    );
  }

  Future<void> saveOpenAiApiKey(String key) async {
    AppConfig.openAiApiKey = key;
    await _saveServiceApiKey(
      column: 'openai_api_key',
      storageKey: 'openai_api_key',
      key: key,
      applyToState: (cur) => cur.copyWith(openAiApiKey: key),
    );
  }

  Future<void> saveGoogleApiKey(String key) async {
    AppConfig.googleApiKey = key;
    await _saveServiceApiKey(
      column: 'google_api_key',
      storageKey: 'google_api_key',
      key: key,
      applyToState: (cur) => cur.copyWith(googleApiKey: key),
    );
  }

  Future<void> saveDriveBaseFolder(String folder) async {
    AppConfig.driveBaseFolder = folder.isNotEmpty ? folder : null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('drive_base_folder', folder);
    await SupabaseService.client.from('profiles').upsert({
      'user_id': SupabaseService.userId,
      'drive_base_folder': folder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    final cur = state.value ?? const AccountState();
    state = AsyncData(cur.copyWith(driveBaseFolder: folder));
  }

  Future<void> saveProfile({
    required String name,
    required String email,
    required String phone,
    required String address,
  }) async {
    // Write to local cache first so the UI is never blocked by network.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', name);
    await prefs.setString('profile_email', email);
    await prefs.setString('profile_phone', phone);
    await prefs.setString('profile_address', address);

    // Upsert to Supabase.
    await SupabaseService.client.from('profiles').upsert({
      'user_id': SupabaseService.userId,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    final cur = state.value ?? const AccountState();
    state = AsyncData(
        cur.copyWith(name: name, email: email, phone: phone, address: address));
  }

  Future<void> _persistAccounts(List<ExternalAccount> accounts) async {
    // Local secure storage cache.
    final json = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: 'external_accounts', value: json);
    final cur = state.value ?? const AccountState();
    state = AsyncData(cur.copyWith(externalAccounts: accounts));
  }

  Future<void> addAccount(ExternalAccount account) async {
    final userId = SupabaseService.userId;
    await SupabaseService.client.from('external_accounts').insert({
      ...account.toJson(),
      'user_id': userId,
    });
    final current = [
      ...(state.value?.externalAccounts ?? <ExternalAccount>[]),
      account
    ];
    await _persistAccounts(current);
  }

  Future<void> updateAccount(ExternalAccount updated) async {
    final json = updated.toJson()..remove('id');
    await SupabaseService.client
        .from('external_accounts')
        .update(json)
        .eq('id', updated.id);
    final current = (state.value?.externalAccounts ?? [])
        .map((a) => a.id == updated.id ? updated : a)
        .toList();
    await _persistAccounts(current);
  }

  Future<void> deleteAccount(String id) async {
    await SupabaseService.client
        .from('external_accounts')
        .delete()
        .eq('id', id);
    final current =
        (state.value?.externalAccounts ?? []).where((a) => a.id != id).toList();
    await _persistAccounts(current);
  }
}

final accountProvider =
    AsyncNotifierProvider<AccountNotifier, AccountState>(AccountNotifier.new);
