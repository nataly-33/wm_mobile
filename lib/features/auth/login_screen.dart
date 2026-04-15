import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _empresaController = TextEditingController();
  final _nombreController = TextEditingController();

  bool _isLoading = false;
  bool _showRegistro = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _empresaController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Por favor completa todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _authService.login(
        _emailController.text,
        _passwordController.text,
      );

      if (mounted && user != null) {
        _navigateBasedOnRole(user.rol);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleRegistro() async {
    if (_empresaController.text.isEmpty ||
        _nombreController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Por favor completa todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _authService.registro(
        _empresaController.text,
        _nombreController.text,
        _emailController.text,
        _passwordController.text,
      );

      if (mounted && user != null) {
        _navigateBasedOnRole(user.rol);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateBasedOnRole(String rol) {
    switch (rol) {
      case 'FUNCIONARIO':
        Navigator.of(context).pushReplacementNamed('/tareas');
        break;
      case 'ADMIN_GENERAL':
      case 'ADMIN_DEPARTAMENTO':
        Navigator.of(context).pushReplacementNamed('/monitor');
        break;
      default:
        Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a00),
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a1a00), Color(0xFF2e2e14)],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Color(0xFF2e2e14).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF9d9d60).withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'WorkflowManager',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC0C080),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Error message
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF44250).withOpacity(0.15),
                          border: const Border(
                            left: BorderSide(
                              color: Color(0xFFF44250),
                              width: 4,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFff6b7a),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    // Forms
                    if (!_showRegistro) ...[
                      const Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          fontSize: 20,
                          color: Color(0xFFF5F5E8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'tu@email.com',
                        icon: Icons.email,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        hint: 'Mínimo 6 caracteres',
                        icon: Icons.lock,
                        isPassword: true,
                      ),
                      const SizedBox(height: 30),
                      _buildButton(
                        label: _isLoading ? 'Iniciando sesión...' : 'Iniciar Sesión',
                        onPressed: _isLoading ? null : _handleLogin,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '¿No tienes cuenta? ',
                            style: TextStyle(
                              color: Color(0xFF9d9d60),
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showRegistro = true),
                            child: const Text(
                              'Registrarse aquí',
                              style: TextStyle(
                                color: Color(0xFFC0C080),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'Crear Nueva Empresa',
                        style: TextStyle(
                          fontSize: 20,
                          color: Color(0xFFF5F5E8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _empresaController,
                        label: 'Nombre de la Empresa',
                        hint: 'Mi Empresa',
                        icon: Icons.business,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _nombreController,
                        label: 'Tu Nombre',
                        hint: 'Juan Pérez',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'tu@email.com',
                        icon: Icons.email,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        hint: 'Mínimo 6 caracteres',
                        icon: Icons.lock,
                        isPassword: true,
                      ),
                      const SizedBox(height: 30),
                      _buildButton(
                        label: _isLoading ? 'Registrando...' : 'Registrarse',
                        onPressed: _isLoading ? null : _handleRegistro,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '¿Ya tienes cuenta? ',
                            style: TextStyle(
                              color: Color(0xFF9d9d60),
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showRegistro = false),
                            child: const Text(
                              'Inicia sesión aquí',
                              style: TextStyle(
                                color: Color(0xFFC0C080),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFC0C080),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(
            color: Color(0xFFF5F5E8),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF9d9d60)),
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9d9d60)),
            filled: true,
            fillColor: Color(0xFF1a1a00).withOpacity(0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                color: Color(0xFF9d9d60),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: const Color(0xFF9d9d60).withOpacity(0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                color: Color(0xFFC0C080),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC0C080),
          disabledBackgroundColor: const Color(0xFFC0C080).withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1a1a00),
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
