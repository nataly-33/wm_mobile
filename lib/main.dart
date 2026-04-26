import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/auth/login_screen.dart';
import 'features/tareas/tareas_screen.dart';
import 'features/tareas/ejecutar_tarea_screen.dart';
import 'features/monitor/monitor_screen.dart';
import 'core/services/auth_service.dart';
import 'core/services/navigation_service.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await NotificationService.init(
      onTokenRefresh: (newToken) =>
          authService.sincronizarFcmTokenConValor(newToken),
    );
    await authService.sincronizarFcmTokenSesionActiva();
  } catch (e) {
    debugPrint('[main] Firebase no disponible: $e');
  }

  runApp(const WorkflowApp());
}

class WorkflowApp extends StatelessWidget {
  const WorkflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkflowManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFC0C080),
        scaffoldBackgroundColor: const Color(0xFF1a1a00),
        brightness: Brightness.dark,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2e2e14),
          elevation: 0,
        ),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFC0C080),
          surface: const Color(0xFF2e2e14),
          onSurface: const Color(0xFFF5F5E8),
        ),
      ),
      navigatorKey: NavigationService.navigatorKey,
      home: const LoginScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/tareas': (_) => const TareasScreen(),
        '/monitor': (_) => const MonitorScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/ejecutar_tarea') {
          final ejecucionId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => EjecutarTareaScreen(ejecucionId: ejecucionId),
          );
        }
        return null;
      },
    );
  }
}
