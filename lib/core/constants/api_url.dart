import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8080/api/v1';
  static String get wsUrl =>
      dotenv.env['WS_URL'] ?? 'ws://10.0.2.2:8080/ws-native';

  // Auth
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/registro';
  static const String healthEndpoint = '/auth/health';

  // Recursos
  static const String ejecucionesBase = '/ejecuciones';
  static const String tramitesBase = '/tramites';
  static const String formulariosBase = '/formularios';
  static const String politicasBase = '/politicas';
  static const String archivosBase = '/archivos';
  static const String usuariosBase = '/usuarios';
}
