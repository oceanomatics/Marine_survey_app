import 'package:marine_survey_app/features/settings/providers/account_provider.dart';

class FakeAccountNotifier extends AccountNotifier {
  FakeAccountNotifier([this._seed = const AccountState()]);
  final AccountState _seed;

  @override
  Future<AccountState> build() async => _seed;
}
