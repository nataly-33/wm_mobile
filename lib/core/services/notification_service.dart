import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'navigation_service.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[BGHandler] Mensaje en background: ${message.messageId}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _localNotificationsReady = false;

  static Future<void> init(
      {Future<void> Function(String token)? onTokenRefresh}) async {
    if (_initialized) return;

    // Paso 1: Canal de notificaciones Android (necesario para que FCM muestre
    // notificaciones en background en Android 8+).
    const androidChannel = AndroidNotificationChannel(
      'workflow_channel',
      'WorkflowManager',
      description: 'Notificaciones del sistema de trámites',
      importance: Importance.high,
    );
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    } catch (e) {
      debugPrint('[NotificationService] No se pudo crear el canal: $e');
    }

    // Paso 2: Inicializar flutter_local_notifications (para mostrar en foreground).
    // Si falla por el ícono u otro motivo, el FCM de background sigue funcionando.
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (_) =>
            NavigationService.navigateTo('/tareas'),
      );
      _localNotificationsReady = true;
      debugPrint('[NotificationService] Local notifications OK');
    } catch (e) {
      debugPrint('[NotificationService] Local notifications no disponibles '
          '(foreground sin banner): $e');
    }

    // Paso 3: Configurar FCM — siempre, independiente de si local notifications falló.
    try {
      final messaging = FirebaseMessaging.instance;

      // Solicitar permiso (crítico en Android 13+)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[NotificationService] Permiso FCM: ${settings.authorizationStatus}');

      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[NotificationService] FCM token rotado');
        onTokenRefresh?.call(newToken);
      });

      // Foreground: FCM no muestra nada automáticamente → lo mostramos nosotros.
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[NotificationService] Mensaje en foreground: ${message.notification?.title}');
        if (_localNotificationsReady) {
          _mostrarNotificacionLocal(message);
        }
      });

      // Background/killed: el sistema muestra la notificación automáticamente
      // porque el mensaje lleva payload "notification". El handler solo
      // necesita inicializar Firebase.
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('[NotificationService] App abierta desde notificación background');
        _navegarSegunTipo(message.data);
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NotificationService] App abierta desde notificación (killed)');
        Future.delayed(const Duration(milliseconds: 500), () {
          _navegarSegunTipo(initialMessage.data);
        });
      }

      _initialized = true;
      debugPrint('[NotificationService] FCM inicializado correctamente');
    } catch (e) {
      debugPrint('[NotificationService] Error al inicializar FCM: $e');
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
