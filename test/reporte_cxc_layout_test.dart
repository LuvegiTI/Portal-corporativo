import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luvegi/models/reporte_cxc.dart';
import 'package:luvegi/pages/reporte_cxc_page.dart';
import 'package:luvegi/services/reporte_cxc_service.dart';

class _FakeCxcService extends ReporteCxcService {
  _FakeCxcService(this.respuesta);

  final ReporteCxcResponse respuesta;

  @override
  Future<ReporteCxcResponse> consultar({
    required String token,
    required String modo,
    String fecha = '',
    String desde = '',
    String hasta = '',
  }) async {
    return respuesta;
  }
}

ReporteCxcResponse _respuesta(int total) {
  final filas = List.generate(total, (i) {
    final n = i + 1;
    return ReporteCxcFila(
      cliente: 'Cliente $n',
      tipoComprobante: 'Factura de Cliente',
      numeroDocumento: 'F001-000000$n',
      unidadNegocio: 'UNO-$n',
      equipo: 'EQ-$n',
      pedido: 'PED-$n',
      fechaFactura: '01/10/2026',
      fechaEsperada: '15/10/2026',
      moneda: 'PEN',
      cuenta: 'Cuenta $n',
      divisaImporte: n * 10.5,
      aLaFecha: n * 3.5,
      rango130: n * 1.5,
      rango3160: 0,
      rango6190: 0,
      rango91120: 0,
      antiguos: 0,
      total: n * 5.0,
    );
  });

  return ReporteCxcResponse(
    fecha: '19/10/2026',
    modo: 'single',
    desde: '',
    hasta: '',
    count: total,
    rows: filas,
    totales: ReporteCxcTotales(
      divisaImporte: 100,
      aLaFecha: 200,
      rango130: 300,
      rango3160: 400,
      rango6190: 500,
      rango91120: 600,
      antiguos: 700,
      total: 800,
    ),
  );
}

Future<void> _consultar(WidgetTester tester) async {
  await tester.tap(find.text('Consultar'));
  await tester.pump();
  await tester.pump();
}

Future<void> _tamano(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _pagina(ReporteCxcResponse respuesta) {
  return MaterialApp(
    home: ReporteCxcPage(
      token: 'token-test',
      permisos: const ['REPORTE_CXC', 'EXPORTAR_EXCEL'],
      servicio: _FakeCxcService(respuesta),
    ),
  );
}

void main() {
  testWidgets('móvil con datos no lanza excepciones', (tester) async {
    await _tamano(tester, const Size(390, 844));
    await tester.pumpWidget(_pagina(_respuesta(30)));
    await _consultar(tester);

    expect(find.text('Cliente 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('móvil con datos largos no lanza excepciones', (tester) async {
    await _tamano(tester, const Size(320, 640));
    await tester.pumpWidget(_pagina(_respuesta(120)));
    await _consultar(tester);

    expect(find.text('Cliente 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('escritorio pagina y no lanza excepciones', (tester) async {
    await _tamano(tester, const Size(1400, 900));
    await tester.pumpWidget(_pagina(_respuesta(120)));
    await _consultar(tester);

    expect(find.text('Cliente 1'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pump();

    expect(find.text('Cliente 51'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('móvil sin datos no lanza excepciones', (tester) async {
    await _tamano(tester, const Size(390, 844));
    await tester.pumpWidget(_pagina(_respuesta(0)));
    await _consultar(tester);

    expect(tester.takeException(), isNull);
  });
}
