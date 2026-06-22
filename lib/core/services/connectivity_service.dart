// lib/core/services/connectivity_service.dart
//
// Wraps connectivity_plus into a simple StreamProvider<bool>.
// true  = at least one active network interface
// false = no connectivity

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  // Emit the current state immediately so listeners start informed
  final initial = await connectivity.checkConnectivity();
  yield _isOnline(initial);

  // Then stream every subsequent change
  await for (final results in connectivity.onConnectivityChanged) {
    yield _isOnline(results);
  }
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);
