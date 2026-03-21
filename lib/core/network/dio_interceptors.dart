import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _jwtStorageKey = 'coc_jwt_token';

/// Attaches JWT Bearer token to every outgoing request.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _jwtStorageKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 401 → caller handles logout (Phase 8 wires this up).
    handler.next(err);
  }
}

/// Retries on 5xx errors, up to [maxRetries] times with exponential backoff.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 2});

  final Dio _dio;
  final int maxRetries;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode ?? 0;
    final attempt = err.requestOptions.extra['retryCount'] as int? ?? 0;

    if (statusCode >= 500 && attempt < maxRetries) {
      await Future<void>.delayed(Duration(seconds: (attempt + 1) * 2));
      err.requestOptions.extra['retryCount'] = attempt + 1;
      try {
        final response = await _dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {
        // fall through to handler.next(err)
      }
    }
    handler.next(err);
  }
}
