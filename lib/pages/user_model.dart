class Usuario {
  final String id;
  final String nombre;
  final String correo;
  final String rol;

  Usuario({required this.id, required this.nombre, required this.correo, required this.rol});

  // Mapea el JSON que devuelve tu PHP
  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'].toString(),
      nombre: json['nombre'],
      correo: json['usuario'],
      rol: json['rol'],
    );
  }
}