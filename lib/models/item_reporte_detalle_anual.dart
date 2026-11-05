class ItemReporteDetalleAnual {
  final String pedido;
  final double ingreso;
  final double egreso;
  final double margen;
  final double porcentajeMargen;

  ItemReporteDetalleAnual({
    required this.pedido,
    required this.ingreso,
    required this.egreso,
    required this.margen,
    required this.porcentajeMargen,
  });

  factory ItemReporteDetalleAnual.fromJson(Map<String, dynamic> json) {
    return ItemReporteDetalleAnual(
      pedido: (json['PEDIDO'] ?? '—').toString(),
      ingreso: double.tryParse('${json['INGRESO']}') ?? 0.0,
      egreso: double.tryParse('${json['EGRESO']}') ?? 0.0,
      margen: double.tryParse('${json['MARGEN']}') ?? 0.0,
      porcentajeMargen:
          double.tryParse('${json['PORCENTAJE_MARGEN']}') ?? 0.0,
    );
  }
}

class ReporteDetalleAnualResponse {
  final List<ItemReporteDetalleAnual> items;
  final String anio;
  final int totalPedidos;
  final double montoTotalIngresos;
  final double montoTotalEgresos;
  final double montoTotalMargen;

  ReporteDetalleAnualResponse({
    required this.items,
    required this.anio,
    required this.totalPedidos,
    required this.montoTotalIngresos,
    required this.montoTotalEgresos,
    required this.montoTotalMargen,
  });

  factory ReporteDetalleAnualResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return ReporteDetalleAnualResponse(
      items: list
          .map((i) => ItemReporteDetalleAnual.fromJson(i))
          .toList(),
      anio: (json['anio'] ?? '').toString(),
      totalPedidos: json['total_pedidos'] ?? 0,
      montoTotalIngresos:
          double.tryParse('${json['monto_total_ingresos']}') ?? 0.0,
      montoTotalEgresos:
          double.tryParse('${json['monto_total_egresos']}') ?? 0.0,
      montoTotalMargen:
          double.tryParse('${json['monto_total_margen']}') ?? 0.0,
    );
  }
}