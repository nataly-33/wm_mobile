import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_url.dart';

class AgenteApiService {
  String get _base => '${ApiConstants.baseUrl}/cliente/agente';

  Map<String, String> _headers(String? token) {
    final h = {'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  /// Enviar mensaje al agente y obtener respuesta.
  Future<Map<String, dynamic>> enviarMensaje({
    required String clienteId,
    required String mensaje,
    String? conversacionId,
    String tipo = 'texto',
    String? token,
  }) async {
    final uri = Uri.parse('$_base/mensaje');
    final body = jsonEncode({
      'conversacionId': conversacionId,
      'clienteId': clienteId,
      'mensaje': mensaje,
      'tipo': tipo,
    });
    final response = await http.post(uri, headers: _headers(token), body: body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al enviar mensaje: ${response.statusCode}');
  }

  /// Notificar archivo subido al agente.
  Future<Map<String, dynamic>> notificarArchivo({
    required String conversacionId,
    required String clienteId,
    required String archivoUrl,
    required String nombreArchivo,
    String? token,
  }) async {
    final uri = Uri.parse('$_base/subir-archivo');
    final body = jsonEncode({
      'conversacionId': conversacionId,
      'clienteId': clienteId,
      'archivoUrl': archivoUrl,
      'nombreArchivo': nombreArchivo,
    });
    final response = await http.post(uri, headers: _headers(token), body: body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al notificar archivo: ${response.statusCode}');
  }

  /// Obtener estado de un tramite para el cliente.
  Future<Map<String, dynamic>> obtenerEstadoTramite({
    required String tramiteId,
    String? token,
  }) async {
    final uri = Uri.parse('$_base/estado-tramite/$tramiteId');
    final response = await http.get(uri, headers: _headers(token));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al obtener estado: ${response.statusCode}');
  }

  /// Historial de conversaciones del cliente.
  Future<List<dynamic>> obtenerHistorial({
    required String clienteId,
    String? token,
  }) async {
    final uri = Uri.parse('$_base/historial?clienteId=$clienteId');
    final response = await http.get(uri, headers: _headers(token));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return (data['data'] as List?) ?? [];
    }
    throw Exception('Error al obtener historial: ${response.statusCode}');
  }
}
