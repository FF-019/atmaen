import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);

  bool get isOffline => status == 0;

  @override
  String toString() => message;
}

/// Thin wrapper over http. Keeps the token and turns server errors into
/// readable messages for snackbars.
class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  String? token;
  void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 15);

  Uri _uri(String path, [Map<String, dynamic>? query]) => Uri.parse('${AppConfig.apiUrl}/api$path').replace(
        queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
      );

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String path, Object body) =>
      _send(() => _http.patch(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> delete(String path) => _send(() => _http.delete(_uri(path), headers: _headers));

  Future<dynamic> upload(String path, File file, {Map<String, String> fields = const {}}) async {
    final req = http.MultipartRequest('POST', _uri(path))
      ..fields.addAll(fields)
      ..files.add(await http.MultipartFile.fromPath('image', file.path));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    return _send(() async => http.Response.fromStream(await _http.send(req)));
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(_timeout);
    } on SocketException {
      throw ApiException(0, 'لا يوجد اتصال بالإنترنت');
    } on TimeoutException {
      throw ApiException(0, 'الاتصال بطيء، حاول مرة أخرى');
    } on http.ClientException {
      throw ApiException(0, 'تعذر الوصول للخادم');
    }

    if (res.statusCode == 204) return null;
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));

    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401) onUnauthorized?.call();
    throw ApiException(res.statusCode, _message(res.statusCode, body));
  }

  // the api returns english details, map the common ones to arabic
  static const _known = {
    'wrong email or password': 'البريد أو كلمة المرور غير صحيحة',
    'this email is already registered': 'هذا البريد مسجل مسبقاً',
    'another volunteer already took this case': 'تولى متطوع آخر هذه الحالة',
    'your account is waiting for admin verification': 'حسابك بانتظار التحقق من الإدارة',
    'session expired, please log in again': 'انتهت الجلسة، سجل الدخول مرة أخرى',
  };

  String _message(int status, dynamic body) {
    final detail = body is Map ? body['detail'] : null;
    if (detail is String) return _known[detail] ?? detail;
    if (detail is List && detail.isNotEmpty) return 'تحقق من البيانات المدخلة';
    return 'حدث خطأ ($status)';
  }
}
