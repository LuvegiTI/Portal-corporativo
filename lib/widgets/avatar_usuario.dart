import 'package:flutter/material.dart';

/// Avatar del usuario con la foto del personal (Odoo hr.employee).
///
/// La foto se sirve por `foto_empleado.php`, que exige el token de sesion,
/// por eso se manda como header. Si el usuario no cruza con Odoo, o la foto
/// no existe, cae al icono de persona.
class AvatarUsuario extends StatelessWidget {
  static const String baseUrl = 'https://portal.luvegi.com/api_luvegi';

  final String token;
  final String usuarioId;
  final double radio;
  final Color colorFondo;
  final Color colorIcono;
  final double tamanoIcono;

  const AvatarUsuario({
    super.key,
    required this.token,
    required this.usuarioId,
    this.radio = 20,
    this.colorFondo = const Color(0xFF0B4A82),
    this.colorIcono = Colors.white,
    this.tamanoIcono = 20,
  });

  String? get _fotoUrl {
    final id = int.tryParse(usuarioId) ?? 0;
    if (id <= 0) return null;
    return '$baseUrl/foto_empleado.php?usuario_id=$id';
  }

  @override
  Widget build(BuildContext context) {
    final url = _fotoUrl;
    final icono = Icon(
      Icons.person_rounded,
      color: colorIcono,
      size: tamanoIcono,
    );

    return CircleAvatar(
      radius: radio,
      backgroundColor: colorFondo,
      child: url == null
          ? icono
          : ClipOval(
              child: Image.network(
                url,
                width: radio * 2,
                height: radio * 2,
                fit: BoxFit.cover,
                headers: {'Authorization': 'Bearer $token'},
                errorBuilder: (_, _, _) => icono,
              ),
            ),
    );
  }
}
