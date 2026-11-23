import 'package:flutter/material.dart';

import '../../services/encuesta_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_text.dart';
import '../../utils/dialog_controllers.dart';

/// Abre el selector de personal que puede votar en una encuesta.
/// Devuelve la lista de ids seleccionados, o null si se cancelo.
Future<List<int>?> mostrarSelectorVotantes({
  required BuildContext context,
  required EncuestaService service,
  required String token,
  required int encuestaId,
}) async {
  List<Map<String, dynamic>> personas = [];
  try {
    final data = await service.listarVotantes(
      token: token,
      encuestaId: encuestaId,
    );
    final raw = data['usuarios'] as List<dynamic>? ?? const [];
    personas = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar el personal: $e'),
          backgroundColor: LuvegiColors.error,
        ),
      );
    }
    return null;
  }

  if (!context.mounted) return null;

  if (personas.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay usuarios activos para mostrar.')),
    );
    return null;
  }

  final seleccionados = <int>{
    for (final p in personas)
      if (p['votante'] == true) (p['id'] as num).toInt(),
  };

  final filtroCtrl = TextEditingController();

  final resultado = await showDialog<List<int>>(
    context: context,
    builder: (ctx) => DialogControllers(
      controllers: [filtroCtrl],
      builder: (ctx, setDialogState) {
        final q = filtroCtrl.text.trim().toLowerCase();
        final filtrados = q.isEmpty
            ? personas
            : personas.where((p) {
                final n = (p['nombre'] ?? '').toString().toLowerCase();
                final c = (p['correo'] ?? '').toString().toLowerCase();
                final a = (p['areas'] ?? '').toString().toLowerCase();
                final r = (p['rol_nombre'] ?? '').toString().toLowerCase();
                return n.contains(q) ||
                    c.contains(q) ||
                    a.contains(q) ||
                    r.contains(q);
              }).toList();

        // Agrupado por area: con ~150 personas una lista plana es ilegible.
        final grupos = <String, List<Map<String, dynamic>>>{};
        for (final p in filtrados) {
          final area = (p['areas'] ?? '').toString().trim();
          final clave = area.isEmpty ? 'Sin area asignada' : area;
          grupos.putIfAbsent(clave, () => <Map<String, dynamic>>[]).add(p);
        }
        final claves = grupos.keys.toList()..sort();

        // Ancho y alto fijos: el AlertDialog pide el ancho intrinseco de su
        // contenido y un viewport sin ancho fijo revienta.
        final anchoLista = (MediaQuery.of(ctx).size.width - 96).clamp(
          260.0,
          430.0,
        );
        final altoLista = (MediaQuery.of(ctx).size.height * 0.44).clamp(
          200.0,
          380.0,
        );

        return AlertDialog(
          title: const Text('Personal que puede votar'),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: LuvegiColors.menuHover,
                    borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: LuvegiColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Solo podrá votar el personal que marques aquí. '
                          'Si no marcas a nadie, nadie podrá votar.',
                          style: LuvegiText.caption,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: filtroCtrl,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, correo, area o rol',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: LuvegiColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                      borderSide: const BorderSide(color: LuvegiColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                      borderSide: const BorderSide(color: LuvegiColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                      borderSide: const BorderSide(
                        color: LuvegiColors.secondary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setDialogState(() {
                        seleccionados
                          ..clear()
                          ..addAll(
                            filtrados.map((p) => (p['id'] as num).toInt()),
                          );
                      }),
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Marcar visibles'),
                      style: TextButton.styleFrom(
                        foregroundColor: LuvegiColors.secondary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          setDialogState(() => seleccionados.clear()),
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Limpiar'),
                      style: TextButton.styleFrom(
                        foregroundColor: LuvegiColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: LuvegiColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${seleccionados.length}/${personas.length}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: anchoLista,
                  height: altoLista,
                  child: ListView.builder(
                    itemCount: claves.length,
                    itemBuilder: (_, i) {
                      final clave = claves[i];
                      final miembros = grupos[clave]!;
                      final ids = miembros
                          .map((p) => (p['id'] as num).toInt())
                          .toList();
                      final todos = ids.every(
                        (id) => seleccionados.contains(id),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: LuvegiColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    clave.toUpperCase(),
                                    style: LuvegiText.caption.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 0.6,
                                      color: LuvegiColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${miembros.length}',
                                  style: LuvegiText.caption.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: LuvegiColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setDialogState(() {
                                    if (todos) {
                                      for (final id in ids) {
                                        seleccionados.remove(id);
                                      }
                                    } else {
                                      seleccionados.addAll(ids);
                                    }
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: todos
                                          ? LuvegiColors.error
                                          : LuvegiColors.menuHover,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      todos ? 'Quitar' : 'Marcar todos',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: todos
                                            ? Colors.white
                                            : LuvegiColors.secondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...miembros.map(
                            (p) => _filaPersona(
                              p,
                              seleccionado: seleccionados.contains(
                                (p['id'] as num).toInt(),
                              ),
                              onTap: () => setDialogState(() {
                                final id = (p['id'] as num).toInt();
                                if (seleccionados.contains(id)) {
                                  seleccionados.remove(id);
                                } else {
                                  seleccionados.add(id);
                                }
                              }),
                              token: token,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, seleccionados.toList()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    ),
  );

  if (resultado == null || resultado.isNotEmpty || !context.mounted) {
    return resultado;
  }

  // Guardar sin nadie marcado deja la encuesta sin votantes: se confirma.
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sin personal habilitado'),
      content: const Text(
        'No marcaste a nadie. Si guardas, nadie podrá votar en esta encuesta '
        'hasta que asignes personal.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: LuvegiColors.error),
          child: const Text('Guardar sin votantes'),
        ),
      ],
    ),
  );
  return confirmar == true ? resultado : null;
}

/// Fila de una persona: foto (o iniciales), nombre y area.
Widget _filaPersona(
  Map<String, dynamic> persona, {
  required bool seleccionado,
  required VoidCallback onTap,
  required String token,
}) {
  final nombre = (persona['nombre'] ?? '').toString();
  final areas = (persona['areas'] ?? '').toString();
  final fotoUrl = (persona['foto_url'] ?? '').toString();

  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: seleccionado ? LuvegiColors.menuHover : Colors.transparent,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: Checkbox(
              value: seleccionado,
              onChanged: (_) => onTap(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 15,
            backgroundColor: LuvegiColors.secondary.withValues(alpha: 0.14),
            child: fotoUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      fotoUrl,
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                      headers: {'Authorization': 'Bearer $token'},
                      errorBuilder: (_, _, _) => Text(
                        _iniciales(nombre),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: LuvegiColors.secondary,
                        ),
                      ),
                    ),
                  )
                : Text(
                    _iniciales(nombre),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: LuvegiColors.secondary,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuvegiText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.2,
                  ),
                ),
                if (areas.isNotEmpty)
                  Text(
                    areas,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LuvegiText.caption.copyWith(fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _iniciales(String nombre) {
  final partes = nombre
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) {
    return partes.first.substring(0, 1).toUpperCase();
  }
  return (partes[0].substring(0, 1) + partes[1].substring(0, 1)).toUpperCase();
}
