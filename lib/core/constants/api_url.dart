class ApiConstants {
  // Para desarrollo local con emulador Android (la máquina host se accede vía 10.0.2.2)
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // Para desarrollo local en iOS
  // static const String baseUrl = 'http://localhost:8080/api/v1';

  // Para producción en Azure
  // static const String baseUrl = 'https://wm-backend.azurewebsites.net/api/v1';

  static const String registerEndpoint = '/auth/registro';
  static const String loginEndpoint = '/auth/login';
  static const String healthEndpoint = '/auth/health';
}
