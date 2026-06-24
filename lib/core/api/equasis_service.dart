// lib/core/api/equasis_service.dart
//
// Logs in to equasis.org and fetches the ship folder PDF for a given IMO.
// Equasis generates and serves the PDF directly from
//   /EquasisWeb/restricted/ShipFop?fs=ShipInfo&IMO={imo}
// so we just return those bytes for upload to the document vault — no
// HTML parsing or PDF re-generation needed.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class EquasisService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://www.equasis.org',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*',
      'Accept-Language': 'en-US,en;q=0.9',
    },
  ));

  /// Full flow: login → fetch Equasis ship-folder PDF → return bytes.
  static Future<Uint8List> fetchVesselReport({
    required String imo,
    required String username,
    required String password,
    String? vesselName,
  }) async {
    final cookie = await _login(username, password);
    return _fetchShipPdf(imo, cookie);
  }

  // ── Login ──────────────────────────────────────────────────────────────

  static Future<String> _login(String username, String password) async {
    final allCookies = <String>{};

    // Step 1: GET the home/login page to establish a pre-session cookie and
    // extract the form action URL + any hidden fields.
    String formAction = '/EquasisWeb/public/HomePage';
    Map<String, String> hiddenFields = {};

    try {
      final initResp = await _dio.get(
        '/EquasisWeb/public/HomePage',
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      _collectCookies(initResp.headers, allCookies);

      final initHtml = (initResp.data ?? '') as String;

      // Extract login form action.
      final actionMatch = RegExp(
        r'<form[^>]+action="([^"]*)"',
        caseSensitive: false,
      ).firstMatch(initHtml);
      if (actionMatch != null && actionMatch.group(1)!.isNotEmpty) {
        final raw = actionMatch.group(1)!;
        formAction = raw.startsWith('http')
            ? raw
            : raw.startsWith('/')
                ? raw
                : '/EquasisWeb/public/$raw';
      }

      // Extract all hidden input fields (ViewState, CSRF tokens, etc.).
      for (final m in RegExp(
        r'<input[^>]+type="hidden"[^>]+name="([^"]+)"[^>]+value="([^"]*)"',
        caseSensitive: false,
      ).allMatches(initHtml)) {
        hiddenFields[m.group(1)!] = m.group(2)!;
      }

      debugPrint('[Equasis] GET form action: $formAction');
      debugPrint('[Equasis] GET hidden fields: ${hiddenFields.keys.toList()}');
    } catch (e) {
      debugPrint('[Equasis] pre-session GET failed: $e');
      throw Exception('Equasis unreachable — check your internet connection. ($e)');
    }

    if (allCookies.isEmpty) {
      throw Exception('Equasis did not return a session cookie. Try again.');
    }

    final initCookieStr = allCookies.join('; ');
    debugPrint('[Equasis] pre-session: ${allCookies.length} cookie(s)');

    // Step 2: POST credentials + all hidden fields to the form action URL.
    final params = <String, String>{
      ...hiddenFields,
      'j_email':  username,
      'j_password': password,
      'fs':       'Login',
      'pageName': 'Login',
    };
    final postBody = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final resp = await _dio.post(
      formAction,
      data: postBody,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: false,
        validateStatus: (s) => s != null && s < 500,
        headers: {
          if (initCookieStr.isNotEmpty) 'Cookie': initCookieStr,
          'Referer': 'https://www.equasis.org/EquasisWeb/public/HomePage',
          'Origin':  'https://www.equasis.org',
        },
      ),
    );
    _collectCookies(resp.headers, allCookies);

    final postLoc = resp.headers.map['location']?.first ?? 'none';
    debugPrint('[Equasis] POST response: status=${resp.statusCode}, location=$postLoc');

    // Step 3: Follow redirect hop(s) and accumulate cookies.
    var statusCode = resp.statusCode ?? 0;
    var location   = resp.headers.map['location']?.first ?? '';
    for (var hops = 0;
        hops < 5 && (statusCode == 301 || statusCode == 302) && location.isNotEmpty;
        hops++) {
      final url = location.startsWith('http')
          ? location
          : 'https://www.equasis.org$location';
      final hop = await _dio.get(
        url,
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
          headers: {'Cookie': allCookies.join('; ')},
        ),
      );
      _collectCookies(hop.headers, allCookies);
      statusCode = hop.statusCode ?? 0;
      location   = hop.headers.map['location']?.first ?? '';
    }

    // Explicit redirect somewhere other than /restricted/ or /authen/ means
    // the credentials were rejected.  A 200 (authenticated homepage) is fine.
    final postStatus = resp.statusCode ?? 0;
    if ((postStatus == 301 || postStatus == 302) &&
        !postLoc.contains('/restricted/') &&
        !postLoc.contains('/authen/')) {
      throw Exception('Equasis login failed: unexpected redirect to $postLoc. Check credentials.');
    }

    final cookieStr = allCookies.join('; ');

    debugPrint('[Equasis] login OK — ${allCookies.length} cookie(s)'
        '${postLoc != "none" ? " → $postLoc" : ""}');
    return cookieStr;
  }

  static void _collectCookies(Headers headers, Set<String> jar) {
    for (final h in (headers.map['set-cookie'] ?? [])) {
      final kv   = h.split(';').first.trim();
      if (kv.isEmpty) continue;
      final name = kv.split('=').first;
      jar.removeWhere((c) => c.startsWith('$name='));
      jar.add(kv);
    }
  }

  // ── Fetch ship-folder PDF ─────────────────────────────────────────────

  static Future<Uint8List> _fetchShipPdf(String imo, String cookie) async {
    final resp = await _dio.get<List<int>>(
      '/EquasisWeb/restricted/ShipFop',
      queryParameters: {'fs': 'ShipInfo', 'IMO': imo},
      options: Options(
        followRedirects: true,
        responseType: ResponseType.bytes,
        validateStatus: (s) => s != null && s < 500,
        headers: {
          'Cookie': cookie,
          'Accept': 'application/pdf,*/*',
        },
      ),
    );

    if (resp.statusCode == 403) {
      throw Exception('Equasis: access denied (403). Session may have expired.');
    }

    final bytes = resp.data ?? <int>[];
    if (bytes.length < 4) {
      throw Exception('Equasis returned an empty response for IMO $imo.');
    }

    // Check the PDF magic bytes — if we got HTML the session wasn't authenticated.
    final magic = String.fromCharCodes(bytes.take(4));
    if (magic != '%PDF') {
      throw Exception(
          'Equasis session not authenticated. Check credentials and retry.');
    }

    debugPrint('[Equasis] ShipFop PDF: ${bytes.length} bytes for IMO $imo');
    return Uint8List.fromList(bytes);
  }
}
