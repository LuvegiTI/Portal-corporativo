import 'package:flutter/material.dart';

import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../services/ticket_service.dart';

class AdminTicketsPage extends StatefulWidget {
  final String token;

  const AdminTicketsPage({super.key, required this.token});

  @override
  State<AdminTicketsPage> createState() => _AdminTicketsPageState();
}

class _AdminTicketsPageState extends State<AdminTicketsPage> {
  final TicketService _service = TicketService();

  static const int _pageSize = 20;

  List<TicketCategoria> _categorias = [];
  List<TicketCategoria> _subcategorias = [];
  List<TicketPrioridad> _prioridades = [];
  List<TicketTecnico> _tecnicos = [];
  List<TicketRegla> _reglas = [];

  int _paginaCategorias = 1;
  int _paginaPrioridades = 1;
  int _paginaTecnicos = 1;

  String _buscarCategorias = '';
  String _buscarPrioridades = '';
  String _buscarTecnicos = '';

  final TextEditingController _buscarCategoriasCtrl = TextEditingController();
  final TextEditingController _buscarPrioridadesCtrl = TextEditingController();
  final TextEditingController _buscarTecnicosCtrl = TextEditingController();

  @override
  void dispose() {
    _buscarCategoriasCtrl.dispose();
    _buscarPrioridadesCtrl.dispose();
    _buscarTecnicosCtrl.dispose();
    super.dispose();
  }

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    try {
      final categorias = await _service.listarCategoriasAdmin(
        token: widget.token,
      );
      final subcategorias = await _service.listarSubcategoriasAdmin(
        token: widget.token,
      );
      final prioridades = await _service.listarPrioridadesAdmin(
        token: widget.token,
      );
      final tecnicos = await _service.listarTecnicos(token: widget.token);
      final reglas = await _service.listarReglas(token: widget.token);
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _subcategorias = subcategorias;
        _prioridades = prioridades;
        _tecnicos = tecnicos;
        _reglas = reglas;
        _paginaCategorias = _paginaValida(
          _paginaCategorias,
          categorias.length,
        );
        _paginaPrioridades = _paginaValida(
          _paginaPrioridades,
          prioridades.length,
        );
        _paginaTecnicos = _paginaValida(_paginaTecnicos, tecnicos.length);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);

