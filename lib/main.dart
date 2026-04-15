import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      ),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/tareas': (context) => const PlaceholderScreen(title: 'Tareas'),
        '/monitor': (context) => const PlaceholderScreen(title: 'Monitor'),
      },
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Pantalla en construcción',
              style: TextStyle(fontSize: 18, color: Color(0xFFC0C080)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0C080),
              ),
              child: const Text(
                'Volver al Login',
                style: TextStyle(color: Color(0xFF1a1a00)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
