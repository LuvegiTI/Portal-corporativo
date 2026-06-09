class Usuario {
  final int id;
  final String email;
  final String nombre;
  final String rol;
  final bool activo;

  Usuario({
    required this.id,
    required this.email,
    required this.nombre,
    required this.rol,
    required this.activo,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] ?? 0,
      email: map['usuario'] ?? '',
      nombre: map['nombre'] ?? '',
      rol: map['rol'] ?? 'USUARIO',
      activo: map['activo'] == 1,
    );
  }
}