      // Mismo criterio que el resto de la pantalla: el mensaje del servidor
      // (sin permiso, sesión expirada, BD caída) es más útil que uno genérico.
      final mensaje = e is TicketApiException
          ? e.message
          : 'No se pudieron cargar los datos.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    }
  }

  int _paginaValida(int pagina, int total) {
    final totalPaginas = total <= 0 ? 1 : (total / _pageSize).ceil();
    if (pagina < 1) return 1;
    if (pagina > totalPaginas) return totalPaginas;
    return pagina;
  }

  List<T> _porPagina<T>(List<T> items, int pagina) {
    final inicio = (pagina - 1) * _pageSize;
    if (inicio >= items.length) return const [];
    return items.skip(inicio).take(_pageSize).toList();
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: LuvegiColors.success),
    );
  }

  void _mostrarError(Object e) {
    if (!mounted) return;
    final mensaje = e is TicketApiException
        ? e.message
        : 'No se pudo completar la operación.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<bool> _confirmar({
    required String titulo,
    required String mensaje,
    String confirmar = 'Sí, continuar',
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmar),
          ),
        ],
      ),
    );
    return resultado == true;
  }

  Future<void> _crearCategoria() async {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: LuvegiSpacing.md),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != true || !mounted) return;
    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) return;

    try {
      await _service.crearCategoria(
        token: widget.token,
        nombre: nombre,
        descripcion: descCtrl.text.trim(),
      );
      _mostrarExito('Categoría creada.');
      await _cargarTodo();
    } on TicketApiException catch (e) {
      _mostrarError(e);
    }
  }

  Future<void> _editarCategoria(TicketCategoria categoria) async {
    final nombreCtrl = TextEditingController(text: categoria.nombre);
    final descCtrl = TextEditingController(text: categoria.descripcion);
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar categoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: LuvegiSpacing.md),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != true || !mounted) return;
    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) return;

    try {
      await _service.editarCategoria(
        token: widget.token,
        id: categoria.id,
        nombre: nombre,
        descripcion: descCtrl.text.trim(),
      );
      _mostrarExito('Categoría actualizada.');
      await _cargarTodo();
    } on TicketApiException catch (e) {
      _mostrarError(e);
    }
  }

  Future<void> _toggleCategoria(TicketCategoria categoria) async {
    final desactivar = categoria.activo;
    final confirmado = await _confirmar(
      titulo: desactivar ? 'Desactivar categoría' : 'Activar categoría',
      mensaje: desactivar
          ? 'La categoría "${categoria.nombre}" dejará de estar disponible al registrar tickets. Los tickets ya creados no se modifican.'
          : 'La categoría "${categoria.nombre}" volverá a estar disponible al registrar tickets.',
    );
    if (!confirmado || !mounted) return;

    try {
      await _service.toggleCategoria(
        token: widget.token,
        id: categoria.id,
        activo: !categoria.activo,
      );
      _mostrarExito(desactivar ? 'Categoría desactivada.' : 'Categoría activada.');
      await _cargarTodo();
    } on TicketApiException catch (e) {
      _mostrarError(e);
    }
  }

  List<TicketCategoria> _subcategoriasDe(int categoriaId) {
    return _subcategorias.where((s) => s.padreId == categoriaId).toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  }

  Future<void> _gestionarSubcategorias(TicketCategoria categoria) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final subs = _subcategoriasDe(categoria.id);
            return Padding(
              padding: EdgeInsets.only(
                left: LuvegiSpacing.lg,
                right: LuvegiSpacing.lg,
                top: LuvegiSpacing.lg,
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom +
                    LuvegiSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Subcategorías de "${categoria.nombre}"',
                            style: LuvegiText.title,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _crearSubcategoria(categoria);
                            if (sheetContext.mounted) setSheetState(() {});
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nueva'),
                        ),
                      ],
                    ),
                    const SizedBox(height: LuvegiSpacing.sm),
                    Text(
                      'Las subcategorías afinan la clasificación del ticket. '
                      'El usuario elige la categoría general al registrar; el '
                      'personal de TI asigna la subcategoría.',
                      style: LuvegiText.caption,
                    ),
                    const SizedBox(height: LuvegiSpacing.md),
                    Flexible(
                      child: subs.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(LuvegiSpacing.lg),
                                child: Text(
                                  'No hay subcategorías registradas.',
                                  style: TextStyle(
                                    color: LuvegiColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : ListView(
                              shrinkWrap: true,
                              children: subs
                                  .map(
                                    (s) => ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        s.activo
                                            ? Icons.check_circle_outline
                                            : Icons.block,
                                        color: s.activo
                                            ? LuvegiColors.success
                                            : LuvegiColors.textSecondary,
                                      ),
                                      title: Row(
                                        children: [
                                          Flexible(child: Text(s.nombre)),
                                          const SizedBox(
                                            width: LuvegiSpacing.sm,
                                          ),
                                          _badgeActivo(s.activo),
                                        ],
                                      ),
                                      subtitle: Text(
                                        s.descripcion.isEmpty
                                            ? 'Sin descripción'
                                            : s.descripcion,
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        tooltip: 'Acciones',
                                        onSelected: (accion) async {
                                          if (accion == 'editar') {
                                            await _editarSubcategoria(s);
                                          } else if (accion == 'toggle') {
                                            await _toggleSubcategoria(s);
                                          }
                                          if (sheetContext.mounted) {
                                            setSheetState(() {});
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'editar',
                                            child: ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                              ),
                                              title: Text('Editar'),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'toggle',
                                            child: ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: Icon(
                                                s.activo
                                                    ? Icons.toggle_off_outlined
                                                    : Icons.toggle_on_outlined,
                                                size: 18,
                                              ),
                                              title: Text(
                                                s.activo
                                                    ? 'Desactivar'
                                                    : 'Activar',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: LuvegiSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _crearSubcategoria(TicketCategoria categoria) async {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Nueva subcategoría de "${categoria.nombre}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: LuvegiSpacing.md),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != true || !mounted) return;
    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) return;

    try {
      await _service.crearSubcategoria(
        token: widget.token,
        padreId: categoria.id,
        nombre: nombre,
        descripcion: descCtrl.text.trim(),
      );
      _mostrarExito('Subcategoría creada.');
      await _cargarTodo();
    } on TicketApiException catch (e) {
      _mostrarError(e);
    }
  }

  Future<void> _editarSubcategoria(TicketCategoria subcategoria) async {
    final nombreCtrl = TextEditingController(text: subcategoria.nombre);
    final descCtrl = TextEditingController(text: subcategoria.descripcion);
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar subcategoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: LuvegiSpacing.md),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != true || !mounted) return;
    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) return;

    try {
      await _service.editarSubcategoria(
        token: widget.token,
        id: subcategoria.id,
        padreId: subcategoria.padreId,
        nombre: nombre,
        descripcion: descCtrl.text.trim(),
      );
      _mostrarExito('Subcategoría actualizada.');
      await _cargarTodo();
    } on TicketApiException catch (e) {
      _mostrarError(e);
    }
  }

  Future<void> _toggleSubcategoria(TicketCategoria subcategoria) async {
    final desactivar = subcategoria.activo;
    final confirmado = await _confirmar(
      titulo: desactivar ? 'Desactivar subcategoría' : 'Activar subcategoría',
      mensaje: desactivar
          ? 'La subcategoría "${subcategoria.nombre}" dejará de estar disponible para asignarla a tickets. Los tickets ya clasificados no se modifican.'
          : 'La subcategoría "${subcategoria.nombre}" volverá a estar disponible para asignarla a tickets.',
    );
    if (!confirmado || !mounted) return;

    try {
      await _service.toggleSubcategoria(
        token: widget.token,
        id: subcategoria.id,
        activo: !subcategoria.activo,
      );
      _mostrarExito(
        desactivar ? 'Subcategoría desactivada.' : 'Subcategoría activada.',
      );
      await _cargarTodo();
    } on TicketApiException catch (e) {
      _mostrarError(e);
    }
  }

  Future<void> _crearPrioridad() async {    final nombreCtrl = TextEditingController();
    final slaCtrl = TextEditingController();
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva prioridad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: LuvegiSpacing.md),
            TextField(
              controller: slaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nivel de atención (horas)',
                hintText: 'Ej.: 4 (Alta), 24 (Media), 72 (Baja)',
                helperText: 'Uso interno para ordenar la atención. 0 = sin definir.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != true || !mounted) return;
    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    final slaHoras = int.tryParse(slaCtrl.text.trim()) ?? 0;

    try {
      await _service.crearPrioridad(
        token: widget.token,
        nombre: nombre,
        nivel: 2,
        slaHoras: slaHoras < 0 ? 0 : slaHoras,
      );
      _mostrarExito('Prioridad creada.');
      await _cargarTodo();
    } on TicketApiException catch (e) {
      _mostrarError(e);
    }
  }

  Future<void> _editarPrioridad(TicketPrioridad prioridad) async {
    final nombreCtrl = TextEditingController(text: prioridad.nombre);
    final nivelCtrl = TextEditingController(text: '${prioridad.nivel}');
    final colorCtrl = TextEditingController(text: prioridad.color);
    final slaCtrl = TextEditingController(
      text: prioridad.slaHoras > 0 ? '${prioridad.slaHoras}' : '',
    );
    final nombreFormCtrl = GlobalKey<FormFieldState<String>>();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Editar prioridad'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: nombreFormCtrl,
                  controller: nombreCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Obligatorio' : null,
                ),
                const SizedBox(height: LuvegiSpacing.md),
                TextField(
                  controller: nivelCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nivel (1 = más alta) *',
                  ),
                ),
                const SizedBox(height: LuvegiSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Color', style: LuvegiText.caption),
                ),
                const SizedBox(height: LuvegiSpacing.xs),
                Wrap(
                  spacing: LuvegiSpacing.sm,
                  runSpacing: LuvegiSpacing.sm,
                  children: [
                    for (final hex in _coloresPrioridad)
                      InkWell(
                        onTap: () => setDialogState(() => colorCtrl.text = hex),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: TicketUtils.colorPrioridad('', hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorCtrl.text == hex
                                  ? LuvegiColors.textPrimary
                                  : LuvegiColors.border,
                              width: colorCtrl.text == hex ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: LuvegiSpacing.sm),
                TextField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código hex',
                    hintText: '#E64833',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: LuvegiSpacing.md),
                TextField(
                  controller: slaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                  labelText: 'Nivel de atención (horas)',
                  hintText: 'Ej.: 4 (Alta), 24 (Media), 72 (Baja)',
                  helperText: 'Uso interno para ordenar la atención. 0 = sin definir.',
                ),
              ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (nombreFormCtrl.currentState?.validate() != true) return;
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.check),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (resultado != true || !mounted) return;
    final nombre = nombreCtrl.text.trim();
    final nivel = int.tryParse(nivelCtrl.text.trim()) ?? 0;
    if (nombre.isEmpty || nivel <= 0) return;
    final slaHoras = int.tryParse(slaCtrl.text.trim()) ?? 0;

    try {
      await _service.editarPrioridad(
        token: widget.token,
        id: prioridad.id,
        nombre: nombre,
        nivel: nivel,
        color: colorCtrl.text.trim(),
        slaHoras: slaHoras < 0 ? 0 : slaHoras,
      );
      _mostrarExito('Prioridad actualizada.');
      await _cargarTodo();
    } on TicketApiException catch (e) {
      _mostrarError(e);
    }
  }

  Future<void> _togglePrioridad(TicketPrioridad prioridad) async {
    final desactivar = prioridad.activo;
    final confirmado = await _confirmar(
      titulo: desactivar ? 'Desactivar prioridad' : 'Activar prioridad',
      mensaje: desactivar
          ? 'La prioridad "${prioridad.nombre}" dejará de estar disponible al registrar tickets.'
          : 'La prioridad "${prioridad.nombre}" volverá a estar disponible al registrar tickets.',
    );
    if (!confirmado || !mounted) return;

    try {
      await _service.togglePrioridad(
        token: widget.token,
        id: prioridad.id,
        activo: !prioridad.activo,
      );
      _mostrarExito(
        desactivar ? 'Prioridad desactivada.' : 'Prioridad activada.',
      );
      await _cargarTodo();
    } on TicketApiException catch (e) {
      _mostrarError(e);
    }
  }

  Future<void> _guardarRegla(int categoriaId) async {
    int? tecnicoId;
    final resultado = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Regla de asignación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'El técnico se asignará automáticamente a los tickets de esta categoría.',
                style: LuvegiText.caption,
              ),
              const SizedBox(height: LuvegiSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: tecnicoId,
                decoration: const InputDecoration(labelText: 'Técnico responsable'),
                items: _tecnicos
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.nombre),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => tecnicoId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: tecnicoId == null
                  ? null
                  : () => Navigator.pop(dialogContext, tecnicoId),
              child: const Text('Guardar regla'),
            ),
          ],
        ),
      ),
    );

    if (resultado == null || !mounted) return;

    try {
      await _service.guardarRegla(
        token: widget.token,
        categoriaId: categoriaId,
        tecnicoId: resultado,
      );
      _mostrarExito('Regla guardada.');
      await _cargarTodo();
    } on TicketApiException catch (e) {
      _mostrarError(e);
    }
  }

  String? _tecnicoDeRegla(int categoriaId) {
    final regla = _reglas.where((r) => r.categoriaId == categoriaId).firstOrNull;
    if (regla == null) return null;
    final tecnico = _tecnicos.where((t) => t.id == regla.tecnicoId).firstOrNull;
    return tecnico?.nombre;
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;

    return ColoredBox(
      color: LuvegiColors.background,
      child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(
                mobile ? LuvegiSpacing.md : LuvegiSpacing.xl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCategorias(),
                      const SizedBox(height: LuvegiSpacing.lg),
                      _buildPrioridades(),
                      const SizedBox(height: LuvegiSpacing.lg),
                      _buildTecnicos(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _seccion({
    required String titulo,
    required List<Widget> acciones,
    required List<Widget> hijos,
    Widget? buscador,
  }) {
    return Container(
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
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
              Expanded(child: Text(titulo, style: LuvegiText.title)),
              ...acciones,
            ],
          ),
          const SizedBox(height: LuvegiSpacing.md),
          if (buscador != null) ...[
            buscador,
            const SizedBox(height: LuvegiSpacing.sm),
          ],
          ...hijos,
        ],
      ),
    );
  }

  Widget _campoBusqueda({
    required String hint,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }

  List<TicketCategoria> get _categoriasFiltradas {
    final q = _buscarCategorias.trim().toLowerCase();
    if (q.isEmpty) return _categorias;
    return _categorias
        .where(
          (c) =>
              c.nombre.toLowerCase().contains(q) ||
              c.descripcion.toLowerCase().contains(q),
        )
        .toList();
  }

  List<TicketPrioridad> get _prioridadesFiltradas {
    final q = _buscarPrioridades.trim().toLowerCase();
    if (q.isEmpty) return _prioridades;
    return _prioridades.where((p) => p.nombre.toLowerCase().contains(q)).toList();
  }

  List<TicketTecnico> get _tecnicosFiltrados {
    final q = _buscarTecnicos.trim().toLowerCase();
    if (q.isEmpty) return _tecnicos;
    return _tecnicos
        .where(
          (t) =>
              t.nombre.toLowerCase().contains(q) ||
              t.correo.toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _paginador({
    required int total,
    required int pagina,
    required VoidCallback onAnterior,
    required VoidCallback onSiguiente,
  }) {
    if (total <= _pageSize) {
      return Padding(
        padding: const EdgeInsets.only(top: LuvegiSpacing.sm),
        child: Text('$total registros', style: LuvegiText.caption),
      );
    }

    final totalPaginas = (total / _pageSize).ceil();

    return Padding(
      padding: const EdgeInsets.only(top: LuvegiSpacing.sm),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$total registros · Página $pagina de $totalPaginas',
            style: LuvegiText.caption,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Anterior',
                onPressed: pagina > 1 ? onAnterior : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Siguiente',
                onPressed: pagina < totalPaginas ? onSiguiente : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeActivo(bool activo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: activo
            ? LuvegiColors.success.withValues(alpha: 0.12)
            : LuvegiColors.textSecondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: activo ? LuvegiColors.success : LuvegiColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildCategorias() {
    final filtradas = _categoriasFiltradas;
    final pagina = _paginaValida(_paginaCategorias, filtradas.length);
    final items = _porPagina(filtradas, pagina);

    return _seccion(
      titulo: 'Categorías',
      acciones: [
        OutlinedButton.icon(
          onPressed: _crearCategoria,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nueva'),
        ),
      ],
      buscador: _campoBusqueda(
        hint: 'Buscar categoría',
        controller: _buscarCategoriasCtrl,
        onChanged: (v) => setState(() {
          _buscarCategorias = v;
          _paginaCategorias = 1;
        }),
      ),
      hijos: [
        if (filtradas.isEmpty)
          Text(
            _categorias.isEmpty
                ? 'No hay categorías registradas.'
                : 'Sin resultados para la búsqueda.',
            style: const TextStyle(color: LuvegiColors.textSecondary),
          )
        else ...[
          ...items.map((c) {
            final tecnico = _tecnicoDeRegla(c.id);
            return Material(
              color: LuvegiColors.surface,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  c.activo ? Icons.check_circle_outline : Icons.block,
                  color: c.activo
                      ? LuvegiColors.success
                      : LuvegiColors.textSecondary,
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(c.nombre)),
                    const SizedBox(width: LuvegiSpacing.sm),
                    _badgeActivo(c.activo),
                  ],
                ),
                subtitle: Text(
                  c.descripcion.isEmpty ? 'Sin descripción' : c.descripcion,
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Acciones',
                  onSelected: (accion) {
                    switch (accion) {
                      case 'editar':
                        _editarCategoria(c);
                      case 'subcategorias':
                        _gestionarSubcategorias(c);
                      case 'tecnico':
                        _guardarRegla(c.id);
                      case 'toggle':
                        _toggleCategoria(c);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined, size: 18),
                        title: Text('Editar'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'subcategorias',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.account_tree_outlined,
                          size: 18,
                        ),
                        title: Text(
                          'Subcategorías (${_subcategoriasDe(c.id).length})',
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'tecnico',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.person_add_alt_outlined,
                          size: 18,
                        ),
                        title: Text(tecnico ?? 'Asignar técnico'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          c.activo
                              ? Icons.toggle_off_outlined
                              : Icons.toggle_on_outlined,
                          size: 18,
                        ),
                        title: Text(c.activo ? 'Desactivar' : 'Activar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          _paginador(
            total: filtradas.length,
            pagina: pagina,
            onAnterior: () => setState(() => _paginaCategorias = pagina - 1),
            onSiguiente: () => setState(() => _paginaCategorias = pagina + 1),
          ),
        ],
      ],
    );
  }

  Widget _buildPrioridades() {
    final filtradas = _prioridadesFiltradas;
    final pagina = _paginaValida(_paginaPrioridades, filtradas.length);
    final items = _porPagina(filtradas, pagina);

    return _seccion(
      titulo: 'Prioridades',
      acciones: [
        OutlinedButton.icon(
          onPressed: _crearPrioridad,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nueva'),
        ),
      ],
      buscador: _campoBusqueda(
        hint: 'Buscar prioridad',
        controller: _buscarPrioridadesCtrl,
        onChanged: (v) => setState(() {
          _buscarPrioridades = v;
          _paginaPrioridades = 1;
        }),
      ),
      hijos: [
        if (filtradas.isEmpty)
          Text(
            _prioridades.isEmpty
                ? 'No hay prioridades registradas.'
                : 'Sin resultados para la búsqueda.',
            style: const TextStyle(color: LuvegiColors.textSecondary),
          )
        else ...[
          ...items.map((p) {
            return Material(
              color: LuvegiColors.surface,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: TicketUtils.colorPrioridad(p.nombre, p.color),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(p.nombre)),
                    const SizedBox(width: LuvegiSpacing.sm),
                    _badgeActivo(p.activo),
                  ],
                ),
                subtitle: Text('Nivel ${p.nivel}'),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Acciones',
                  onSelected: (accion) {
                    switch (accion) {
                      case 'editar':
                        _editarPrioridad(p);
                      case 'toggle':
                        _togglePrioridad(p);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined, size: 18),
                        title: Text('Editar'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          p.activo
                              ? Icons.toggle_off_outlined
                              : Icons.toggle_on_outlined,
                          size: 18,
                        ),
                        title: Text(p.activo ? 'Desactivar' : 'Activar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          _paginador(
            total: filtradas.length,
            pagina: pagina,
            onAnterior: () => setState(() => _paginaPrioridades = pagina - 1),
            onSiguiente: () => setState(() => _paginaPrioridades = pagina + 1),
          ),
        ],
      ],
    );
  }

  Widget _buildTecnicos() {
    final filtrados = _tecnicosFiltrados;
    final pagina = _paginaValida(_paginaTecnicos, filtrados.length);
    final items = _porPagina(filtrados, pagina);

    return _seccion(
      titulo: 'Personal TI',
      acciones: const [],
      buscador: _campoBusqueda(
        hint: 'Buscar por nombre o correo',
        controller: _buscarTecnicosCtrl,
        onChanged: (v) => setState(() {
          _buscarTecnicos = v;
          _paginaTecnicos = 1;
        }),
      ),
      hijos: [
        if (filtrados.isEmpty)
          Text(
            _tecnicos.isEmpty
                ? 'No hay personal de TI configurado. El administrador debe asignar el permiso ADMIN_TICKETS a los usuarios del área.'
                : 'Sin resultados para la búsqueda.',
            style: const TextStyle(color: LuvegiColors.textSecondary),
          )
        else ...[
          ...items.map(
            (t) => Material(
              color: LuvegiColors.surface,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: LuvegiColors.secondaryLight,
                  child: Icon(
                    Icons.support_agent_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(t.nombre),
                subtitle: Text(t.correo),
              ),
            ),
          ),
          _paginador(
            total: filtrados.length,
            pagina: pagina,
            onAnterior: () => setState(() => _paginaTecnicos = pagina - 1),
            onSiguiente: () => setState(() => _paginaTecnicos = pagina + 1),
          ),
        ],
      ],
    );
  }

  static const List<String> _coloresPrioridad = [
    '#E64833',
    '#F4A300',
    '#2E86DE',
    '#27AE60',
    '#8E44AD',
    '#7F8C8D',
  ];
}
