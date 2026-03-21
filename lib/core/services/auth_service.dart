import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

const _jwtStorageKey = 'coc_jwt_token';
const _operatorNameKey = 'coc_operator_name';
const _operatorRoleKey = 'coc_operator_role';
const _apiBase = 'http://192.168.1.5:3000';

class AuthService {
  AuthService(this._storage, this._dio);
  final FlutterSecureStorage _storage;
  final Dio _dio;

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _jwtStorageKey);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() => _storage.read(key: _jwtStorageKey);
  Future<String?> getOperatorName() => _storage.read(key: _operatorNameKey);
  Future<String?> getOperatorRole() => _storage.read(key: _operatorRoleKey);

  /// Login: POST /auth/login with {email, password}
  /// Response: { token: String, operator: { name: String, role: String } }
  Future<void> login(String email, String password) async {
    final response = await _dio.post(
      '$_apiBase/auth/login',
      data: {'identifier': email, 'password': password},
    );
    final token = response.data['accessToken'] as String;
    final user = response.data['user'] as Map<String, dynamic>;
    await _storage.write(key: _jwtStorageKey, value: token);
    await _storage.write(
      key: _operatorNameKey,
      value: user['fullName'] as String? ?? 'Operator',
    );
    await _storage.write(
      key: _operatorRoleKey,
      value: 'OPERATOR',
    );
  }

  Future<void> logout() async {
    await _storage.delete(key: _jwtStorageKey);
    await _storage.delete(key: _operatorNameKey);
    await _storage.delete(key: _operatorRoleKey);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final dio = Dio();
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    requestHeader: true,
    responseHeader: false,
    error: true,
    logPrint: (o) => print('[AUTH] $o'),
  ));
  return AuthService(const FlutterSecureStorage(), dio);
});

/// Async bool — true if a valid token exists in secure storage.
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  return ref.watch(authServiceProvider).isLoggedIn();
});
