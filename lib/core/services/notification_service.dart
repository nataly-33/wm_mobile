import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'navigation_service.dart';
import '../../firebase_options.dart';

// Handler background: corre en isolate separado.
// FCM muestra la notificación automáticamente si el mensaje tiene payload
// "notification", así que aquí solo necesitamos inicializar Firebase.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[BGHandler] Mensaje en background: ${message.messageId}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init(
      {Future<void> Function(String token)? onTokenRefresh}) async {
    if (_initialized) return;

    try {
      const androidChannel = AndroidNotificationChannel(
        'workflow_channel',
        'WorkflowManager',
        description: 'Notificaciones del sistema de trámites',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          // Tap en notificación local (foreground): los datos de navegación
          // no están disponibles aquí, así que simplemente abrimos tareas.
          NavigationService.navigateTo('/tareas');
        },
      );

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Desactivar presentación automática en foreground para iOS
      // (en Android no tiene efecto, pero es buena práctica declararlo)
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      // Token rotado: sincronizar con backend
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[NotificationService] FCM token rotado');
        onTokenRefresh?.call(newToken);
      });

      // Mensajes en FOREGROUND: FCM no los muestra → los mostramos nosotros
      FirebaseMessaging.onMessage.listen((message) {
        _mostrarNotificacionLocal(message);
      });

      // Handler para background/killed
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Tap en notificación con la app en BACKGROUND (no killed)
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('[NotificationService] App abierta desde notificación background');
        _navegarSegunTipo(message.data);
      });

      // Tap en notificación con la app CERRADA (killed state)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NotificationService] App abierta desde notificación (killed)');
        // Diferir hasta que el árbol de widgets esté montado
        Future.delayed(const Duration(milliseconds: 500), () {
          _navegarSegunTipo(initialMessage.data);
        });
      }

      _initialized = true;
      debugPrint('[NotificationService] Inicializado correctamente');
    } catch (e) {
      debugPrint('[NotificationService] Error al inicializar: $e');
    }
  }

  static Future<String?> obtenerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('[NotificationService] FCM token: $token');
      return token;
    } catch (e) {
      debugPrint('[NotificationService] Error al obtener FCM token: $e');
      return null;
    }
  }

  static Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    try {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'workflow_channel',
            'WorkflowManager',
            channelDescription: 'Notificaciones del sistema de trámites',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      debugPrint('[NotificationService] Notificación foreground mostrada: ${notification.title}');
    } catch (e) {
      debugPrint('[NotificationService] Error al mostrar notificación: $e');
    }
  }

  static void _navegarSegunTipo(Map<String, dynamic> data) {
    final tipo = data['tipo'] as String?;
    switch (tipo) {
      case 'ASIGNACION':
        NavigationService.navigateTo('/tareas');
        break;
      case 'COMPLETADO':
      case 'RECHAZADO':
        NavigationService.navigateTo('/monitor');
        break;
      default:
        NavigationService.navigateTo('/tareas');
    }
  }
}
