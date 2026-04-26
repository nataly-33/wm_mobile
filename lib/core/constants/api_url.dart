class ApiConstants {
  // Dispositivo físico en red local: usa IP local
  static const String baseUrl = 'http://192.168.0.15:8080/api/v1';
  // WebSocket nativo (sin SockJS) para Flutter
  static const String wsUrl = 'ws://192.168.0.15:8080/ws-native';

  // Para emulador Android: 10.0.2.2 apunta al localhost del host
  // static const String baseUrl = 'http://10.0.2.2:8080/api/v1';
  // static const String wsUrl = 'ws://10.0.2.2:8080/ws-native';

  // Producción Azure
  // static const String baseUrl = 'https://wm-backend.azurewebsites.net/api/v1';
  // static const String wsUrl = 'wss://wm-backend.azurewebsites.net/ws-native';

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
