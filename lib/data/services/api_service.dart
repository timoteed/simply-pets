import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, {this.statusCode = 400});

  @override
  String toString() => message;
}

class ApiService {
  final StorageService storageService;
  final http.Client _client;
  void Function()? onUnauthorized;

  ApiService({
    required this.storageService,
    http.Client? client,
    this.onUnauthorized,
  }) : _client = client ?? http.Client();

  String get baseUrl {
    final customUrl = storageService.getApiBaseUrl();
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      return customUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }

    if (kIsWeb) {
      // In browser, if hosted on the same server, use the origin.
      // If running dev server on another port, default to http://127.0.0.1:8080
      final uri = Uri.base;
      if (uri.port == 8080 || uri.port == 8081 || uri.port == 8082) {
        return uri.origin;
      }
      return 'http://127.0.0.1:8080';
    }

    return 'http://127.0.0.1:8080';
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    final token = storageService.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _buildUri(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleanPath');
  }

  dynamic _processResponse(http.Response response) {
    dynamic data;
    try {
      if (response.body.isNotEmpty) {
        data = jsonDecode(response.body);
      }
    } catch (_) {
      data = response.body;
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
      final msg = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Authentication required. Please log in.';
      throw ApiException(msg, statusCode: 401);
    }

    if (response.statusCode >= 400) {
      final msg = data is Map && data['error'] != null
          ? data['error'].toString()
          : (data is String && data.isNotEmpty ? data : 'Request failed (${response.statusCode})');
      throw ApiException(msg, statusCode: response.statusCode);
    }

    return data;
  }

  Future<dynamic> get(String path) async {
    try {
      final uri = _buildUri(path);
      final response = await _client.get(uri, headers: _buildHeaders());
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<dynamic> post(String path, [dynamic body]) async {
    try {
      final uri = _buildUri(path);
      final response = await _client.post(
        uri,
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<dynamic> put(String path, dynamic body) async {
    try {
      final uri = _buildUri(path);
      final response = await _client.put(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final uri = _buildUri(path);
      final response = await _client.delete(uri, headers: _buildHeaders());
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  String qualifyUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('data:')) {
      return path;
    }
    final clean = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$clean';
  }

  Future<dynamic> postMultipart(
    String path, {
    required List<int> bytes,
    required String filename,
    String fieldName = 'photo',
  }) async {
    try {
      final uri = _buildUri(path);
      final request = http.MultipartRequest('POST', uri);
      final token = storageService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
        ),
      );
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }
}
