class ReporteConsumo {
  final String fecha;
  final String proveedor;
  final String tipoOperacionComprobante;
  final String refComprobante;
  final String refOrigen;
  final String codigoProducto;
  final String producto;
  final String etiqueta;
  final String cantidad;
  final String moneda;
  final String precioOrigen;
  final String tipoCambio;
  final String precioPen;
  final String cuentaAnalitica;
  final String unidadNegocio;
  final String equipo;
  final String pedido;
  final String origen;

  ReporteConsumo({
    required this.fecha,
    required this.proveedor,
    required this.tipoOperacionComprobante,
    required this.refComprobante,
    required this.refOrigen,
    required this.codigoProducto,
    required this.producto,
    required this.etiqueta,
    required this.cantidad,
    required this.moneda,
    required this.precioOrigen,
    required this.tipoCambio,
    required this.precioPen,
    required this.cuentaAnalitica,
    required this.unidadNegocio,
    required this.equipo,
    required this.pedido,
    required this.origen,
  });

  factory ReporteConsumo.fromJson(Map<String, dynamic> json) {
    return ReporteConsumo(
      fecha: '${json['fecha'] ?? ''}',
      proveedor: '${json['proveedor'] ?? ''}',
      tipoOperacionComprobante: '${json['tipo_operacion_comprobante'] ?? ''}',
      refComprobante: '${json['ref_comprobante'] ?? ''}',
      refOrigen: '${json['ref_origen'] ?? ''}',
      codigoProducto: '${json['codigo_producto'] ?? ''}',
      producto: '${json['producto'] ?? ''}',
      etiqueta: '${json['etiqueta'] ?? ''}',
      cantidad: '${json['cantidad'] ?? ''}',
      moneda: '${json['moneda'] ?? ''}',
      precioOrigen: '${json['precio_origen'] ?? ''}',
      tipoCambio: '${json['tipo_cambio'] ?? ''}',
      precioPen: '${json['precio_pen'] ?? ''}',
      cuentaAnalitica: '${json['cuenta_analitica'] ?? ''}',
      unidadNegocio: '${json['unidad_negocio'] ?? ''}',
      equipo: '${json['equipo'] ?? ''}',
      pedido: '${json['pedido'] ?? ''}',
      origen: '${json['origen'] ?? ''}',
    );
  }
}