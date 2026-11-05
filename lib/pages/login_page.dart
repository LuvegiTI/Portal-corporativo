import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/auditoria_service.dart';
import 'forgot_password_page.dart';
import 'auth_gate.dart';
import 'api_client.dart';
import '../utils/mensaje_error.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService();
  final _auditoria = AuditoriaService();

  bool _loading = false;
  bool _isPasswordVisible = false;
  String? _error;

  static const Color primaryBlue = Color(0xFF003366);
  static const Color accentBlue = Color(0xFF00509E);
  Future<void> _login() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Por favor, completa todos los campos');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _auth.login(
        usuario: _userCtrl.text.trim().toLowerCase(),
        password: _passCtrl.text.trim(),
        licencia: '',
        hardwareId: 'WEB',
      );

      // --- LÓGICA DE VALIDACIÓN DEL BACKEND ---
      if (res['ok'] != true) {
        String errorMsg = res['error'] ?? 'Error desconocido';

        setState(() {
          if (errorMsg == 'USUARIO_BLOQUEADO') {
            _error =
                'Tu cuenta ha sido bloqueada. Envíe un correo a sistemas@luvegi.com para reestablecerla';
          } else if (errorMsg == 'CREDENCIALES_INVALIDAS') {
            // Usamos los datos extras que envía tu nuevo PHP
            int? restantes = res['restantes'];
            _error = restantes != null
                ? 'Contraseña incorrecta'
                : 'Usuario o contraseña incorrectos.';
          } else if (errorMsg == 'USUARIO_NO_ENCONTRADO') {
            _error = 'El usuario ingresado no existe.';
          } else {
            _error = res['mensaje'] ?? 'No se pudo iniciar sesión.';
          }
        });
        _registrarIntentoLogin(_userCtrl.text.trim(), false, errorMsg);
        return;
      }
      // --- LOGIN EXITOSO ---
      final String token = res['token'] ?? '';
      final Map<String, dynamic> u = Map<String, dynamic>.from(
        res['usuario'] ?? {},
      );
      final String idStr = u['id'].toString();

      await _auth.saveSession(
        token: token,
        rol: (u['rol'] ?? 'USUARIO').toString().toUpperCase(),
        nombre: u['nombre'] ?? 'Sin Nombre',
        correo: u['usuario'] ?? 'sin@correo.com',
        permisos: List<String>.from(u['permisos'] ?? []),
        usuarioId: idStr,
      );

      // Un solo watcher de sesión (ApiClient). Antes había dos polling
      // duplicados: este y otro en HomePage.
      ApiClient().startSessionCheck();

      _registrarIntentoLogin(_userCtrl.text.trim(), true, 'LOGIN_OK');

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('LOGIN ERROR => $e');
      String msg = MensajeError.desdeExcepcion(e);
      setState(() => _error = msg);
      _registrarIntentoLogin(_userCtrl.text.trim(), false, 'ERROR_CONEXION');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Registra el intento en la bitácora sin bloquear la UI.
  void _registrarIntentoLogin(String usuario, bool exito, String motivo) {
    if (usuario.isEmpty) return;
    try {
      _auditoria
          .registrarIntentoLogin(
            usuario: usuario,
            exito: exito,
            motivo: motivo,
            dispositivo: 'WEB',
          )
          .catchError((_) {});
    } catch (_) {}
  }

  // ... (El resto del código build, _buildTextField y _buildErrorWidget se mantienen igual)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryBlue, Color(0xFF001A33)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    size: 70,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'LUVEGI SISTEMAS',
                  style: TextStyle(
                    fontSize: 26,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Gestión y Control Profesional',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(35),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 25),
                      _buildTextField(
                        controller: _userCtrl,
                        label: 'Usuario / Correo',
                        hint: 'ejemplo@luvegi.com',
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passCtrl,
                        label: 'Contraseña',
                        hint: '••••••••',
                        icon: Icons.vpn_key_rounded,
                        isPassword: true,
                        obscureText: !_isPasswordVisible,
                        togglePassword: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 15),
                        _buildErrorWidget(),
                      ],
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,

                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,

                            foregroundColor: Colors.white,

                            elevation: 8,

                            shadowColor: primaryBlue.withValues(alpha: 0.5),

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),

                          onPressed: _loading ? null : _login,

                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'INGRESAR',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordPage(),
                            ),
                          ),

                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(
                              color: accentBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

    bool obscureText = false,

    VoidCallback? togglePassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          label,
          style: const TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: controller,

          obscureText: obscureText,

          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),

          decoration: InputDecoration(
            hintText: hint,

            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w400,
            ),

            prefixIcon: Icon(icon, color: primaryBlue, size: 22),

            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: primaryBlue.withValues(alpha: 0.8),
                    ),

                    onPressed: togglePassword,
                  )
                : null,

            filled: true,

            fillColor: Colors.grey.shade100,

            contentPadding: const EdgeInsets.symmetric(vertical: 18),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: primaryBlue, width: 2),
            ),
          ),

          onSubmitted: (_) => _login(),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: Colors.red.shade50,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: Colors.red.shade200),
      ),

      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
