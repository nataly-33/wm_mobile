# Guía de Desarrollo — wm_mobile

Referencia técnica completa para el desarrollo de la app Flutter del sistema WorkflowManager.

---

## Arquitectura general

```
Flutter App
│
├── core/           → Servicios globales y modelos compartidos
│   ├── constants/  → URLs, constantes de la app
│   ├── models/     → Clases Dart con fromJson/toJson
│   └── services/   → Llamadas HTTP, WebSocket, notificaciones
│
├── features/       → Pantallas organizadas por funcionalidad
│   ├── auth/       → Login
│   ├── funcionario/ → Tareas y ejecución
│   └── admin/      → Monitor de políticas
│
└── widgets/        → Componentes UI reutilizables
```

### Principios de diseño

1. **StatefulWidget para pantallas** con datos remotos. `StatelessWidget` solo para widgets simples que reciben todo como parámetros.
2. **Serialización manual** con `fromJson`/`toJson`. Sin `json_serializable` ni otros generadores.
3. **ApiService centralizado**: todas las llamadas HTTP pasan por `ApiService`, que maneja JWT y errores globalmente.
4. **Sin `dynamic`**: todo el JSON se castea explícitamente. Nunca `json['campo']` sin `as String`, `as int`, etc.

---

## ApiService — El cliente HTTP

`ApiService` es el núcleo de las llamadas al backend. Maneja el JWT automáticamente.

```dart
// lib/core/services/api_service.dart
class ApiService {
  final String baseUrl = ApiConstants.baseUrl;

  Future<Map<String, dynamic>> get(String endpoint) async {
    final token = await LocalStorage.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    final token = await LocalStorage.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    final token = await LocalStorage.getToken();
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    if (response.statusCode == 401) {
      // Token expirado — AuthService se encarga de limpiar y navegar a login
      throw const UnauthorizedException();
    }
    final message = body['message'] as String? ?? 'Error del servidor';
    throw ApiException(message);
  }
}
```

---

## Autenticación y almacenamiento del token

### LocalStorage — `flutter_secure_storage`

```dart
// lib/core/services/local_storage.dart
class LocalStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';
  static const _userKey = 'current_user';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final data = await _storage.read(key: _userKey);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }
}
```

### AuthService — Login y logout

```dart
// lib/core/services/auth_service.dart
class AuthService {
  final ApiService _api = ApiService();

  Future<UserModel> login(String email, String password) async {
    final response = await _api.post('/api/v1/auth/login', {
      'email': email,
      'password': password,
    });

    final data = response['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = UserModel.fromJson(data['usuario'] as Map<String, dynamic>);

    // Guardar en almacenamiento seguro
    await LocalStorage.saveToken(token);
    await LocalStorage.saveUser(data['usuario'] as Map<String, dynamic>);

    return user;
  }

  Future<void> logout() async {
    await LocalStorage.clearAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await LocalStorage.getToken();
    return token != null;
  }
}
```

---

## WebSockets — Tiempo real

### SocketService

```dart
// lib/core/services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? _socket;

  void conectar(String token) {
    _socket = IO.io(
      ApiConstants.wsUrl,
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .build(),
    );

    _socket!.onConnect((_) {
      print('WebSocket conectado');
    });

    _socket!.onDisconnect((_) {
      print('WebSocket desconectado');
    });
  }

  void suscribirAPolitica(String politicaId, Function(dynamic) callback) {
    _socket?.on('politica/$politicaId', callback);
  }

  void suscribirAUsuario(String usuarioId, Function(dynamic) callback) {
    _socket?.on('usuario/$usuarioId', callback);
  }

  void desconectar() {
    _socket?.disconnect();
    _socket = null;
  }
}
```

### Uso en MonitorScreen

```dart
late SocketService _socketService;

@override
void initState() {
  super.initState();
  _cargarDatos();
  _conectarSocket();
}

void _conectarSocket() async {
  final token = await LocalStorage.getToken();
  _socketService = SocketService();
  _socketService.conectar(token!);
  _socketService.suscribirAPolitica(widget.politicaId, (data) {
    // Actualizar color del nodo sin recargar
    setState(() {
      _actualizarEstadoNodo(data['nodoId'], data['estado']);
    });
  });
}

@override
void dispose() {
  _socketService.desconectar();
  super.dispose();
}
```

---

## Push Notifications — FCM

### Flujo de notificaciones

```
1. App inicia → NotificationService.init() en main.dart
2. Se obtiene FCM token del dispositivo
3. Se envía al backend: PUT /api/v1/usuarios/{id}/fcm-token
4. Backend envía push cuando corresponde (nueva tarea, trámite completado)
5. App recibe la push:
   - Foreground: flutter_local_notifications muestra banner
   - Background/terminada: sistema operativo muestra la notificación
6. Tap en notificación → navegar a la pantalla correspondiente
```

### NotificationService

