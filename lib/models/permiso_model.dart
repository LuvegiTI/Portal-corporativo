class Permiso {
  final int id;
  final String codigo;
  final String descripcion;
  final String modulo;

  Permiso({
    required this.id,
    required this.codigo,
    required this.descripcion,
    required this.modulo,
  });

  factory Permiso.fromMap(Map<String, dynamic> map) {
    return Permiso(
      id: map['id'] as int? ?? 0,
      codigo: map['codigo'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      modulo: map['modulo'] as String? ?? 'OTROS',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'codigo': codigo,
    'descripcion': descripcion,
    'modulo': modulo,
  };
}
