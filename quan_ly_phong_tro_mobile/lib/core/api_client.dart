import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final String baseUrl;
  String? _sessionCookie;

  bool get hasSession => _sessionCookie != null;

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  void _captureCookie(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return;

    final match = RegExp(r'\.AspNetCore\.Session=[^;]+').firstMatch(setCookie);
    if (match != null) {
      _sessionCookie = match.group(0);
    }
  }

  dynamic _decode(http.Response response) {
    _captureCookie(response);

    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        body = utf8.decode(response.bodyBytes);
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String message = 'Loi ket noi may chu (${response.statusCode}).';
    if (body is Map<String, dynamic> && body['message'] != null) {
      message = body['message'].toString();
    } else if (body is String && body.trim().isNotEmpty) {
      message = body;
    }
    throw ApiException(response.statusCode, message);
  }

  Future<dynamic> get(String path) async {
    final response = await http.get(_uri(path), headers: _headers);
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final response = await http.post(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final response = await http.put(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(_uri(path), headers: _headers);
    return _decode(response);
  }

  void clearSession() {
    _sessionCookie = null;
  }
}
