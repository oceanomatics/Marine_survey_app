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

  static const _loginUrl = '/EquasisWeb/authen/HomePage?fs=HomePage';

  static Future<String> _login(String username, String password) async {
    final allCookies = <String>{};

    // Step 1: GET the login page directly (not the public marketing
    // homepage) to establish the session cookie against the same URL the
    // login POST will hit — matches a confirmed-working, independently
    // reverse-engineered Equasis client, and avoids whatever session state
    // was missing when we instead started from /public/HomePage and scraped
    // a form action out of it (that path was consistently landing on
    // Equasis's own generic "CtrlGeneralError" page downstream).
    try {
      var initResp = await _dio.get(
        _loginUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      _collectCookies(initResp.headers, allCookies);

      // Follow redirect hops manually, collecting cookies at each one —
      // auto-followed redirects (followRedirects: true) never expose
      // intermediate Set-Cookie headers to the caller, so if the homepage
      // itself redirects to establish the session cookie, it would
      // otherwise be silently dropped (this is the likely cause of the
      // intermittent "session not authenticated" failures).
      var initHops = 0;
      while (initHops < 5 &&
          (initResp.statusCode == 301 || initResp.statusCode == 302) &&
          (initResp.headers.map['location']?.isNotEmpty ?? false)) {
        final loc = initResp.headers.map['location']!.first;
        final url = loc.startsWith('http') ? loc : 'https://www.equasis.org$loc';
        initResp = await _dio.get(
          url,
          options: Options(
            followRedirects: false,
            validateStatus: (s) => s != null && s < 500,
            headers: {'Cookie': allCookies.join('; ')},
          ),
        );
        _collectCookies(initResp.headers, allCookies);
        initHops++;
      }

      debugPrint('[Equasis] GET $_loginUrl: status=${initResp.statusCode}');
    } catch (e) {
      debugPrint('[Equasis] pre-session GET failed: $e');
      throw Exception('Equasis unreachable — check your internet connection. ($e)');
    }

    if (allCookies.isEmpty) {
      throw Exception('Equasis did not return a session cookie. Try again.');
    }

    final initCookieStr = allCookies.join('; ');
    debugPrint('[Equasis] pre-session: ${allCookies.length} cookie(s) '
        '(${allCookies.map((c) => c.split("=").first).join(", ")})');

    // Step 2: POST credentials to that same URL. Only send what the actual
    // login form/button submits (j_email, j_password, submit) — we used to
    // also send fs=Login/pageName=Login, which conflicts with the fs=
    // HomePage already on the URL's own query string and is not part of
    // the real form at all; that mismatch is the likely cause of the
    // "CtrlGeneralError" responses seen once logged in.
    final params = <String, String>{
      'j_email':  username,
      'j_password': password,
      'submit':   'Login',
    };
    final postBody = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final resp = await _dio.post(
      _loginUrl,
      data: postBody,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: false,
        validateStatus: (s) => s != null && s < 500,
        headers: {
          if (initCookieStr.isNotEmpty) 'Cookie': initCookieStr,
          'Referer': 'https://www.equasis.org$_loginUrl',
          'Origin':  'https://www.equasis.org',
        },
      ),
    );
    _collectCookies(resp.headers, allCookies);

    final postLoc = resp.headers.map['location']?.first ?? 'none';
    debugPrint('[Equasis] POST response: status=${resp.statusCode}, location=$postLoc');

    // Equasis doesn't 302-redirect on this form any more — it forwards
    // server-side and returns 200 either way, distinguishing success/failure
    // only via a JS-triggered modal embedded in the response body (e.g.
    // "Your login (e-mail) or/and password are unknown in Equasis" or
    // "Your session has expired, please try to login again"). Surface that
    // exact text instead of guessing from the status code alone — it's the
    // most reliable signal we have, and tells the surveyor precisely what
    // Equasis is objecting to.
    final postHtml = (resp.data ?? '').toString();
    final modalMsg = _extractModalMessage(postHtml);
    if (modalMsg != null) {
      debugPrint('[Equasis] login POST modal message: "$modalMsg"');
      throw Exception('Equasis login failed: $modalMsg');
    }
    debugPrint('[Equasis] login POST body: ${postHtml.length} chars, no error modal detected');

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

    debugPrint('[Equasis] login OK — ${allCookies.length} cookie(s) '
        '(${allCookies.map((c) => c.split("=").first).join(", ")})'
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

  // Equasis renders site messages ("Your session has expired...", "Your
  // login (e-mail) or/and password are unknown in Equasis...", etc.) into a
  // Bootstrap modal (`id="warning"`) that's only present in the HTML when
  // there's something to say. Absent on normal authenticated pages.
  static String? _extractModalMessage(String html) {
    final m = RegExp(
      r'id="warning"[\s\S]*?<div class="modal-body">\s*<p>([^<]+)</p>',
      caseSensitive: false,
    ).firstMatch(html);
    final msg = m?.group(1)?.trim();
    return (msg != null && msg.isNotEmpty) ? msg : null;
  }

  // ── Fetch ship-folder PDF ─────────────────────────────────────────────

  static Future<Uint8List> _fetchShipPdf(String imo, String cookie) async {
    // Confirmed against a real authenticated session (see
    // docs/EQUASIS_DEBUG_LOG.md, Attempt 6): Equasis's own search-results
    // rows select a ship via a hidden form — POST to
    // ShipInfo?fs=Search with P_IMO in the body — not a GET with query
    // parameters. Only after that "lands" on the ship does the page expose
    // the actual ship-folder PDF link, which uses a *different* parameter
    // name again: ShipFop?fs=ShipInfo&IMO=... (plain IMO, not P_IMO).
    final infoBytes = await _post(
      '/EquasisWeb/restricted/ShipInfo',
      {'P_IMO': imo},
      cookie,
      label: 'ShipInfo',
      query: {'fs': 'Search'},
    );

    final infoHtml = String.fromCharCodes(infoBytes);
    if (!_isPdf(infoBytes)) {
      final infoModalMsg = _extractModalMessage(infoHtml);
      if (infoModalMsg != null) {
        _logHtmlDiagnostics('ShipInfo', infoHtml);
        throw Exception('Equasis: $infoModalMsg');
      }
      if (!infoHtml.contains(imo)) {
        _logHtmlDiagnostics('ShipInfo', infoHtml);
        throw Exception('Equasis: could not find a ship matching IMO $imo.');
      }
    }

    final bytes = await _get(
      '/EquasisWeb/restricted/ShipFop',
      {'fs': 'ShipInfo', 'IMO': imo},
      cookie,
      label: 'ShipFop',
    );

    if (_isPdf(bytes)) {
      debugPrint('[Equasis] ShipFop PDF: ${bytes.length} bytes for IMO $imo');
      return Uint8List.fromList(bytes);
    }

    final html = String.fromCharCodes(bytes);
    _logHtmlDiagnostics('ShipFop', html);
    final modalMsg = _extractModalMessage(html);
    throw Exception(modalMsg != null
        ? 'Equasis: $modalMsg'
        : 'Equasis session not authenticated. Check credentials and retry.');
  }

  static Future<List<int>> _get(
    String path,
    Map<String, String>? query,
    String cookie, {
    required String label,
  }) async {
    final resp = await _dio.get<List<int>>(
      path,
      queryParameters: query,
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
    return _logAndUnwrap(label, resp);
  }

  static Future<List<int>> _post(
    String path,
    Map<String, String> fields,
    String cookie, {
    required String label,
    Map<String, String>? query,
  }) async {
    final body = fields.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final resp = await _dio.post<List<int>>(
      path,
      data: body,
      queryParameters: query,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: true,
        responseType: ResponseType.bytes,
        validateStatus: (s) => s != null && s < 500,
        headers: {
          'Cookie': cookie,
          'Accept': 'application/pdf,*/*',
        },
      ),
    );
    return _logAndUnwrap(label, resp);
  }

  static List<int> _logAndUnwrap(String label, Response<List<int>> resp) {
    final contentType = resp.headers.value('content-type') ?? 'unknown';
    debugPrint('[Equasis] $label response: status=${resp.statusCode}, '
        'content-type=$contentType, bytes=${resp.data?.length ?? 0}');

    if (resp.statusCode == 403) {
      throw Exception('Equasis: access denied (403). Session may have expired.');
    }

    final bytes = resp.data ?? <int>[];
    if (bytes.length < 4) {
      throw Exception('Equasis returned an empty response.');
    }
    return bytes;
  }

  static bool _isPdf(List<int> bytes) =>
      bytes.length >= 4 && String.fromCharCodes(bytes.take(4)) == '%PDF';

  static void _logHtmlDiagnostics(String label, String html) {
    final titleMatch =
        RegExp(r'<title>([^<]*)</title>', caseSensitive: false).firstMatch(html);
    final title = titleMatch?.group(1)?.trim() ?? '(no title found)';
    // Collapse whitespace so the logged snippet is actually readable instead
    // of mostly blank lines (Equasis templates start with several newlines).
    final compact = html.replaceAll(RegExp(r'\s+'), ' ').trim();
    debugPrint('[Equasis] $label non-PDF response — title: "$title", '
        '${html.length} chars');
    debugPrint('[Equasis] $label snippet: '
        '${compact.substring(0, compact.length < 600 ? compact.length : 600)}');
  }
}
