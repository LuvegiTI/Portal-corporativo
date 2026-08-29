import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../design_system/luvegi_text_field.dart';
import '../services/importar_oc_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';

class ImportarOcPage extends StatefulWidget {
  final String token;

  const ImportarOcPage({
    super.key,
    required this.token,
  });

  @override
  State<ImportarOcPage> createState() => _ImportarOcPageState();
}

class _ImportarOcPageState extends State<ImportarOcPage> {
  final TextEditingController _ocCtrl = TextEditingController();
  final ImportarOcService _service = ImportarOcService();

  bool _loading = false;
  String _archivoNombre = 'Ningún archivo seleccionado';
  String _estado = 'Esperando datos...';

  List<Map<String, dynamic>> _lineas = [];

  String _cellValue(Data? cell) {
    if (cell == null || cell.value == null) return '';
    return cell.value.toString().trim();
  }

  String _normalizarHeader(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  double _toDouble(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }

  Future<void> _seleccionarExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;

      final file = result.files.single;
      final bytes = file.bytes!;
      final lineas = _leerExcel(bytes);

      if (!mounted) return;

      setState(() {
        _archivoNombre = file.name;
        _lineas = lineas;
        _estado = 'Excel cargado correctamente.';
      });

      _mostrarMensaje(
        'Excel cargado: ${lineas.length} líneas válidas',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _archivoNombre = 'Ningún archivo seleccionado';
        _lineas = [];
        _estado = 'Error al leer el archivo Excel.';
      });

