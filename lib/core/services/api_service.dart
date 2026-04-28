import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../constants/api_url.dart';
import '../models/auth_models.dart';
import '../models/ejecucion_models.dart';

class ApiService {
  String get baseUrl => ApiConstants.baseUrl;

  Map<String, String> _headers(String? token) {
    final h = {'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  dynamic _parseBody(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  String _extractError(dynamic json, String fallback) {
    if (json is Map) return json['message'] as String? ?? fallback;
    return fallback;
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<AuthResponse> login(String email, String password) async {
    final url = Uri.parse('$baseUrl${ApiConstants.loginEndpoint}');
    debugPrint('[ApiService] LOGIN URL: $url');
    try {
      final response = await http.post(url,
          headers: _headers(null),
          body: jsonEncode({'email': email, 'password': password}));
      debugPrint('[ApiService] LOGIN STATUS: ${response.statusCode}');
      debugPrint('[ApiService] LOGIN BODY: ${response.body}');
      final json = _parseBody(response);
      if (response.statusCode == 200 && json?['data'] != null) {
        return AuthResponse.fromJson(json['data'] as Map<String, dynamic>);
      }
      throw Exception(_extractError(json, 'Error al iniciar sesión'));
    } catch (e) {
      debugPrint('[ApiService] LOGIN EXCEPTION: $e');
      rethrow;
    }
  }

  Future<AuthResponse> registro(
      String nombreEmpresa, String nombreAdmin, String email, String password) async {
    final url = Uri.parse('$baseUrl${ApiConstants.registerEndpoint}');
    final response = await http.post(url,
        headers: _headers(null),
        body: jsonEncode({
          'nombreEmpresa': nombreEmpresa,
          'nombreAdmin': nombreAdmin,
          'email': email,
          'password': password,
        }));

    final json = _parseBody(response);
    if ((response.statusCode == 200 || response.statusCode == 201) && json?['data'] != null) {
      return AuthResponse.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw Exception(_extractError(json, 'Error al registrarse'));
  }

  // ── FCM Token ─────────────────────────────────────────────────────────────

  Future<void> actualizarFcmToken(String userId, String fcmToken, String token) async {
    final url = Uri.parse('$baseUrl${ApiConstants.usuariosBase}/$userId/fcm-token');
    final response = await http.put(url,
        headers: _headers(token),
        body: jsonEncode({'fcmToken': fcmToken}));
    if (response.statusCode != 200) {
      debugPrint('[ApiService] FCM token update falló: HTTP ${response.statusCode} - ${response.body}');
    }
  }

  // ── Ejecuciones ──────────────────────────────────────────────────────────

  Future<List<EjecucionDetallada>> listarTareasFuncionario(String userId, String token) async {
    final url = Uri.parse('$baseUrl${ApiConstants.ejecucionesBase}/funcionario/$userId');
    final response = await http.get(url, headers: _headers(token));
    final json = _parseBody(response);
    if (response.statusCode == 200 && json?['data'] != null) {
      return (json['data'] as List<dynamic>)
          .map((e) => EjecucionDetallada.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_extractError(json, 'Error al cargar tareas'));
  }

  Future<EjecucionDetallada> obtenerEjecucion(String ejecucionId, String token) async {
    final url = Uri.parse('$baseUrl${ApiConstants.ejecucionesBase}/$ejecucionId');
    final response = await http.get(url, headers: _headers(token));
    final json = _parseBody(response);
    if (response.statusCode == 200 && json?['data'] != null) {
      return EjecucionDetallada.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw Exception(_extractError(json, 'Error al obtener ejecución'));
  }

  Future<void> iniciarEjecucion(String ejecucionId, String token) async {
    final url = Uri.parse('$baseUrl${ApiConstants.ejecucionesBase}/$ejecucionId/iniciar');
    await http.put(url, headers: _headers(token));
  }

  Future<void> completarEjecucion(
      String ejecucionId, Map<String, dynamic> respuesta, String token) async {
    final url = Uri.parse('$baseUrl${ApiConstants.ejecucionesBase}/$ejecucionId/completar');
    final response = await http.put(url,
        headers: _headers(token),
        body: jsonEncode({'respuesta_formulario': respuesta}));
    if (response.statusCode != 200) {
      final json = _parseBody(response);
      throw Exception(_extractError(json, 'Error al completar tarea'));
    }
  }

  Future<void> rechazarEjecucion(
      String ejecucionId, String observaciones, String token) async {
    final url = Uri.parse('$baseUrl${ApiConstants.ejecucionesBase}/$ejecucionId/rechazar');
    final response = await http.put(url,
        headers: _headers(token),
        body: jsonEncode({'observaciones': observaciones}));
    if (response.statusCode != 200) {
      final json = _parseBody(response);
      throw Exception(_extractError(json, 'Error al rechazar tarea'));
    }
  }

  // ── Formularios ──────────────────────────────────────────────────────────

  Future<Formulario?> obtenerFormularioPorNodo(String nodoId, String token) async {
    final url = Uri.parse('$baseUrl${ApiConstants.formulariosBase}/nodo/$nodoId');
    final response = await http.get(url, headers: _headers(token));
    if (response.statusCode == 404) return null;
    final json = _parseBody(response);
    if (response.statusCode == 200 && json?['data'] != null) {
      return Formulario.fromJson(json['data'] as Map<String, dynamic>);
    }
    return null;
  }

  // ── Archivos ─────────────────────────────────────────────────────────────

  Future<String> subirArchivo(
      String filePath, String fileName, String mimeType, String token) async {
    final url = Uri.parse('$baseUrl${ApiConstants.archivosBase}/subir');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('archivo', filePath,
          filename: fileName));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final json = _parseBody(response);

    if (response.statusCode == 200 && json?['url'] != null) {
      return json['url'] as String;
    }
    throw Exception('Error al subir archivo');
  }

  // ── Políticas ─────────────────────────────────────────────────────────────

  Future<List<Politica>> listarPoliticasActivas(String token) async {
    final url = Uri.parse('$baseUrl${ApiConstants.politicasBase}');
    final response = await http.get(url, headers: _headers(token));
    final json = _parseBody(response);
    if (response.statusCode == 200 && json?['data'] != null) {
      return (json['data'] as List<dynamic>)
          .map((p) => Politica.fromJson(p as Map<String, dynamic>))
          .where((p) => p.estado == 'ACTIVA')
          .toList();
    }
    return [];
  }

  // ── Monitor ──────────────────────────────────────────────────────────────

  Future<MonitorPolitica> obtenerMonitor(String politicaId, String token) async {
    final url = Uri.parse('$baseUrl${ApiConstants.tramitesBase}/monitor/$politicaId');
    final response = await http.get(url, headers: _headers(token));
    final json = _parseBody(response);
    if (response.statusCode == 200 && json?['data'] != null) {
      return MonitorPolitica.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw Exception(_extractError(json, 'Error al cargar monitor'));
  }
}
