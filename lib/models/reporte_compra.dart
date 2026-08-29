class ReporteOrdenCompra {
  final String ordenCompra;
  final String proveedor;
  final String fechaConfirmacion;
  final String divisa;
  final String producto;
  final String descripcion;
  final String cantidad;
  final String unidadNegocio;
  final String equipo;
  final String pedido;
  final String precioUnitario;
  final String sinImpuesto;
  final String conImpuesto;

  const ReporteOrdenCompra({
    required this.ordenCompra,
    required this.proveedor,
    required this.fechaConfirmacion,
    required this.divisa,
    required this.producto,
    required this.descripcion,
    required this.cantidad,
    required this.unidadNegocio,
    required this.equipo,
    required this.pedido,
    required this.precioUnitario,
    required this.sinImpuesto,
    required this.conImpuesto,
  });

  factory ReporteOrdenCompra.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] ?? '').toString();

    return ReporteOrdenCompra(
      ordenCompra: text('orden_compra'),
      proveedor: text('proveedor'),
      fechaConfirmacion: text('fecha_confirmacion'),
      divisa: text('divisa'),
      producto: text('producto'),
      descripcion: text('descripcion'),
      cantidad: text('cantidad'),
      unidadNegocio: text('unidad_negocio'),
      equipo: text('equipo'),
      pedido: text('pedido'),
      precioUnitario: text('precio_unitario'),
      sinImpuesto: text('sin_impuesto'),
      conImpuesto: text('con_impuesto'),
    );
  }
}

class ReporteOrdenCompraResponse {
  final List<ReporteOrdenCompra> data;
  final int page;
  final int pageSize;
  final int totalPages;
  final int totalLineas;
  final double elapsed;
  final double totalSinImpuesto;
  final double totalConImpuesto;

  const ReporteOrdenCompraResponse({
    required this.data,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.totalLineas,
    required this.elapsed,
    required this.totalSinImpuesto,
    required this.totalConImpuesto,
  });

  factory ReporteOrdenCompraResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];

    final data = rawData is List
        ? rawData
            .whereType<Map>()
            .map(
              (e) => ReporteOrdenCompra.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList()
        : <ReporteOrdenCompra>[];

    int integer(String key, [int fallback = 0]) {
      return int.tryParse(
            (json[key] ?? fallback).toString(),
          ) ??
          fallback;
    }

    double decimal(String key) {
      return double.tryParse(
            (json[key] ?? 0).toString(),
          ) ??
          0;
    }

    return ReporteOrdenCompraResponse(
      data: data,
      page: integer('page', 1),
      pageSize: integer('page_size', 50),
      totalPages: integer('total_pages'),
      totalLineas: integer('total_lineas'),
      elapsed: decimal('elapsed'),
      totalSinImpuesto: decimal('total_sin_impuesto'),
      totalConImpuesto: decimal('total_con_impuesto'),
    );
  }
}
