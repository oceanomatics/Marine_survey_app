// lib/core/services/fx_rate_service.dart
//
// Fetches historical FX rates from openexchangerates.org (free tier).
// Free tier is USD-based only — cross-rates are computed through USD.
// Rates are cached in memory per (date, from, to) for the session.

import 'package:dio/dio.dart';

class FxRateService {
  FxRateService._();

  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://openexchangerates.org/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  // Session cache: '$date|$from|$to' → rate
  static final Map<String, double> _cache = {};

  /// Returns the rate to convert 1 unit of [from] into [to] on [date].
  /// [date] format: 'YYYY-MM-DD'. Pass null for today's live rate.
  /// Returns null if the API key is missing or the request fails.
  static Future<double?> getRate({
    required String from,
    required String to,
    required String apiKey,
    String? date,
  }) async {
    if (apiKey.isEmpty) return null;
    if (from == to) return 1.0;

    final dateKey = date ?? 'latest';
    final cacheKey = '$dateKey|$from|$to';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final endpoint = date != null
          ? '/historical/$date.json'
          : '/latest.json';
      final response = await _dio.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: {'app_id': apiKey, 'base': 'USD'},
      );

      final rates = response.data?['rates'] as Map<String, dynamic>?;
      if (rates == null) return null;

      final rateFrom = from == 'USD' ? 1.0 : (rates[from] as num?)?.toDouble();
      final rateTo   = to   == 'USD' ? 1.0 : (rates[to]   as num?)?.toDouble();
      if (rateFrom == null || rateTo == null || rateFrom == 0) return null;

      // Cross-rate through USD: 1 FROM = (rateTo / rateFrom) TO
      final rate = rateTo / rateFrom;
      _cache[cacheKey] = rate;
      return rate;
    } catch (_) {
      return null;
    }
  }

  /// Convert [amount] from [from] to [to] on [date].
  static Future<double?> convert({
    required double amount,
    required String from,
    required String to,
    required String apiKey,
    String? date,
  }) async {
    final rate = await getRate(from: from, to: to, apiKey: apiKey, date: date);
    return rate == null ? null : amount * rate;
  }

  /// Clear the session cache (e.g., when the date changes).
  static void clearCache() => _cache.clear();
}
