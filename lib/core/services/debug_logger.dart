// lib/core/services/debug_logger.dart
//
// Lightweight on-device debug log. Entries survive app restarts (stored in
// SharedPreferences). Capped at 200 entries — oldest are dropped first.
// Usage: DebugLogger.log('my message', tag: 'Vessel', error: e, stack: st);

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.tag,
    required this.message,
    this.detail,
  });

  final DateTime timestamp;
  final String tag;
  final String message;
  final String? detail;

  Map<String, dynamic> toJson() => {
        'ts':      timestamp.toIso8601String(),
        'tag':     tag,
        'msg':     message,
        if (detail != null) 'detail': detail,
      };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        timestamp: DateTime.parse(j['ts'] as String),
        tag:       j['tag'] as String,
        message:   j['msg'] as String,
        detail:    j['detail'] as String?,
      );
}

class DebugLogger {
  DebugLogger._();

  static const _prefKey = 'debug_log_v1';
  static const _maxEntries = 200;

  // Write a log entry. Call from anywhere — fire and forget.
  static Future<void> log(
    String message, {
    String tag = 'App',
    Object? error,
    StackTrace? stack,
  }) async {
    String? detail;
    if (error != null) {
      detail = error.toString();
      if (stack != null) {
        detail = '$detail\n\n${stack.toString().split('\n').take(8).join('\n')}';
      }
    }

    // Always print to the IDE/VS Code debug console immediately.
    final prefix = '[${tag.toUpperCase()}]';
    if (detail != null) {
      debugPrint('$prefix $message\n$detail');
    } else {
      debugPrint('$prefix $message');
    }

    final entry = LogEntry(
      timestamp: DateTime.now().toLocal(),
      tag:       tag,
      message:   message,
      detail:    detail,
    );

    try {
      final prefs   = await SharedPreferences.getInstance();
      final raw     = prefs.getString(_prefKey) ?? '[]';
      final entries = (jsonDecode(raw) as List)
          .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      entries.add(entry);
      if (entries.length > _maxEntries) {
        entries.removeRange(0, entries.length - _maxEntries);
      }
      await prefs.setString(
          _prefKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
    } catch (_) {
      // Never let the logger crash the app.
    }
  }

  static Future<List<LogEntry>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_prefKey) ?? '[]';
      final list  = (jsonDecode(raw) as List)
          .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      return list.reversed.toList(); // newest first
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
