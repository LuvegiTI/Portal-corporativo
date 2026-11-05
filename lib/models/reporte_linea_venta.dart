class ReporteLineaVenta {
  final String concepto;
  final String numeroOrdenVenta;
  final String cliente;
  final String ruc;
  final String ejecutivoLuvegi;
  final String fechaCreacion;
  final String fechaConfirmacion;
  final String unidadNegocio;
  final String pedido;
  final String producto;
  final String moneda;
  final String unidadMedida;
  final String cantidad;
  final String cantidadEntregada;
  final String cantidadPorEntregar;
  final String cantidadFacturada;
  final String precioUnitario;
  final String descuentoPorcentaje;
  final String descuentoOtorgado;
  final String precioTotalSinImp;
  final String precioTotalConImp;

  ReporteLineaVenta({
    required this.concepto,
    required this.numeroOrdenVenta,
    required this.cliente,
    required this.ruc,
    required this.ejecutivoLuvegi,
    required this.fechaCreacion,
    required this.fechaConfirmacion,
    required this.unidadNegocio,
    required this.pedido,
    required this.producto,
    required this.moneda,
    required this.unidadMedida,
    required this.cantidad,
    required this.cantidadEntregada,
    required this.cantidadPorEntregar,
    required this.cantidadFacturada,
    required this.precioUnitario,
    required this.descuentoPorcentaje,
    required this.descuentoOtorgado,
    required this.precioTotalSinImp,
    required this.precioTotalConImp,
  });

  factory ReporteLineaVenta.fromJson(Map<String, dynamic> json) {
    return ReporteLineaVenta(
      concepto: json['Concepto']?.toString() ?? '',
      numeroOrdenVenta: json['Numero de orden de venta']?.toString() ?? '',
      cliente: json['Cliente']?.toString() ?? '',
      ruc: json['RUC']?.toString() ?? '',
      ejecutivoLuvegi: json['Ejecutivo Luvegi']?.toString() ?? '',
      fechaCreacion: json['Fecha de Creacion']?.toString() ?? '',
      fechaConfirmacion: json['Fecha de confirmación']?.toString() ?? '',
      unidadNegocio: json['Unidad de Negocio']?.toString() ?? '',
      pedido: json['Pedido']?.toString() ?? '',
      producto: json['Producto']?.toString() ?? '',
      moneda: json['Moneda']?.toString() ?? '',
      unidadMedida: json['Unidad de Medida']?.toString() ?? '',
      cantidad: json['Cantidad']?.toString() ?? '',
      cantidadEntregada: json['Cantidad Entregada']?.toString() ?? '',
      cantidadPorEntregar: json['Cantidad por Entregar']?.toString() ?? '',
      cantidadFacturada: json['Cantidad Facturada']?.toString() ?? '',
      precioUnitario: json['Precio unitario (sin imp.)']?.toString() ?? '',
      descuentoPorcentaje: json['% descuento']?.toString() ?? '',
      descuentoOtorgado: json['Descuento Otorgado']?.toString() ?? '',
      precioTotalSinImp: json['Precio total (sin imp.)']?.toString() ?? '',
      precioTotalConImp: json['Precio Total (con imp.)']?.toString() ?? '',
    );
  }
}
