import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import '../constants/api_constants.dart';

class ApiService {
  ApiService({GetStorage? storage}) : _storage = storage ?? GetStorage();

  final GetStorage _storage;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);

  String buildUrl(String endpoint) {
    if (endpoint.startsWith('http')) return endpoint;
    return '${ApiConstants.baseUrl}$endpoint';
  }

  Future<Map<String, dynamic>> get({
    required String endpoint,
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) {
    return _request(
      method: 'GET',
      endpoint: endpoint,
      query: query,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>> post({
    required String endpoint,
    Map<String, dynamic>? data,
    bool authenticated = true,
  }) {
    return _request(
      method: 'POST',
      endpoint: endpoint,
      data: data,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>> put({
    required String endpoint,
    Map<String, dynamic>? data,
    bool authenticated = true,
  }) {
    return _request(
      method: 'PUT',
      endpoint: endpoint,
      data: data,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>> delete({
    required String endpoint,
    Map<String, dynamic>? data,
    bool authenticated = true,
  }) {
    return _request(
      method: 'DELETE',
      endpoint: endpoint,
      data: data,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String endpoint,
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    bool authenticated = true,
    bool hasRetriedAfterRefresh = false,
  }) async {
    final uri = _buildUri(endpoint, query);
    debugPrint('ApiService.$method: $uri payload=${data ?? {}}');

    try {
      final request = await _client.openUrl(method, uri);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.contentTypeHeader, 'application/json');
      final token = _storage.read<String>('accessToken');
      if (authenticated && token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (data != null) {
        request.add(utf8.encode(jsonEncode(data)));
      }

      final response = await request.close().timeout(const Duration(seconds: 18));
      final body = await response.transform(utf8.decoder).join();
      final decoded = _decodeBody(body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _normalizeResponse(decoded, uri.toString());
      }
      if (authenticated &&
          response.statusCode == 401 &&
          !hasRetriedAfterRefresh &&
          await _refreshAccessToken()) {
        return _request(
          method: method,
          endpoint: endpoint,
          query: query,
          data: data,
          authenticated: authenticated,
          hasRetriedAfterRefresh: true,
        );
      }
      debugPrint('ApiService.$method: HTTP ${response.statusCode} $body');
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractMessage(decoded) ?? 'Request failed',
        response: _normalizeResponse(decoded, uri.toString()),
      );
    } on TimeoutException catch (error) {
      debugPrint('ApiService.$method timeout: $error');
      rethrow;
    } on SocketException catch (error) {
      debugPrint('ApiService.$method network error: $error');
      rethrow;
    } catch (error) {
      debugPrint('ApiService.$method error: $error');
      rethrow;
    }
  }

  Uri _buildUri(String endpoint, Map<String, dynamic>? query) {
    final uri = Uri.parse(buildUrl(endpoint));
    if (query == null || query.isEmpty) return uri;
    final existing = Map<String, String>.from(uri.queryParameters);
    query.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        existing[key] = value.toString();
      }
    });
    return uri.replace(queryParameters: existing);
  }

  Object? _decodeBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }

  Map<String, dynamic> _normalizeResponse(Object? decoded, String url) {
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded)..putIfAbsent('url', () => url);
    }
    if (decoded is List) {
      return {'success': true, 'url': url, 'data': decoded};
    }
    return {'success': true, 'url': url, 'data': decoded};
  }

  String? _extractMessage(Object? decoded) {
    if (decoded is! Map) return null;
    for (final key in ['message', 'error', 'detail']) {
      final value = decoded[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = _storage.read<String>('refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refreshToken}');
      final request = await _client.openUrl('POST', uri);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({'refreshToken': refreshToken})));

      final response = await request.close().timeout(const Duration(seconds: 18));
      final body = await response.transform(utf8.decoder).join();
      final decoded = _decodeBody(body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _clearAuthTokens();
        debugPrint('ApiService.refresh: failed HTTP ${response.statusCode} $body');
        return false;
      }

      final normalized = _normalizeResponse(decoded, uri.toString());
      final access = _findString(normalized, const ['accessToken', 'token', 'access_token']);
      final refresh = _findString(normalized, const ['refreshToken', 'refresh_token']);
      if (access == null || access.isEmpty) {
        await _clearAuthTokens();
        return false;
      }
      await _storage.write('accessToken', access);
      if (refresh != null && refresh.isNotEmpty) {
        await _storage.write('refreshToken', refresh);
      }
      debugPrint('ApiService.refresh: token refreshed successfully');
      return true;
    } catch (error) {
      await _clearAuthTokens();
      debugPrint('ApiService.refresh: failed after exception $error');
      return false;
    }
  }

  String? _findString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    for (final value in map.values) {
      if (value is Map) {
        final nested = _findString(Map<String, dynamic>.from(value), keys);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    }
    return null;
  }

  Future<void> _clearAuthTokens() async {
    await _storage.remove('accessToken');
    await _storage.remove('refreshToken');
  }
}

class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    required this.response,
  });

  final int statusCode;
  final String message;
  final Map<String, dynamic> response;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

