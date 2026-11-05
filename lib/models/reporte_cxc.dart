class ReporteCxcFila {
  final String cliente;
  final String tipoComprobante;
  final String numeroDocumento;
  final String unidadNegocio;
  final String equipo;
  final String pedido;
  final String fechaFactura;
  final String fechaEsperada;
  final String moneda;
  final String cuenta;
  final double divisaImporte;
  final double aLaFecha;
  final double rango130;
  final double rango3160;
  final double rango6190;
  final double rango91120;
  final double antiguos;
  final double total;

  ReporteCxcFila({
    required this.cliente,
    required this.tipoComprobante,
    required this.numeroDocumento,
    required this.unidadNegocio,
    required this.equipo,
    required this.pedido,
    required this.fechaFactura,
    required this.fechaEsperada,
    required this.moneda,
    required this.cuenta,
    required this.divisaImporte,
    required this.aLaFecha,
    required this.rango130,
    required this.rango3160,
    required this.rango6190,
    required this.rango91120,
    required this.antiguos,
    required this.total,
  });

  factory ReporteCxcFila.fromJson(Map<String, dynamic> json) {
    return ReporteCxcFila(
      cliente: json['cliente']?.toString() ?? '',
      tipoComprobante: json['tipo_comprobante']?.toString() ?? '',
      numeroDocumento: json['numero_documento']?.toString() ?? '',
      unidadNegocio: json['unidad_negocio']?.toString() ?? '',
      equipo: json['equipo']?.toString() ?? '',
      pedido: json['pedido']?.toString() ?? '',
      fechaFactura: json['fecha_factura']?.toString() ?? '',
      fechaEsperada: json['fecha_esperada']?.toString() ?? '',
      moneda: json['moneda']?.toString() ?? '',
      cuenta: json['cuenta']?.toString() ?? '',
      divisaImporte: _d(json['divisa_importe']),
      aLaFecha: _d(json['a_la_fecha']),
      rango130: _d(json['rango_1_30']),
      rango3160: _d(json['rango_31_60']),
      rango6190: _d(json['rango_61_90']),
      rango91120: _d(json['rango_91_120']),
      antiguos: _d(json['antiguos']),
      total: _d(json['total']),
    );
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class ReporteCxcTotales {
  final double divisaImporte;
  final double aLaFecha;
  final double rango130;
  final double rango3160;
  final double rango6190;
  final double rango91120;
  final double antiguos;
  final double total;

  ReporteCxcTotales({
    required this.divisaImporte,
    required this.aLaFecha,
    required this.rango130,
    required this.rango3160,
    required this.rango6190,
    required this.rango91120,
    required this.antiguos,
    required this.total,
  });

  factory ReporteCxcTotales.fromJson(Map<String, dynamic> json) {
    return ReporteCxcTotales(
      divisaImporte: ReporteCxcFila._d(json['divisa_importe']),
      aLaFecha: ReporteCxcFila._d(json['a_la_fecha']),
      rango130: ReporteCxcFila._d(json['rango_1_30']),
      rango3160: ReporteCxcFila._d(json['rango_31_60']),
      rango6190: ReporteCxcFila._d(json['rango_61_90']),
      rango91120: ReporteCxcFila._d(json['rango_91_120']),
      antiguos: ReporteCxcFila._d(json['antiguos']),
      total: ReporteCxcFila._d(json['total']),
    );
  }
}

class ReporteCxcResponse {
  final String fecha;
  final String modo;
  final String desde;
  final String hasta;
  final int count;
  final List<ReporteCxcFila> rows;
  final ReporteCxcTotales totales;

  ReporteCxcResponse({
    required this.fecha,
    required this.modo,
    required this.desde,
    required this.hasta,
    required this.count,
    required this.rows,
    required this.totales,
  });
}
