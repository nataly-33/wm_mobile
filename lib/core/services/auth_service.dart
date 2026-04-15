import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/auth_models.dart';
import 'api_service.dart';

class AuthService {
  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'user_data';

  final _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  User? _currentUser;

  AuthService() {
    _loadUserFromStorage();
  }

  // Obtener usuario actual
  User? get currentUser => _currentUser;

  // Verificar si está autenticado
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Obtener token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Guardar credenciales
  Future<void> saveCredentials(AuthResponse response) async {
    await _storage.write(key: _tokenKey, value: response.token);

    final user = User(
      id: response.id,
      nombre: response.nombre,
      email: response.email,
      rol: response.rol,
      departamentoId: response.departamentoId,
    );

    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    _currentUser = user;
  }

  // Login
  Future<User?> login(String email, String password) async {
    try {
      final response = await _apiService.login(email, password);
      await saveCredentials(response);
      return _currentUser;
    } catch (e) {
      rethrow;
    }
  }

  // Registro
  Future<User?> registro(
    String nombreEmpresa,
    String nombreAdmin,
    String email,
    String password,
  ) async {
    try {
      final response = await _apiService.registro(
        nombreEmpresa,
        nombreAdmin,
        email,
        password,
      );
      await saveCredentials(response);
      return _currentUser;
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    _currentUser = null;
  }

  // Cargar usuario del almacenamiento
  Future<void> _loadUserFromStorage() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (e) {
        // Usuario inválido, ignorar
        _currentUser = null;
      }
    }
  }

  // Obtener rol del usuario actual
  String? get userRol => _currentUser?.rol;

  // Obtener ID del usuario actual
  String? get userId => _currentUser?.id;

  // Obtener nombre del usuario actual
  String? get userName => _currentUser?.nombre;
}
