class ReporteGrupoElectrogeno {
  final String categoria;
  final String producto;
  final double aLaMano;
  final double entrante;
  final double saliente;
  final double disponible;
  final String listaPrecios;
  final double precioFijo;
  final bool tieneRegla;

  ReporteGrupoElectrogeno({
    required this.categoria,
    required this.producto,
    required this.aLaMano,
    required this.entrante,
    required this.saliente,
    required this.disponible,
    required this.listaPrecios,
    required this.precioFijo,
    required this.tieneRegla,
  });

  factory ReporteGrupoElectrogeno.fromJson(Map<String, dynamic> json) {
    return ReporteGrupoElectrogeno(
      categoria: (json['categoria'] ?? '').toString(),
      producto: (json['producto'] ?? '').toString(),
      aLaMano: double.tryParse('${json['a_la_mano']}') ?? 0.0,
      entrante: double.tryParse('${json['entrante']}') ?? 0.0,
      saliente: double.tryParse('${json['saliente']}') ?? 0.0,
      disponible: double.tryParse('${json['disponible']}') ?? 0.0,
      listaPrecios: (json['lista_precios'] ?? '').toString(),
      precioFijo: double.tryParse('${json['precio_fijo']}') ?? 0.0,
      tieneRegla: json['tiene_regla'] == true,
    );
  }
}
