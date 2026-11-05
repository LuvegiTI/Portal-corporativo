import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../utils/mensaje_error.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _pageCtrl = PageController();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://portal.luvegi.com/api_luvegi',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  bool _loading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  static const Color primaryBlue = Color(0xFF003366);
  static const Color accentBlue = Color(0xFF00509E);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _parseResponse(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is String) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    throw Exception("Respuesta inválida del servidor");
  }

  Future<void> _solicitarCodigo() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = "Ingresa tu correo");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.post(
        '/request_reset.php',
        data: jsonEncode({'email': _emailCtrl.text.trim()}),
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.plain,
        ),
      );

      final data = _parseResponse(response.data);

      if (data['ok'] == true) {
        if (!mounted) return;

        _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        setState(() {
          _errorMessage = MensajeError.desdeCodigo(data['error']?.toString());
        });
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage = _getDioError(e);
      });
    } catch (e) {
      setState(() {
        _errorMessage = MensajeError.desdeExcepcion(e);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _cambiarPassword() async {
    if (_codeCtrl.text.trim().isEmpty || _newPassCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = "Completa los campos");
      return;
    }

    if (_newPassCtrl.text.trim().length < 8) {
      setState(() {
        _errorMessage = "La contraseña debe tener mínimo 8 caracteres";
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.post(
        '/reset_password.php',
        data: jsonEncode({
          'email': _emailCtrl.text.trim(),
          'codigo': _codeCtrl.text.trim(),
          'nueva_password': _newPassCtrl.text.trim(),
        }),
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.plain,
        ),
      );

      final data = _parseResponse(response.data);

      if (data['ok'] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Contraseña actualizada con éxito"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).maybePop();
      } else {
        setState(() {
          _errorMessage = MensajeError.desdeCodigo(data['error']?.toString());
        });
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage = _getDioError(e);
      });
    } catch (e) {
      setState(() {
        _errorMessage = MensajeError.desdeExcepcion(e);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _getDioError(DioException e) {
    final data = e.response?.data;

    try {
      final parsed = _parseResponse(data);
      if (parsed['error'] != null) {
        return MensajeError.desdeCodigo(parsed['error'].toString());
      }
    } catch (_) {}

    return MensajeError.desdeExcepcion(e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Recuperar Acceso',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
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
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStepCard(
                icon: Icons.mark_email_read_rounded,
                title: "Verifica tu Identidad",
                subtitle:
                    "Enviaremos un código de seguridad a tu correo institucional.",
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _emailCtrl,
                      label: "Correo Electrónico",
                      hint: "ejemplo@luvegi.com",
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 30),
                    _buildActionButton("ENVIAR CÓDIGO", _solicitarCodigo),
                  ],
                ),
              ),
              _buildStepCard(
                icon: Icons.security_rounded,
                title: "Nueva Contraseña",
                subtitle: "Ingresa el código que recibiste y tu nueva clave.",
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _codeCtrl,
                      label: "Código de Seguridad",
                      hint: "6 dígitos",
                      icon: Icons.pin_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _newPassCtrl,
                      label: "Nueva Contraseña",
                      hint: "Mínimo 8 caracteres",
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                    ),
                    const SizedBox(height: 30),
                    _buildActionButton("ACTUALIZAR CLAVE", _cambiarPassword),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() => _errorMessage = null);
                              _pageCtrl.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.ease,
                              );
                            },
                      child: const Text(
                        "Volver a enviar código",
                        style: TextStyle(color: accentBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 100),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 30),
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 25),
                if (_errorMessage != null) _buildErrorBanner(),
                child,
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInputField({
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
            color: primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          keyboardType: isPassword
              ? TextInputType.visiblePassword
              : TextInputType.text,
          textInputAction: TextInputAction.next,
          enableSuggestions: !isPassword,
          autocorrect: !isPassword,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: primaryBlue, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: primaryBlue, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 5,
          shadowColor: primaryBlue.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: _loading ? null : onPressed,
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
