import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/auth_models.dart';
import 'api_service.dart';
import 'notification_service.dart';

class AuthService {
  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'user_data';

  final _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  User? _currentUser;
  Future<void>? _loadFuture;

  AuthService() {
    _loadFuture = _loadUserFromStorage();
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

  Future<void> ensureUserLoaded() async {
    _loadFuture ??= _loadUserFromStorage();
    await _loadFuture;
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
      departamentoNombre: response.departamentoNombre,
    );

    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    _currentUser = user;
    _loadFuture = Future.value();
  }

  // Login
  Future<User?> login(String email, String password) async {
    try {
      final response = await _apiService.login(email, password);
      await saveCredentials(response);
      _registrarFcmToken(response.id, response.token);
      return _currentUser;
    } catch (e) {
      rethrow;
    }
  }

  // Guardar FCM token en el backend (silencioso si falla)
  Future<void> _registrarFcmToken(String userId, String token) async {
    try {
      final fcmToken = await NotificationService.obtenerToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _apiService.actualizarFcmToken(userId, fcmToken, token);
        debugPrint('[AuthService] FCM token registrado en backend');
      }
    } catch (e) {
      debugPrint('[AuthService] No se pudo registrar FCM token: $e');
    }
  }

  Future<void> sincronizarFcmTokenSesionActiva() async {
    try {
      await ensureUserLoaded();
      final token = await getToken();
      final userId = _currentUser?.id;
      if (token == null || userId == null || userId.isEmpty) return;

      final fcmToken = await NotificationService.obtenerToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      await _apiService.actualizarFcmToken(userId, fcmToken, token);
      debugPrint('[AuthService] FCM token sincronizado en inicio de app');
    } catch (e) {
      debugPrint('[AuthService] No se pudo sincronizar FCM token al iniciar: $e');
    }
  }

  Future<void> sincronizarFcmTokenConValor(String fcmToken) async {
    try {
      await ensureUserLoaded();
      final token = await getToken();
      final userId = _currentUser?.id;
      if (token == null || userId == null || userId.isEmpty) return;
      if (fcmToken.isEmpty) return;

      await _apiService.actualizarFcmToken(userId, fcmToken, token);
      debugPrint('[AuthService] FCM token actualizado por rotacion');
    } catch (e) {
      debugPrint('[AuthService] No se pudo actualizar FCM token por rotacion: $e');
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
    try {
      final token = await getToken();
      final userId = _currentUser?.id;
      if (token != null && userId != null && userId.isNotEmpty) {
        await _apiService.actualizarFcmToken(userId, '', token);
        debugPrint('[AuthService] FCM token limpiado en logout');
      }
    } catch (e) {
      debugPrint('[AuthService] No se pudo limpiar FCM token: $e');
    }
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

  // Obtener departamento del usuario actual
  String? get userDepartamento => _currentUser?.departamentoNombre;
}
