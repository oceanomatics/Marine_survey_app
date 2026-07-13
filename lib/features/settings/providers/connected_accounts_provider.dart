// lib/features/settings/providers/connected_accounts_provider.dart
//
// Phase 2 — data layer only (docs/TODO.md Phase 2 "Connected Accounts").
// Records which external account is connected for which purpose
// (correspondence/photos/documents), separate from google_auth_service's
// actual sign-in session — this provider does NOT drive which Google
// account is currently signed in, it's the durable record of intent
// that a future account-switching mechanism (built + tested with the
// surveyor present, on a real device) will read from.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';

enum AccountProviderType {
  google('google', 'Google'),
  microsoft('microsoft', 'Microsoft');

  const AccountProviderType(this.value, this.label);
  final String value;
  final String label;

  static AccountProviderType fromValue(String v) => values
      .firstWhere((e) => e.value == v, orElse: () => AccountProviderType.google);
}

enum AccountPurpose {
  correspondence('correspondence', 'Correspondence'),
  photos('photos', 'Photos'),
  documents('documents', 'Documents');

  const AccountPurpose(this.value, this.label);
  final String value;
  final String label;

  static AccountPurpose fromValue(String v) => values
      .firstWhere((e) => e.value == v, orElse: () => AccountPurpose.correspondence);
}

@immutable
class ConnectedAccount {
  const ConnectedAccount({
    required this.id,
    required this.userId,
    required this.provider,
    required this.purpose,
    required this.accountEmail,
    this.oauthClientId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final AccountProviderType provider;
  final AccountPurpose purpose;
  final String accountEmail;

  /// Per-surveyor "bring your own OAuth client" override — null means use
  /// the app's shared default. Only honoured on iOS/web with the current
  /// google_sign_in plugin (Android reads its client from google-services
  /// .json at build time, not this value) — see migration 049.
  final String? oauthClientId;
  final DateTime createdAt;

  factory ConnectedAccount.fromJson(Map<String, dynamic> j) => ConnectedAccount(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        provider: AccountProviderType.fromValue(j['provider'] as String),
        purpose: AccountPurpose.fromValue(j['purpose'] as String),
        accountEmail: j['account_email'] as String,
        oauthClientId: j['oauth_client_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

final connectedAccountsProvider =
    AsyncNotifierProvider<ConnectedAccountsNotifier, List<ConnectedAccount>>(
  ConnectedAccountsNotifier.new,
);

class ConnectedAccountsNotifier extends AsyncNotifier<List<ConnectedAccount>> {
  @override
  Future<List<ConnectedAccount>> build() => _fetch();

  Future<List<ConnectedAccount>> _fetch() async {
    final data = await SupabaseService.client
        .from('connected_accounts')
        .select()
        .eq('user_id', SupabaseService.userId)
        .order('created_at');
    return (data as List)
        .map((e) => ConnectedAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// One connected account per purpose per user (DB unique constraint) —
  /// upserts on (user_id, purpose).
  Future<void> connect({
    required AccountProviderType provider,
    required AccountPurpose purpose,
    required String accountEmail,
    String? oauthClientId,
  }) async {
    final row = await SupabaseService.client
        .from('connected_accounts')
        .upsert({
          'user_id': SupabaseService.userId,
          'provider': provider.value,
          'purpose': purpose.value,
          'account_email': accountEmail,
          'oauth_client_id': oauthClientId,
        }, onConflict: 'user_id,purpose')
        .select()
        .single();

    final updated = ConnectedAccount.fromJson(row);
    final current = state.value ?? [];
    state = AsyncData([
      ...current.where((a) => a.purpose != purpose),
      updated,
    ]);
  }

  Future<void> disconnect(AccountPurpose purpose) async {
    await SupabaseService.client
        .from('connected_accounts')
        .delete()
        .eq('user_id', SupabaseService.userId)
        .eq('purpose', purpose.value);
    final current = state.value ?? [];
    state = AsyncData(current.where((a) => a.purpose != purpose).toList());
  }

  ConnectedAccount? forPurpose(AccountPurpose purpose) =>
      (state.value ?? []).where((a) => a.purpose == purpose).firstOrNull;
}
