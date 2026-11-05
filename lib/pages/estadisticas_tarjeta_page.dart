import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../services/tarjeta_estadisticas_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';
import '../utils/mensaje_error.dart';

enum _CampoOrden { nombre, visitas, clics, interaccion }

class _DispositivoInfo {
  final String clave;
  final String etiqueta;
  final IconData icono;
  final Color color;

  const _DispositivoInfo(this.clave, this.etiqueta, this.icono, this.color);
}

const List<_DispositivoInfo> _dispositivos = [
  _DispositivoInfo(
    'movil',
    'Móvil',
    Icons.smartphone_rounded,
    LuvegiColors.secondary,
  ),
  _DispositivoInfo(
    'tablet',
    'Tablet',
    Icons.tablet_mac_rounded,
    LuvegiColors.info,
  ),
  _DispositivoInfo(
    'escritorio',
    'Escritorio',
    Icons.desktop_windows_rounded,
    LuvegiColors.warning,
  ),
  _DispositivoInfo(
    'desconocido',
    'Sin identificar',
    Icons.devices_other_rounded,
    LuvegiColors.textHint,
  ),
];

class EstadisticasTarjetaPage extends StatefulWidget {
  final String token;

  const EstadisticasTarjetaPage({super.key, required this.token});

  @override
  State<EstadisticasTarjetaPage> createState() =>
      _EstadisticasTarjetaPageState();
}

class _EstadisticasTarjetaPageState extends State<EstadisticasTarjetaPage> {
  final _service = TarjetaEstadisticasService();
  final _formatoFecha = DateFormat('dd/MM/yyyy');
  final _formatoFechaHora = DateFormat('dd/MM/yyyy HH:mm');
  final _numero = NumberFormat('#,##0');

  late DateTime _desde;
  late DateTime _hasta;

  bool _cargando = true;
  bool _exportando = false;
  String? _error;
  EstadisticaTarjetaDatos? _datos;

  _CampoOrden _campo = _CampoOrden.visitas;
  bool _ascendente = false;

  @override
  void initState() {
    super.initState();
    _hasta = DateTime.now();
    _desde = _hasta.subtract(const Duration(days: 30));
    _cargar();
  }

  String _aIso(DateTime fecha) => DateFormat('yyyy-MM-dd').format(fecha);

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final datos = await _service.consultar(
        widget.token,
        desde: _aIso(_desde),
        hasta: _aIso(_hasta),
      );
      if (!mounted) return;
      setState(() => _datos = datos);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = MensajeError.desdeExcepcion(e);
        _datos = null;
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirFecha({required bool esDesde}) async {
    final fechaInicial = esDesde ? _desde : _hasta;

    final seleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );

    if (seleccionada == null || !mounted) return;

    setState(() {
      if (esDesde) {
        _desde = seleccionada;
      } else {
        _hasta = seleccionada;
      }

      if (_desde.isAfter(_hasta)) {
        if (esDesde) {
          _hasta = seleccionada;
        } else {
          _desde = seleccionada;
        }
      }
    });

