class ReporteOrdenCompra {
  final String ordenCompra;
  final String proveedor;
  final String fechaConfirmacion;
  final String divisa;
  final double tipoCambio;
  final String producto;
  final String descripcion;
  final double cantidad;
  final String unidadNegocio;
  final String equipo;
  final String pedido;
  final double precioUnitario;
  final String impuesto;
  final double sinImpuesto;
  final double conImpuesto;

  ReporteOrdenCompra({
    required this.ordenCompra,
    required this.proveedor,
    required this.fechaConfirmacion,
    required this.divisa,
    required this.tipoCambio,
    required this.producto,
    required this.descripcion,
    required this.cantidad,
    required this.unidadNegocio,
    required this.equipo,
    required this.pedido,
    required this.precioUnitario,
    required this.impuesto,
    required this.sinImpuesto,
    required this.conImpuesto,
  });

  factory ReporteOrdenCompra.fromJson(Map<String, dynamic> json) {
    return ReporteOrdenCompra(
      ordenCompra: (json['orden_compra'] ?? '').toString(),
      proveedor: (json['proveedor'] ?? '').toString(),
      fechaConfirmacion: (json['fecha_confirmacion'] ?? '').toString(),
      divisa: (json['divisa'] ?? 'PEN').toString(),
      tipoCambio: double.tryParse('${json['tipo_cambio']}') ?? 1.0,
      producto: (json['producto'] ?? '').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      cantidad: double.tryParse('${json['cantidad']}') ?? 0.0,
      unidadNegocio: (json['unidad_negocio'] ?? '').toString(),
      equipo: (json['equipo'] ?? '').toString(),
      pedido: (json['pedido'] ?? '').toString(),
      precioUnitario: double.tryParse('${json['precio_unitario']}') ?? 0.0,
      impuesto: (json['impuesto'] ?? 'Sin Impuesto').toString(),
      sinImpuesto: double.tryParse('${json['sin_impuesto']}') ?? 0.0,
      conImpuesto: double.tryParse('${json['con_impuesto']}') ?? 0.0,
    );
  }
}
