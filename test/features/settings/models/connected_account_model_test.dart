// Phase 2 (13 July 2026): connected accounts data model — pure parsing
// logic only, no provider/UI test yet since nothing consumes this
// provider in a screen (see docs/TODO.md Phase 2 "Connected Accounts").
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/settings/providers/connected_accounts_provider.dart';

void main() {
  group('AccountProviderType.fromValue', () {
    test('resolves known values', () {
      expect(AccountProviderType.fromValue('google'), AccountProviderType.google);
      expect(
          AccountProviderType.fromValue('microsoft'), AccountProviderType.microsoft);
    });

    test('falls back to google for an unknown value', () {
      expect(AccountProviderType.fromValue('yahoo'), AccountProviderType.google);
    });
  });

  group('AccountPurpose.fromValue', () {
    test('resolves known values', () {
      expect(AccountPurpose.fromValue('correspondence'), AccountPurpose.correspondence);
      expect(AccountPurpose.fromValue('photos'), AccountPurpose.photos);
      expect(AccountPurpose.fromValue('documents'), AccountPurpose.documents);
    });

    test('falls back to correspondence for an unknown value', () {
      expect(AccountPurpose.fromValue('calendar'), AccountPurpose.correspondence);
    });
  });

  group('ConnectedAccount.fromJson', () {
    test('parses a full row', () {
      final account = ConnectedAccount.fromJson(const {
        'id': 'acc-1',
        'user_id': 'user-1',
        'provider': 'google',
        'purpose': 'correspondence',
        'account_email': 'plc@oceanomatics.com.au',
        'oauth_client_id': null,
        'created_at': '2026-07-13T00:00:00Z',
      });

      expect(account.id, 'acc-1');
      expect(account.provider, AccountProviderType.google);
      expect(account.purpose, AccountPurpose.correspondence);
      expect(account.accountEmail, 'plc@oceanomatics.com.au');
      expect(account.oauthClientId, isNull);
    });

    test('parses an optional oauth_client_id when present', () {
      final account = ConnectedAccount.fromJson(const {
        'id': 'acc-2',
        'user_id': 'user-1',
        'provider': 'microsoft',
        'purpose': 'documents',
        'account_email': 'surveyor@firm.com',
        'oauth_client_id': 'firm-specific-client-id',
        'created_at': '2026-07-13T00:00:00Z',
      });

      expect(account.provider, AccountProviderType.microsoft);
      expect(account.oauthClientId, 'firm-specific-client-id');
    });
  });
}