    await _cargar();
  }

  List<EstadisticaTarjetaFila> get _filasOrdenadas {
    final filas = List<EstadisticaTarjetaFila>.of(_datos?.filas ?? const []);

    filas.sort((a, b) {
      final comparacion = switch (_campo) {
        _CampoOrden.nombre => a.nombre.compareTo(b.nombre),
        _CampoOrden.visitas => a.visitas.compareTo(b.visitas),
        _CampoOrden.clics => a.clics.compareTo(b.clics),
        _CampoOrden.interaccion => a.interaccion.compareTo(b.interaccion),
      };
      return _ascendente ? comparacion : -comparacion;
    });

    return filas;
  }

  void _ordenarPor(_CampoOrden campo) {
    setState(() {
      if (_campo == campo) {
        _ascendente = !_ascendente;
        return;
      }
      _campo = campo;
      _ascendente = campo == _CampoOrden.nombre;
    });
  }

  Future<void> _exportarExcel() async {
    if (_exportando) return;

    final filas = _filasOrdenadas;
    if (filas.isEmpty) {
      _mensaje('No hay datos para exportar.', error: true);
      return;
    }

    setState(() => _exportando = true);

    try {
      final excel = excel_lib.Excel.createExcel();
      final hoja = excel['Tarjetas de contacto'];
      excel.delete('Sheet1');

      hoja.appendRow([
        excel_lib.TextCellValue('Ejecutivo'),
        excel_lib.TextCellValue('Cargo'),
        excel_lib.TextCellValue('Visitas'),
        excel_lib.TextCellValue('Visitas móvil'),
        excel_lib.TextCellValue('Visitas tablet'),
        excel_lib.TextCellValue('Visitas escritorio'),
        excel_lib.TextCellValue('Clics WhatsApp'),
        excel_lib.TextCellValue('Clics móvil'),
        excel_lib.TextCellValue('Clics tablet'),
        excel_lib.TextCellValue('Clics escritorio'),
        excel_lib.TextCellValue('Interacción (%)'),
        excel_lib.TextCellValue('Última visita'),
        excel_lib.TextCellValue('Último clic'),
      ]);

      for (final fila in filas) {
        int visitasDe(String clave) =>
            fila.dispositivos[clave]?.visitas ?? 0;
        int clicsDe(String clave) => fila.dispositivos[clave]?.clics ?? 0;

        hoja.appendRow([
          excel_lib.TextCellValue(fila.nombre),
          excel_lib.TextCellValue(fila.cargo),
          excel_lib.TextCellValue(fila.visitas.toString()),
          excel_lib.TextCellValue(visitasDe('movil').toString()),
          excel_lib.TextCellValue(visitasDe('tablet').toString()),
          excel_lib.TextCellValue(visitasDe('escritorio').toString()),
          excel_lib.TextCellValue(fila.clics.toString()),
          excel_lib.TextCellValue(clicsDe('movil').toString()),
          excel_lib.TextCellValue(clicsDe('tablet').toString()),
          excel_lib.TextCellValue(clicsDe('escritorio').toString()),
          excel_lib.TextCellValue(fila.interaccion.toStringAsFixed(1)),
          excel_lib.TextCellValue(_fechaHoraTexto(fila.ultimaVisita)),
          excel_lib.TextCellValue(_fechaHoraTexto(fila.ultimoClic)),
        ]);
      }

      final nombre =
          'EstadisticasTarjetas_${_datos?.desde ?? ''}_${_datos?.hasta ?? ''}';

      if (kIsWeb) {
        excel.save(fileName: '$nombre.xlsx');
      } else {
        final bytes = excel.save();
        if (bytes != null) {
          await FileSaver.instance.saveFile(
            name: nombre,
            bytes: Uint8List.fromList(bytes),
            ext: 'xlsx',
            mimeType: MimeType.microsoftExcel,
          );
        }
      }

      _mensaje('Archivo exportado correctamente.');
    } catch (e) {
      _mensaje(MensajeError.desdeExcepcion(e), error: true);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _mensaje(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: error ? LuvegiColors.error : LuvegiColors.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bool compacto = MediaQuery.sizeOf(context).width < 800;
    final filas = _filasOrdenadas;

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      body: Padding(
        padding: EdgeInsets.all(compacto ? LuvegiSpacing.md : LuvegiSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(compacto),
            const SizedBox(height: LuvegiSpacing.lg),
            _buildFiltros(compacto),

            if (_error != null) ...[
              const SizedBox(height: LuvegiSpacing.md),
              _buildError(),
            ],

            if (_datos != null) ...[
              const SizedBox(height: LuvegiSpacing.md),
              _buildResumen(compacto),
              const SizedBox(height: LuvegiSpacing.md),
              _buildResumenDispositivos(compacto),
            ],

            const SizedBox(height: LuvegiSpacing.md),

            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : filas.isEmpty
                      ? _buildVacio()
                      : _buildTabla(filas, compacto),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool compacto) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: LuvegiColors.menuHover,
            borderRadius: BorderRadius.circular(LuvegiRadius.md),
          ),
          child: const Icon(
            Icons.insights_rounded,
            color: LuvegiColors.secondary,
            size: 25,
          ),
        ),
        const SizedBox(width: LuvegiSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estadísticas de tarjetas de contacto',
                style: LuvegiText.title.copyWith(fontSize: compacto ? 17 : 20),
              ),
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Visitas a la tarjeta y clics al enlace de WhatsApp, por ejecutivo.',
                style: LuvegiText.bodySecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFiltros(bool compacto) {
    final contenido = Wrap(
      spacing: LuvegiSpacing.md,
      runSpacing: LuvegiSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        LuvegiButton.outline(
          text: 'Desde: ${_formatoFecha.format(_desde)}',
          icon: Icons.event_rounded,
          onPressed: () => _elegirFecha(esDesde: true),
        ),
        LuvegiButton.outline(
          text: 'Hasta: ${_formatoFecha.format(_hasta)}',
          icon: Icons.event_available_rounded,
          onPressed: () => _elegirFecha(esDesde: false),
        ),
        LuvegiButton.primary(
          text: _cargando ? 'Actualizando...' : 'Actualizar',
          icon: Icons.refresh_rounded,
          loading: _cargando,
          onPressed: _cargando ? null : _cargar,
        ),
        LuvegiButton.secondary(
          text: _exportando ? 'Exportando...' : 'Exportar Excel',
          icon: Icons.download_rounded,
          loading: _exportando,
          onPressed: _exportando ? null : _exportarExcel,
        ),
      ],
    );

    return LuvegiCard(
      padding: compacto
          ? const EdgeInsets.all(LuvegiSpacing.md)
          : const EdgeInsets.all(LuvegiSpacing.lg),
      child: contenido,
    );
  }

  Widget _buildResumen(bool compacto) {
    final datos = _datos;

    final items = <Widget>[
      _ResumenDato(
        icono: Icons.visibility_outlined,
        etiqueta: 'Visitas a la tarjeta',
        valor: _numero.format(datos?.totalVisitas ?? 0),
        color: LuvegiColors.secondary,
      ),
      _ResumenDato(
        icono: Icons.chat_outlined,
        etiqueta: 'Clics en WhatsApp',
        valor: _numero.format(datos?.totalClics ?? 0),
        color: LuvegiColors.success,
      ),
      _ResumenDato(
        icono: Icons.percent_rounded,
        etiqueta: 'Interacción',
        valor: '${(datos?.interaccionTotal ?? 0).toStringAsFixed(1)}%',
        color: LuvegiColors.info,
      ),
      _ResumenDato(
        icono: Icons.people_alt_outlined,
        etiqueta: 'Ejecutivos medidos',
        valor: _numero.format(datos?.filas.length ?? 0),
        color: LuvegiColors.warning,
      ),
    ];

    if (compacto) {
      return Wrap(
        spacing: LuvegiSpacing.sm,
        runSpacing: LuvegiSpacing.sm,
        children: [
          for (final item in items) SizedBox(width: 210, child: item),
        ],
      );
    }

    return Row(
      children: [for (final item in items) Expanded(child: item)],
    );
  }

  Widget _buildResumenDispositivos(bool compacto) {
    final datos = _datos;
    final conteos =
        datos?.dispositivos ?? const <String, ConteoDispositivo>{};

    final visibles = _dispositivos
        .where((d) => (conteos[d.clave]?.visitas ?? 0) > 0 ||
            (conteos[d.clave]?.clics ?? 0) > 0)
        .toList();

    if (visibles.isEmpty) return const SizedBox.shrink();

    return LuvegiCard(
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.devices_rounded,
                size: 17,
                color: LuvegiColors.textSecondary,
              ),
              const SizedBox(width: LuvegiSpacing.xs),
              Text(
                'VISITAS POR DISPOSITIVO',
                style: LuvegiText.caption.copyWith(
                  color: LuvegiColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          Wrap(
            spacing: LuvegiSpacing.sm,
            runSpacing: LuvegiSpacing.sm,
            children: [
              for (final dispositivo in visibles)
                SizedBox(
                  width: compacto ? 168 : 200,
                  child: _ResumenDato(
                    icono: dispositivo.icono,
                    etiqueta: dispositivo.etiqueta,
                    valor: _numero.format(conteos[dispositivo.clave]?.visitas ?? 0),
                    detalle:
                        '${_numero.format(conteos[dispositivo.clave]?.clics ?? 0)} clics',
                    color: dispositivo.color,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: LuvegiColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: LuvegiColors.error),
          const SizedBox(width: LuvegiSpacing.sm),
          Expanded(
            child: Text(
              _error!,
              style: LuvegiText.body.copyWith(
                color: LuvegiColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: LuvegiCard(
        maxWidth: 430,
        padding: const EdgeInsets.all(LuvegiSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insights_rounded,
              size: 42,
              color: LuvegiColors.textHint,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            Text(
              _error != null
                  ? 'No pudimos cargar las estadísticas.'
                  : 'Aún no hay actividad registrada en este periodo.',
              textAlign: TextAlign.center,
              style: LuvegiText.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetas(List<EstadisticaTarjetaFila> filas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: filas.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: LuvegiSpacing.sm),
            itemBuilder: (_, i) => _tarjetaFila(filas[i]),
          ),
        ),
        const SizedBox(height: LuvegiSpacing.sm),
        Text(
          'Se cuenta cada ingreso a la tarjeta y cada clic a WhatsApp, sin límite por IP ni por dispositivo.',
          style: LuvegiText.caption.copyWith(color: LuvegiColors.textHint),
        ),
      ],
    );
  }

  Widget _datoFila({
    required IconData icono,
    required String etiqueta,
    required String valor,
    Color? color,
  }) {
    final tono = color ?? LuvegiColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 15, color: color ?? LuvegiColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          etiqueta,
          style: LuvegiText.caption.copyWith(
            fontSize: 11,
            color: LuvegiColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          valor,
          style: LuvegiText.body.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: tono,
          ),
        ),
      ],
    );
  }

  Widget _tarjetaFila(EstadisticaTarjetaFila fila) {
    return Container(
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LuvegiColors.menuHover,
                  borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                ),
                child: Text(
                  fila.codigo,
                  style: LuvegiText.caption.copyWith(
                    color: LuvegiColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: LuvegiSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fila.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LuvegiText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (fila.cargo.isNotEmpty)
                      Text(
                        fila.cargo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LuvegiText.caption.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: LuvegiSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (fila.visitas > 0
                          ? LuvegiColors.success
                          : LuvegiColors.textHint)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                ),
                child: Text(
                  '${fila.interaccion.toStringAsFixed(1)}%',
                  style: LuvegiText.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: fila.visitas > 0
                        ? LuvegiColors.success
                        : LuvegiColors.textHint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          Wrap(
            spacing: LuvegiSpacing.md,
            runSpacing: LuvegiSpacing.xs,
            children: [
              _datoFila(
                icono: Icons.visibility_outlined,
                etiqueta: 'Visitas',
                valor: _numero.format(fila.visitas),
              ),
              _datoFila(
                icono: Icons.chat_outlined,
                etiqueta: 'Clics',
                valor: _numero.format(fila.clics),
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          Wrap(
            spacing: LuvegiSpacing.md,
            runSpacing: LuvegiSpacing.xs,
            children: [
              _datoFila(
                icono: Icons.login_rounded,
                etiqueta: 'Última visita',
                valor: fila.ultimaVisita == null
                    ? '—'
                    : _formatoFechaHora.format(fila.ultimaVisita!),
              ),
              _datoFila(
                icono: Icons.touch_app_rounded,
                etiqueta: 'Último clic',
                valor: fila.ultimoClic == null
                    ? '—'
                    : _formatoFechaHora.format(fila.ultimoClic!),
              ),
            ],
          ),
          if (fila.dispositivos.isNotEmpty) ...[
            const SizedBox(height: LuvegiSpacing.sm),
            _celdaDispositivos(fila),
          ],
        ],
      ),
    );
  }

  Widget _buildTabla(List<EstadisticaTarjetaFila> filas, bool compacto) {
    if (compacto) return _buildTarjetas(filas);

    final maxVisitas =
        filas.map((f) => f.visitas).fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LuvegiCard(
            padding: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, restricciones) {
                final ancho = restricciones.maxWidth < 1120
                    ? 1120.0
                    : restricciones.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: ancho,
                    height: restricciones.maxHeight,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _encabezadoTabla(),
                          const Divider(height: 1),
                          for (final fila in filas)
                            _filaTabla(fila, maxVisitas),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: LuvegiSpacing.sm),
        Text(
          'Se cuenta cada ingreso a la tarjeta y cada clic a WhatsApp, sin límite por IP ni por dispositivo.',
          style: LuvegiText.caption.copyWith(color: LuvegiColors.textHint),
        ),
      ],
    );
  }

  Widget _encabezadoTexto(String texto) {
    return Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LuvegiSpacing.sm,
          vertical: LuvegiSpacing.md,
        ),
        child: Text(
          texto,
          textAlign: TextAlign.right,
          style: LuvegiText.caption.copyWith(
            color: LuvegiColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _encabezadoTabla() {
    Widget celda(_CampoOrden campo, String texto, {bool derecha = false}) {
      final activo = _campo == campo;
      return Expanded(
        flex: 2,
        child: InkWell(
          onTap: () => _ordenarPor(campo),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LuvegiSpacing.sm,
              vertical: LuvegiSpacing.md,
            ),
            child: Row(
              mainAxisAlignment:
                  derecha ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  texto,
                  style: LuvegiText.caption.copyWith(
                    color: activo
                        ? LuvegiColors.secondary
                        : LuvegiColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (activo) ...[
                  const SizedBox(width: LuvegiSpacing.xs),
                  Icon(
                    _ascendente
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 13,
                    color: LuvegiColors.secondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: LuvegiColors.menuHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: LuvegiSpacing.xs),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: InkWell(
                onTap: () => _ordenarPor(_CampoOrden.nombre),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LuvegiSpacing.sm,
                    vertical: LuvegiSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'EJECUTIVO',
                        style: LuvegiText.caption.copyWith(
                          color: _campo == _CampoOrden.nombre
                              ? LuvegiColors.secondary
                              : LuvegiColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_campo == _CampoOrden.nombre) ...[
                        const SizedBox(width: LuvegiSpacing.xs),
                        Icon(
                          _ascendente
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 13,
                          color: LuvegiColors.secondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LuvegiSpacing.sm,
                  vertical: LuvegiSpacing.md,
                ),
                child: Text(
                  'DISPOSITIVO',
                  style: LuvegiText.caption.copyWith(
                    color: LuvegiColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            celda(_CampoOrden.visitas, 'VISITAS', derecha: true),
            celda(_CampoOrden.clics, 'CLICS WSP', derecha: true),
            celda(_CampoOrden.interaccion, 'INTERACCIÓN', derecha: true),
            _encabezadoTexto('ÚLTIMA VISITA'),
            _encabezadoTexto('ÚLTIMO CLIC'),
          ],
        ),
      ),
    );
  }

  String _fechaHoraTexto(DateTime? fecha) =>
      fecha == null ? '' : _formatoFechaHora.format(fecha);

  Widget _celdaFecha(DateTime? fecha) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LuvegiSpacing.sm),
      child: Text(
        fecha == null ? '—' : _formatoFechaHora.format(fecha),
        textAlign: TextAlign.right,
        style: LuvegiText.caption.copyWith(
          fontSize: 12,
          color: fecha == null
              ? LuvegiColors.textHint
              : LuvegiColors.textPrimary,
        ),
      ),
    );
  }

  Widget _celdaDispositivos(EstadisticaTarjetaFila fila) {
    final conDatos = _dispositivos
        .where((d) => (fila.dispositivos[d.clave]?.visitas ?? 0) > 0 ||
            (fila.dispositivos[d.clave]?.clics ?? 0) > 0)
        .toList();

    if (conDatos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: LuvegiSpacing.sm),
        child: Text(
          '—',
          style: LuvegiText.body.copyWith(color: LuvegiColors.textHint),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LuvegiSpacing.sm),
      child: Wrap(
        spacing: LuvegiSpacing.xs,
        runSpacing: LuvegiSpacing.xs,
        children: [
          for (final dispositivo in conDatos)
            Tooltip(
              message: '${dispositivo.etiqueta}: '
                  '${fila.dispositivos[dispositivo.clave]!.visitas} visitas · '
                  '${fila.dispositivos[dispositivo.clave]!.clics} clics',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: dispositivo.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(LuvegiRadius.xs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(dispositivo.icono, size: 12, color: dispositivo.color),
                    const SizedBox(width: 4),
                    Text(
                      _numero.format(
                        fila.dispositivos[dispositivo.clave]!.visitas,
                      ),
                      style: LuvegiText.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: dispositivo.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filaTabla(EstadisticaTarjetaFila fila, int maxVisitas) {
    final fraccion = maxVisitas > 0 ? fila.visitas / maxVisitas : 0.0;

    Widget numero(int valor) {
      return Text(
        _numero.format(valor),
        textAlign: TextAlign.right,
        style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
      );
    }

    return Container(
      color: LuvegiColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: LuvegiSpacing.xs,
        vertical: LuvegiSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LuvegiSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: LuvegiColors.menuHover,
                          borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                        ),
                        child: Text(
                          fila.codigo,
                          style: LuvegiText.caption.copyWith(
                            color: LuvegiColors.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: LuvegiSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fila.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LuvegiText.body
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              fila.cargo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LuvegiText.caption.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(flex: 4, child: _celdaDispositivos(fila)),
              Expanded(flex: 2, child: numero(fila.visitas)),
              Expanded(flex: 2, child: numero(fila.clics)),
              Expanded(
                flex: 2,
                child: Text(
                  '${fila.interaccion.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: LuvegiText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fila.visitas > 0
                        ? LuvegiColors.success
                        : LuvegiColors.textHint,
                  ),
                ),
              ),
              Expanded(flex: 3, child: _celdaFecha(fila.ultimaVisita)),
              Expanded(flex: 3, child: _celdaFecha(fila.ultimoClic)),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LuvegiSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(LuvegiRadius.xl),
                    child: LinearProgressIndicator(
                      value: fraccion,
                      minHeight: 5,
                      backgroundColor: LuvegiColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        fila.visitas > 0
                            ? LuvegiColors.secondary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
                const Expanded(flex: 16, child: SizedBox()),
              ],
            ),
          ),
          const SizedBox(height: LuvegiSpacing.xs),
          const Divider(height: 1, color: LuvegiColors.divider),
        ],
      ),
    );
  }
}

class _ResumenDato extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;
  final String? detalle;

  const _ResumenDato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: LuvegiSpacing.md),
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Row(
        children: [
          Icon(icono, size: 22, color: color),
          const SizedBox(width: LuvegiSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuvegiText.statistic.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuvegiText.caption.copyWith(fontSize: 11),
                ),
                if (detalle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    detalle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LuvegiText.caption.copyWith(
                      fontSize: 10,
                      color: LuvegiColors.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