      _mostrarMensaje(
        e.toString().replaceAll('Exception:', '').trim(),
        error: true,
      );
    }
  }

  List<Map<String, dynamic>> _leerExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];

    if (sheet == null) return [];

    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    final headers = rows.first.map((e) => _cellValue(e)).toList();

    int col(String name) {
      final target = _normalizarHeader(name);

      return headers.indexWhere(
        (h) => _normalizarHeader(h) == target,
      );
    }

    final cProducto = col('Producto');
    final cDescripcion = col('Descripción');
    final cCantidad = col('Cantidad');
    final cPrecio = col('Precio Unitario');
    final cEntrega = col('Entrega Esperada');
    final cImpuestos = col('Impuestos');
    final cAna1 = col('Distribución Analítica1');
    final cAna2 = col('Distribución Analítica2');
    final cAna3 = col('Distribución Analítica3');

    if (cProducto == -1 ||
        cDescripcion == -1 ||
        cCantidad == -1 ||
        cPrecio == -1 ||
        cEntrega == -1) {
      throw Exception(
        'El Excel debe tener las columnas: Producto, Descripción, Cantidad, Precio Unitario y Entrega Esperada.',
      );
    }

    final List<Map<String, dynamic>> data = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      String get(int index) {
        if (index == -1 || index >= row.length) return '';
        return _cellValue(row[index]);
      }

      String producto = get(cProducto);

      if (producto.isEmpty || producto.toLowerCase() == 'nan') continue;

      if (producto.endsWith('.0')) {
        producto = producto.substring(0, producto.length - 2);
      }

      final cantidad = _toDouble(get(cCantidad));
      final precio = _toDouble(get(cPrecio));

      if (cantidad <= 0) continue;

      data.add({
        'Producto': producto,
        'Descripción': get(cDescripcion),
        'Cantidad': cantidad,
        'Precio Unitario': precio,
        'Entrega Esperada': get(cEntrega),
        'Impuestos': get(cImpuestos),
        'Distribución Analítica1': get(cAna1),
        'Distribución Analítica2': get(cAna2),
        'Distribución Analítica3': get(cAna3),
      });
    }

    return data;
  }

  Future<void> _importar() async {
    final oc = _ocCtrl.text.trim();

    if (oc.isEmpty) {
      _mostrarMensaje(
        'Escribe la Orden de Compra.',
        error: true,
      );
      return;
    }

    if (_lineas.isEmpty) {
      _mostrarMensaje(
        'Primero selecciona un Excel válido.',
        error: true,
      );
      return;
    }

    setState(() {
      _loading = true;
      _estado = 'Importando líneas a Odoo...';
    });

    try {
      final res = await _service.importar(
        token: widget.token,
        ordenCompra: oc,
        lineas: _lineas,
      );

      if (!mounted) return;

      setState(() {
        _estado =
            'Importación completada. Líneas procesadas: ${res['lineas_procesadas']}.';
        _archivoNombre = 'Ningún archivo seleccionado';
        _lineas = [];
      });

      _mostrarMensaje(
        'Importación exitosa. Líneas procesadas: ${res['lineas_procesadas']}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _estado = 'Error durante la importación.';
      });

      _mostrarMensaje(
        e.toString().replaceAll('Exception:', '').trim(),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _mostrarMensaje(
    String mensaje, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor:
            error ? LuvegiColors.error : LuvegiColors.secondary,
      ),
    );
  }

  Color get _estadoColor {
    final estado = _estado.toLowerCase();

    if (estado.contains('error')) {
      return LuvegiColors.error;
    }

    if (estado.contains('completada') ||
        estado.contains('correctamente')) {
      return LuvegiColors.success;
    }

    if (estado.contains('importando')) {
      return LuvegiColors.secondary;
    }

    return LuvegiColors.textSecondary;
  }

  IconData get _estadoIcon {
    final estado = _estado.toLowerCase();

    if (estado.contains('error')) {
      return Icons.error_outline_rounded;
    }

    if (estado.contains('completada') ||
        estado.contains('correctamente')) {
      return Icons.check_circle_outline_rounded;
    }

    if (estado.contains('importando')) {
      return Icons.sync_rounded;
    }

    return Icons.info_outline_rounded;
  }

  @override
  void dispose() {
    _ocCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool mobile = width < 760;

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      appBar: AppBar(
        title: const Text('Importador de Órdenes de Compra'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            mobile ? LuvegiSpacing.md : LuvegiSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: LuvegiSpacing.lg),
                if (mobile)
                  _buildMobile()
                else
                  _buildDesktop(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _CompactSection(
                icon: Icons.shopping_cart_checkout_rounded,
                title: '1. Orden de Compra',
                child: LuvegiTextField(
                  controller: _ocCtrl,
                  label: 'Orden de Compra destino',
                  hint: 'Ejemplo: OC03951',
                  prefixIcon: Icons.shopping_cart_outlined,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(height: LuvegiSpacing.md),
              _CompactSection(
                icon: Icons.upload_file_rounded,
                title: '2. Archivo Excel',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRequiredColumns(),
                    const SizedBox(height: LuvegiSpacing.md),
                    LuvegiButton.outline(
                      text: 'Seleccionar archivo Excel',
                      icon: Icons.upload_file_rounded,
                      width: double.infinity,
                      onPressed: _loading ? null : _seleccionarExcel,
                    ),
                    const SizedBox(height: LuvegiSpacing.md),
                    _buildFileSummary(),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: LuvegiSpacing.lg),
        Expanded(
          flex: 4,
          child: _CompactSection(
            icon: Icons.rocket_launch_rounded,
            title: '3. Importar a Odoo',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(),
                const SizedBox(height: LuvegiSpacing.lg),
                _buildSummary(),
                const SizedBox(height: LuvegiSpacing.lg),
                LuvegiButton.primary(
                  text: _loading ? 'Importando...' : 'Importar a Odoo',
                  icon: Icons.rocket_launch_rounded,
                  loading: _loading,
                  width: double.infinity,
                  onPressed: _loading ? null : _importar,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobile() {
    return Column(
      children: [
        _CompactExpansionSection(
          initiallyExpanded: true,
          icon: Icons.shopping_cart_checkout_rounded,
          title: '1. Orden de Compra',
          child: LuvegiTextField(
            controller: _ocCtrl,
            label: 'Orden de Compra destino',
            hint: 'Ejemplo: OC03951',
            prefixIcon: Icons.shopping_cart_outlined,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: LuvegiSpacing.sm),
        _CompactExpansionSection(
          initiallyExpanded: _lineas.isEmpty,
          icon: Icons.upload_file_rounded,
          title: '2. Archivo Excel',
          trailingText: _lineas.isEmpty
              ? null
              : '${_lineas.length} líneas',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRequiredColumns(),
              const SizedBox(height: LuvegiSpacing.md),
              LuvegiButton.outline(
                text: 'Seleccionar archivo Excel',
                icon: Icons.upload_file_rounded,
                width: double.infinity,
                onPressed: _loading ? null : _seleccionarExcel,
              ),
              const SizedBox(height: LuvegiSpacing.md),
              _buildFileSummary(),
            ],
          ),
        ),
        const SizedBox(height: LuvegiSpacing.sm),
        _CompactExpansionSection(
          initiallyExpanded: _lineas.isNotEmpty,
          icon: Icons.rocket_launch_rounded,
          title: '3. Importar a Odoo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(),
              const SizedBox(height: LuvegiSpacing.md),
              LuvegiButton.primary(
                text: _loading ? 'Importando...' : 'Importar a Odoo',
                icon: Icons.rocket_launch_rounded,
                loading: _loading,
                width: double.infinity,
                onPressed: _loading ? null : _importar,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
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
            Icons.shopping_cart_checkout_rounded,
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
                'Importador de Órdenes de Compra',
                style: LuvegiText.title.copyWith(
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Carga líneas desde Excel hacia una Orden de Compra en Odoo.',
                style: LuvegiText.bodySecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredColumns() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.menuHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Text(
        'Columnas requeridas: Producto, Descripción, Cantidad, Precio Unitario, Entrega Esperada, Impuestos y Distribución Analítica.',
        style: LuvegiText.caption.copyWith(
          color: LuvegiColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFileSummary() {
    final bool hasFile =
        _archivoNombre != 'Ningún archivo seleccionado';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(
          color: hasFile
              ? LuvegiColors.secondary.withOpacity(0.35)
              : LuvegiColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasFile
                ? Icons.insert_drive_file_rounded
                : Icons.folder_open_rounded,
            color: hasFile
                ? LuvegiColors.secondary
                : LuvegiColors.textHint,
          ),
          const SizedBox(width: LuvegiSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _archivoNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuvegiText.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Líneas detectadas: ${_lineas.length}',
                  style: LuvegiText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(
            label: 'OC',
            value: _ocCtrl.text.trim().isEmpty
                ? 'Sin ingresar'
                : _ocCtrl.text.trim(),
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          _SummaryRow(
            label: 'Archivo',
            value: _archivoNombre,
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          _SummaryRow(
            label: 'Líneas',
            value: '${_lineas.length}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: _estadoColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(
          color: _estadoColor.withOpacity(0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _estadoIcon,
            color: _estadoColor,
            size: 22,
          ),
          const SizedBox(width: LuvegiSpacing.sm),
          Expanded(
            child: Text(
              _estado,
              style: LuvegiText.body.copyWith(
                color: _estadoColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _CompactSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LuvegiCard(
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: LuvegiColors.menuHover,
                  borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                ),
                child: Icon(
                  icon,
                  color: LuvegiColors.secondary,
                  size: 19,
                ),
              ),
              const SizedBox(width: LuvegiSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: LuvegiText.title.copyWith(
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _CompactExpansionSection extends StatelessWidget {
  final bool initiallyExpanded;
  final IconData icon;
  final String title;
  final String? trailingText;
  final Widget child;

  const _CompactExpansionSection({
    required this.initiallyExpanded,
    required this.icon,
    required this.title,
    required this.child,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    return LuvegiCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: LuvegiSpacing.md,
            vertical: LuvegiSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            LuvegiSpacing.md,
            0,
            LuvegiSpacing.md,
            LuvegiSpacing.md,
          ),
          leading: Icon(
            icon,
            color: LuvegiColors.secondary,
          ),
          title: Text(
            title,
            style: LuvegiText.title.copyWith(
              fontSize: 15,
            ),
          ),
          subtitle: trailingText == null
              ? null
              : Text(
                  trailingText!,
                  style: LuvegiText.caption,
                ),
          children: [child],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: LuvegiText.caption.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: LuvegiSpacing.sm),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LuvegiText.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