```dart
// lib/core/services/notification_service.dart
class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Pedir permisos
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Inicializar notificaciones locales (para foreground)
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Escuchar mensajes en foreground
    FirebaseMessaging.onMessage.listen((message) {
      _mostrarNotificacionLocal(message);
    });

    // Manejar tap cuando la app estaba en background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navegarSegunNotificacion(message.data);
    });
  }

  static Future<String?> obtenerToken() async {
    return await _fcm.getToken();
  }

  static void _mostrarNotificacionLocal(RemoteMessage message) {
    _local.show(
      message.hashCode,
      message.notification?.title ?? 'WorkflowManager',
      message.notification?.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'workflow_channel',
          'WorkflowManager',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Navegar según el payload de la notificación
  }

  static void _navegarSegunNotificacion(Map<String, dynamic> data) {
    final tipo = data['tipo'] as String?;
    if (tipo == 'ASIGNACION') {
      // Navegar a /tareas
    } else if (tipo == 'COMPLETADO') {
      // Navegar a /monitor
    }
  }
}
```

---

## Formularios dinámicos

El formulario de cada nodo se genera dinámicamente según los campos definidos en el backend.

```dart
// lib/features/funcionario/ejecutar_tarea_screen.dart

Widget _buildCampo(Campo campo) {
  switch (campo.tipo) {
    case 'TEXTO':
      return _buildTextField(campo);
    case 'NUMERO':
      return _buildNumberField(campo);
    case 'FECHA':
      return _buildDateField(campo);
    case 'SELECCION':
      return _buildDropdown(campo);
    case 'ARCHIVO':
    case 'IMAGEN':
      return _buildFilePicker(campo);
    default:
      return const SizedBox.shrink();
  }
}

Widget _buildTextField(Campo campo) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        campo.etiqueta + (campo.requerido ? ' *' : ''),
        style: const TextStyle(color: Color(0xFFf5f5e8), fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      TextFormField(
        decoration: InputDecoration(
          hintText: campo.etiqueta,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: const Color(0xFF2e2e14),
        ),
        style: const TextStyle(color: Color(0xFFf5f5e8)),
        validator: campo.requerido
          ? (val) => val?.isEmpty == true ? 'Campo requerido' : null
          : null,
        onSaved: (val) => _respuestas[campo.nombre] = val,
      ),
      const SizedBox(height: 16),
    ],
  );
}

Widget _buildFilePicker(Campo campo) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(campo.etiqueta, style: const TextStyle(color: Color(0xFFf5f5e8))),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: () => _seleccionarArchivo(campo),
        icon: const Icon(Icons.attach_file),
        label: const Text('Seleccionar archivo'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF565620),
        ),
      ),
      if (_archivosSeleccionados[campo.nombre] != null)
        Text(
          _archivosSeleccionados[campo.nombre]!.split('/').last,
          style: const TextStyle(color: Color(0xFF9D9D60), fontSize: 12),
        ),
      const SizedBox(height: 16),
    ],
  );
}

Future<void> _seleccionarArchivo(Campo campo) async {
  final result = await FilePicker.platform.pickFiles();
  if (result != null) {
    final path = result.files.single.path!;
    // Subir a Azure Blob via backend
    final url = await _uploadService.subir(path);
    setState(() { _archivosSeleccionados[campo.nombre] = url; });
    _respuestas[campo.nombre] = url;
  }
}
```

---

## Colores — Constantes

Siempre usar las constantes de `common_widgets.dart`. Nunca hardcodear colores en las pantallas.

```dart
// lib/widgets/common_widgets.dart
const Color primaryLight = Color(0xFFC0C080);
const Color primaryMid   = Color(0xFF9D9D60);
const Color primaryDark  = Color(0xFF333300);

const Color bgDark    = Color(0xFF1a1a00);
const Color bgPanel   = Color(0xFF242410);
const Color bgCard    = Color(0xFF2e2e14);
const Color borderCol = Color(0xFF565620);

const Color textPrimary = Color(0xFFf5f5e8);
const Color textMuted   = Color(0xFF9D9D60);

const Color success = Color(0xFF6BD968);
const Color danger  = Color(0xFFF44250);
const Color warning = Color(0xFFFECC1B);
const Color info    = Color(0xFF3992FF);
```

---

## Comandos de referencia rápida

```bash
# Instalar dependencias
flutter pub get

# Ejecutar en debug
flutter run

# Ejecutar en dispositivo específico
flutter run -d <device-id>

# Ver dispositivos disponibles
flutter devices

# Verificar errores
flutter analyze

# Tests
flutter test

# Build APK debug
flutter build apk --debug

# Build APK release
flutter build apk --release

# Limpiar caché
flutter clean && flutter pub get

# Actualizar dependencias
flutter pub upgrade
```

---

## Herramientas recomendadas

| Herramienta | Uso |
|-------------|-----|
| **Android Studio** | IDE con emulador Android incluido |
| **VS Code + Flutter extension** | Alternativa más ligera |
| **Flutter DevTools** | Debuggear UI, performance, memoria |
| **Postman** | Verificar endpoints del backend |
| **MongoDB Compass** | Ver datos en la base de datos |

---

## Glosario

| Término | Significado |
|---------|-------------|
| StatefulWidget | Widget que tiene estado interno mutable (`setState`) |
| StatelessWidget | Widget sin estado, recibe todo como parámetros |
| initState | Método que se ejecuta al crear el widget (como ngOnInit de Angular) |
| dispose | Método que se ejecuta al destruir el widget (limpiar recursos) |
| BuildContext | Contexto de ubicación del widget en el árbol |
| FutureBuilder | Widget que construye la UI según el estado de un Future |
| RefreshIndicator | Pull-to-refresh en listas |
| FlutterSecureStorage | Almacenamiento cifrado en el dispositivo |
