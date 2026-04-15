import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_url.dart';
import '../models/auth_models.dart';

class ApiService {
  final String baseUrl = ApiConstants.baseUrl;

  Future<AuthResponse> login(String email, String password) async {
    final url = Uri.parse('$baseUrl${ApiConstants.loginEndpoint}');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final apiResponse = ApiResponse<AuthResponse>.fromJson(
          json,
          (data) => AuthResponse.fromJson(data),
        );

        if (apiResponse.data != null) {
          return apiResponse.data!;
        } else {
          throw Exception('No se recibieron datos de autenticación');
        }
      } else if (response.statusCode == 401) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(json['message'] ?? 'Credenciales inválidas');
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(json['message'] ?? 'Error al iniciar sesión');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<AuthResponse> registro(
    String nombreEmpresa,
    String nombreAdmin,
    String email,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl${ApiConstants.registerEndpoint}');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombreEmpresa': nombreEmpresa,
          'nombreAdmin': nombreAdmin,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final apiResponse = ApiResponse<AuthResponse>.fromJson(
          json,
          (data) => AuthResponse.fromJson(data),
        );

        if (apiResponse.data != null) {
          return apiResponse.data!;
        } else {
          throw Exception('No se recibieron datos de autenticación');
        }
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(json['message'] ?? 'Error al registrarse');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<String> health() async {
    final url = Uri.parse('$baseUrl${ApiConstants.healthEndpoint}');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return 'OK';
      } else {
        throw Exception('Servidor no disponible');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
