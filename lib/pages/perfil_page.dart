import 'package:flutter/material.dart';

class PerfilPage extends StatelessWidget {
  final String nombre;
  final String rol;
  final String correo;
  final String usuarioId;
  final String token;

  const PerfilPage({
    super.key,
    required this.nombre,
    required this.rol,
    required this.correo,
    required this.usuarioId,
    required this.token,
  });

  /// URL de la foto del personal (Odoo hr.employee). El endpoint exige el
  /// token de sesion, asi que se envia como header.
  String get _fotoUrl {
    final id = int.tryParse(usuarioId) ?? 0;
    if (id <= 0) return '';
    return 'https://portal.luvegi.com/api_luvegi/foto_empleado.php?usuario_id=$id';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo gris muy claro para que las tarjetas blancas resalten
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 30),

            // --- SECCIÓN FOTO DE PERFIL ---
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade200, const Color(0xFF003366)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: _fotoUrl.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              size: 80,
                              color: Color(0xFF003366),
                            )
                          : ClipOval(
                              child: Image.network(
                                _fotoUrl,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                headers: {
                                  'Authorization': 'Bearer $token',
                                },
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person_rounded,
                                  size: 80,
                                  color: Color(0xFF003366),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003366),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003366).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      rol.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- TARJETA DE INFORMACIÓN "FACHERA" ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDataRow(
                      Icons.alternate_email_rounded,
                      "Cuenta / Correo",
                      correo,
                    ),
                    _customDivider(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // --- BOTÓN DE SALIDA ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  foregroundColor: Colors.redAccent.shade700,
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.05),
                ),
                child: const Text(
                  "Regresar al Inicio",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _customDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.withValues(alpha: 0.06),
      indent: 70,
      endIndent: 20,
    );
  }

  Widget _buildDataRow(
    IconData icon,
    String label,
    String value, {
    bool isStatus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: const Color(0xFF003366), size: 24),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            color: isStatus ? Colors.green.shade600 : const Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        trailing: isStatus
            ? const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 22,
              )
            : const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.black12,
                size: 14,
              ),
        ),
      ),
    );
  }
}
