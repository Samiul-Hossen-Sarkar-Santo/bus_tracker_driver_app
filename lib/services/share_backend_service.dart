import 'dart:convert';
import 'dart:io';

import 'package:bus_tracker_driver_app/data/bus_catalog.dart';

class ShareSessionStartResult {
  final String sessionId;
  final DateTime expiresAt;

  const ShareSessionStartResult({
    required this.sessionId,
    required this.expiresAt,
  });
}

class ShareBackendService {
  static const String _defaultApiBaseUrl =
      'https://asia-southeast1-bus-tracker-bbaa6.cloudfunctions.net';
  static const String _definedApiBaseUrl = String.fromEnvironment(
    'SHARING_API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );
  static const Duration _timeout = Duration(seconds: 15);

  static String get _apiBaseUrl {
    final value = _definedApiBaseUrl.trim();
    return value.isEmpty ? _defaultApiBaseUrl : value;
  }

  static bool get isConfigured => _apiBaseUrl.trim().isNotEmpty;

  static Uri _buildUri(String path) {
    final normalized = _apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$normalized/$path');
  }

  static Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (!isConfigured) {
      throw Exception(
        'Backend URL not configured. Pass '
        '--dart-define=SHARING_API_BASE_URL=https://<region>-<project>.cloudfunctions.net',
      );
    }

    final client = HttpClient();
    try {
      final request = await client
          .postUrl(_buildUri(path))
          .timeout(_timeout);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close().timeout(_timeout);
      final payload = await utf8.decodeStream(response).timeout(_timeout);
      final parsed = payload.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(payload) as Map<String, dynamic>);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final backendError = parsed['error']?.toString();
        throw Exception(backendError ?? 'Backend request failed: ${response.statusCode}');
      }

      return parsed;
    } on SocketException {
      throw Exception('Network issue while contacting backend.');
    } on HttpException {
      throw Exception('Backend HTTP error.');
    } finally {
      client.close(force: true);
    }
  }

  static Future<ShareSessionStartResult> startSharing({
    required BusCatalogItem bus,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _postJson('startSharing', {
      'busId': bus.busId,
      'routeId': bus.routeId,
      'routeName': bus.routeName,
      'busNumber': bus.busNumber,
      'driverName': bus.driverName,
      'location': {
        'lat': latitude,
        'long': longitude,
      },
    });

    final sessionId = response['sessionId']?.toString();
    final expiresAtMs = response['expiresAtMs'];

    if (sessionId == null || sessionId.isEmpty || expiresAtMs is! num) {
      throw Exception('Invalid backend response for startSharing.');
    }

    return ShareSessionStartResult(
      sessionId: sessionId,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs.toInt()),
    );
  }

  static Future<void> updateLocation({
    required String busId,
    required String sessionId,
    required double latitude,
    required double longitude,
  }) async {
    await _postJson('updateLocation', {
      'busId': busId,
      'sessionId': sessionId,
      'location': {
        'lat': latitude,
        'long': longitude,
      },
    });
  }

  static Future<void> stopSharing({
    required String busId,
    required String sessionId,
    String reason = 'manual_stop',
  }) async {
    await _postJson('stopSharing', {
      'busId': busId,
      'sessionId': sessionId,
      'reason': reason,
    });
  }
}
