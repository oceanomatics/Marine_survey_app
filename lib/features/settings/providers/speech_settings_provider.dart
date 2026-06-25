// lib/features/settings/providers/speech_settings_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Value object ──────────────────────────────────────────────────────────────

enum EndpointSensitivity {
  relaxed,  // 4.0 s / 2.5 s — slow speakers, long pauses
  normal,   // 3.0 s / 1.8 s — default
  tight;    // 1.8 s / 1.0 s — fast speakers, quick saves

  String get label => switch (this) {
        relaxed => 'Relaxed',
        normal  => 'Normal',
        tight   => 'Tight',
      };

  String get hint => switch (this) {
        relaxed => 'Longer pause before sentence ends',
        normal  => 'Balanced — recommended',
        tight   => 'Shorter pause, faster segments',
      };

  /// trailing-silence thresholds: [rule1, rule2] in seconds
  (double, double) get thresholds => switch (this) {
        relaxed => (4.0, 2.5),
        normal  => (3.0, 1.8),
        tight   => (1.8, 1.0),
      };
}

class SpeechSettings {
  const SpeechSettings({
    this.modelId            = 'en-20m',
    this.decodingMethod     = 'modified_beam_search',
    this.endpointSensitivity = EndpointSensitivity.normal,
  });

  final String              modelId;
  final String              decodingMethod;   // 'greedy_search' | 'modified_beam_search'
  final EndpointSensitivity endpointSensitivity;

  SpeechSettings copyWith({
    String?              modelId,
    String?              decodingMethod,
    EndpointSensitivity? endpointSensitivity,
  }) =>
      SpeechSettings(
        modelId:             modelId             ?? this.modelId,
        decodingMethod:      decodingMethod      ?? this.decodingMethod,
        endpointSensitivity: endpointSensitivity ?? this.endpointSensitivity,
      );
}

// ── Keys ──────────────────────────────────────────────────────────────────────

const _kModelId    = 'speech_model_id';
const _kDecoding   = 'speech_decoding_method';
const _kEndpoint   = 'speech_endpoint_sensitivity';

// ── Provider ──────────────────────────────────────────────────────────────────

final speechSettingsProvider =
    AsyncNotifierProvider<SpeechSettingsNotifier, SpeechSettings>(
  SpeechSettingsNotifier.new,
);

class SpeechSettingsNotifier extends AsyncNotifier<SpeechSettings> {
  @override
  Future<SpeechSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SpeechSettings(
      modelId: prefs.getString(_kModelId) ?? 'en-20m',
      decodingMethod: prefs.getString(_kDecoding) ?? 'modified_beam_search',
      endpointSensitivity: EndpointSensitivity.values.firstWhere(
        (e) => e.name == (prefs.getString(_kEndpoint) ?? 'normal'),
        orElse: () => EndpointSensitivity.normal,
      ),
    );
  }

  Future<void> setModelId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModelId, id);
    state = AsyncData(state.requireValue.copyWith(modelId: id));
  }

  Future<void> setDecodingMethod(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDecoding, method);
    state = AsyncData(state.requireValue.copyWith(decodingMethod: method));
  }

  Future<void> setEndpointSensitivity(EndpointSensitivity s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEndpoint, s.name);
    state = AsyncData(state.requireValue.copyWith(endpointSensitivity: s));
  }
}
