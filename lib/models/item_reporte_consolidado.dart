class ItemReporteConsolidado {
  final String tipoRegistro;
  final String contacto;
  final String ruc;
  final String etiqueta;
  final String tipoComprobante;
  final String numeroComprobante;
  final String link;
  final String fechaEmision;
  final String fechaKardex;
  final String ocOrigen;
  final String refOrigen;
  final String producto;
  final String codigoProducto;
  final double cantidad;
  final double precioUnitario;
  final String impuesto;
  final String moneda;
  final double valorMoneda;
  final double valorMonedaNacional;
  final double valorConImpuesto;
  final double valorNacionalConImpuesto;
  final double porcentajeAnalitico;
  final double tipoCambio;
  final String pedido;

  ItemReporteConsolidado({
    required this.tipoRegistro,
    required this.contacto,
    required this.ruc,
    required this.etiqueta,
    required this.tipoComprobante,
    required this.numeroComprobante,
    required this.link,
    required this.fechaEmision,
    required this.fechaKardex,
    required this.ocOrigen,
    required this.refOrigen,
    required this.producto,
    required this.codigoProducto,
    required this.cantidad,
    required this.precioUnitario,
    required this.impuesto,
    required this.moneda,
    required this.valorMoneda,
    required this.valorMonedaNacional,
    required this.valorConImpuesto,
    required this.porcentajeAnalitico,
    required this.valorNacionalConImpuesto,
    required this.tipoCambio,
    required this.pedido,
  });

  factory ItemReporteConsolidado.fromJson(Map<String, dynamic> json) {
    return ItemReporteConsolidado(
      tipoRegistro: (json['TIPO REGISTRO'] ?? '—').toString(),
      contacto: (json['CONTACTO'] ?? '').toString(),
      ruc: (json['RUC'] ?? '').toString(),
      etiqueta: (json['ETIQUETA'] ?? '—').toString(),
      tipoComprobante: (json['TIPO COMPROBANTE'] ?? '').toString(),
      numeroComprobante: (json['NUMERO COMPROBANTE'] ?? '').toString(),
      link: (json['LINK'] ?? '').toString(),
      fechaEmision: (json['FECHA EMISION'] ?? '').toString(),
      fechaKardex: (json['FECHA KARDEX'] ?? '').toString(),
      ocOrigen: (json['OC ORIGEN'] ?? '').toString(),
      refOrigen: (json['REF. ORIGEN'] ?? '').toString(),
      producto: (json['PRODUCTO'] ?? '').toString(),
      codigoProducto: (json['CODIGO PRODUCTO'] ?? '').toString(),
      cantidad: double.tryParse('${json['CANTIDAD']}') ?? 0.0,
      precioUnitario: double.tryParse('${json['PRECIO UNITARIO']}') ?? 0.0,
      impuesto: (json['IMPUESTO'] ?? '—').toString(),
      moneda: (json['MONEDA'] ?? 'PEN').toString(),
      valorMoneda: double.tryParse('${json['VALOR EN MONEDA']}') ?? 0.0,
      valorMonedaNacional:
          double.tryParse('${json['VALOR EN MONEDA NACIONAL']}') ?? 0.0,
      valorConImpuesto: double.tryParse('${json['VALOR CON IMPUESTO']}') ?? 0.0,
      porcentajeAnalitico: (json['% ANALITICO'] ?? 100.0).toDouble(),
      valorNacionalConImpuesto:
          double.tryParse('${json['VALOR NACIONAL CON IMPUESTO']}') ?? 0.0,
      tipoCambio: double.tryParse('${json['TIPO DE CAMBIO']}') ?? 1.0,
      pedido: (json['PEDIDO'] ?? '').toString(),
    );
  }
}
