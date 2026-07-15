// lib/shared/widgets/biometric_lock_gate.dart
//
// Shown in front of the whole app at cold start (and again whenever the app
// resumes from background) when the surveyor has turned on the biometric
// app-lock toggle in Account settings. Blocks nothing when the setting is
// off — the common case — so this is a no-op wrapper until opted into.

import 'package:flutter/material.dart';
import '../../core/services/biometric_lock_service.dart';
import '../theme/app_theme.dart';

class BiometricLockGate extends StatefulWidget {
  const BiometricLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _locked = false;
  bool _lockEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _lockEnabled) {
      setState(() => _locked = true);
    }
  }

  Future<void> _checkLock() async {
    final enabled = await BiometricLockService.isEnabled();
    if (!mounted) return;
    setState(() {
      _lockEnabled = enabled;
      _locked = enabled;
      _checking = false;
    });
  }

  Future<void> _unlock() async {
    final ok = await BiometricLockService.authenticate();
    if (!mounted) return;
    if (ok) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const SizedBox.shrink();
    if (!_locked) return widget.child;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white, size: 56),
              const SizedBox(height: 20),
              const Text('Marine Survey is locked',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _unlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
