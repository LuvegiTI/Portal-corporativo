class Usuario {
  final int id;
  final String usuario;
  final String nombre;

  Usuario({
    required this.id,
    required this.usuario,
    required this.nombre,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as int? ?? 0,
      usuario: map['usuario'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'usuario': usuario,
    'nombre': nombre,
  };
}
