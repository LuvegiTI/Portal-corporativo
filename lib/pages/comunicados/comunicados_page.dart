import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';

import '../../services/comunicado_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../utils/mensaje_error.dart';

class ComunicadosPage extends StatefulWidget {
  final String token;

  const ComunicadosPage({super.key, required this.token});

  @override
  State<ComunicadosPage> createState() => _ComunicadosPageState();
}

class _ComunicadosPageState extends State<ComunicadosPage> {
  final ComunicadoService _service = ComunicadoService();
  List<dynamic> _comunicados = [];
  bool _cargando = true;
  String? _error;

  // Escala de fuente para accesibilidad
  double _escalaFuente = 1.0;

  @override
  void initState() {
    super.initState();
    _cargarComunicados();
  }

  Future<void> _cargarComunicados() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final lista = await _service.listar(token: widget.token);
      if (!mounted) return;
      setState(() => _comunicados = lista);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _descargarArchivo(int id, int adjuntoId) async {
    try {
      final urlString = _service.archivoUrl(
        id,
        widget.token,
        adjuntoId: adjuntoId,
      );
      final uri = Uri.parse(urlString);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir el archivo'),
              backgroundColor: LuvegiColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: LuvegiColors.error,
          ),
        );
      }
    }
  }

  String _fecha(String valor) {
    if (valor.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(valor.replaceFirst(' ', 'T'));
    if (parsed == null) return valor;
    return DateFormat('dd MMM yyyy, HH:mm').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filtrar para el Muro de Avisos: Solo mostrar si tienen Imagen o Texto explicativo.
    // Esto oculta los que son "solo archivo" (como el SCTR) para que no ensucien el muro.
    final avisos = _comunicados
        .where((c) => c.tieneImagen || c.contenido.trim().isNotEmpty)
        .toList();

    return DefaultTabController(
      length: 1,
      child: Scaffold(
        backgroundColor: const Color(
          0xFFF1F5F9,
        ), // Fondo corporativo (Slate 100)
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.05),
          titleSpacing: LuvegiSpacing.lg,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LuvegiColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: LuvegiColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portal de Comunicados',
                    style: LuvegiText.title.copyWith(
                      fontSize: 18,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Avisos y normativas vigentes',
                    style: LuvegiText.caption.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Herramientas de accesibilidad (A-, A+)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Reducir texto',
                    icon: const Text(
                      'A-',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    onPressed: () {
                      if (_escalaFuente > 0.8)
                        setState(() => _escalaFuente -= 0.15);
                    },
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: const Color(0xFFCBD5E1),
                  ),
                  IconButton(
                    tooltip: 'Agrandar texto',
                    icon: const Text(
                      'A+',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    onPressed: () {
                      if (_escalaFuente < 2.0)
                        setState(() => _escalaFuente += 0.15);
                    },
                  ),
                ],
              ),
            ),
          ],
          bottom: const TabBar(
            labelColor: LuvegiColors.primary,
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: LuvegiColors.primary,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: [
              Tab(icon: Icon(Icons.feed_outlined), text: 'Muro de Avisos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // SECCIÓN 1: MURO DE AVISOS
            _buildTabMuroAvisos(avisos),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // PESTAÑA 1: MURO DE AVISOS
  // ========================================================================
  Widget _buildTabMuroAvisos(List<dynamic> avisos) {
    final ancho = MediaQuery.of(context).size.width;
    final paddingHorizontal = ancho > 850
        ? (ancho - 850) / 2
        : LuvegiSpacing.md;

    if (_cargando) return _buildShimmerLoading(paddingHorizontal);

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: LuvegiColors.error,
              size: 48,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            Text(_error!, style: LuvegiText.body),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _cargarComunicados,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LuvegiColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (avisos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: Colors.grey.shade400, size: 80),
            const SizedBox(height: 16),
            Text(
              'No hay avisos recientes',
              style: LuvegiText.title.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarComunicados,
      color: LuvegiColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: paddingHorizontal,
          vertical: LuvegiSpacing.xl,
        ),
        itemCount: avisos.length,
        itemBuilder: (context, index) {
          return _buildTarjetaComunicado(avisos[index]);
        },
      ),
    );
  }


  // ========================================================================
  // REACCIONES (tipo Facebook)
  // ========================================================================
  Future<void> _reaccionar(Comunicado comunicado, String tipo) async {
    // Update optimista: la UI responde al instante y se revierte si el
    // servidor rechaza la operacion.
    final anteriores = comunicado.reacciones;
    setState(() {
      _comunicados = _comunicados.map((c) {
        if (c.id != comunicado.id) return c;
        return Comunicado(
          id: c.id,
          titulo: c.titulo,
          contenido: c.contenido,
          importante: c.importante,
          activo: c.activo,
          autor: c.autor,
          creadoEn: c.creadoEn,
          tieneImagen: c.tieneImagen,
          tieneArchivo: c.tieneArchivo,
          archivoNombre: c.archivoNombre,
          archivoTamano: c.archivoTamano,
          archivos: c.archivos,
          reacciones: c.reacciones.alternando(tipo),
        );
      }).toList();
    });

    try {
      final nuevas = await _service.reaccionar(
        token: widget.token,
        comunicadoId: comunicado.id,
        tipo: tipo,
      );
      if (!mounted) return;
      setState(() {
        _comunicados = _comunicados.map((c) {
          if (c.id != comunicado.id) return c;
          return Comunicado(
            id: c.id,
            titulo: c.titulo,
            contenido: c.contenido,
            importante: c.importante,
            activo: c.activo,
            autor: c.autor,
            creadoEn: c.creadoEn,
            tieneImagen: c.tieneImagen,
            tieneArchivo: c.tieneArchivo,
            archivoNombre: c.archivoNombre,
            archivoTamano: c.archivoTamano,
            archivos: c.archivos,
            reacciones: nuevas,
          );
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      // Se revierte al estado anterior.
      setState(() {
        _comunicados = _comunicados.map((c) {
          if (c.id != comunicado.id) return c;
          return Comunicado(
            id: c.id,
            titulo: c.titulo,
            contenido: c.contenido,
            importante: c.importante,
            activo: c.activo,
            autor: c.autor,
            creadoEn: c.creadoEn,
            tieneImagen: c.tieneImagen,
            tieneArchivo: c.tieneArchivo,
            archivoNombre: c.archivoNombre,
            archivoTamano: c.archivoTamano,
            archivos: c.archivos,
            reacciones: anteriores,
          );
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MensajeError.desdeExcepcion(e)),
          backgroundColor: LuvegiColors.error,
        ),
      );
    }
  }

  Widget _buildBarraReacciones(Comunicado c) {
    final r = c.reacciones;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in tiposReaccion.entries)
                _botonReaccion(c, entry.key, entry.value),
            ],
          ),
          const SizedBox(width: 10),
          // Contador y nombres juntos en una sola linea. Al tocarlo se abre
          // la lista de quien reaccionó.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _resumenReacciones(r),
            ),
          ),
        ],
      ),
    );
  }

  /// "7 reacciones" - clickable. Los nombres de quien reaccionó solo se
  /// ven al tocarlo (se abre la lista completa).
  Widget _resumenReacciones(ComunicadoReacciones r) {
    if (r.total == 0) {
      return const Text(
        'Sin reacciones',
        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      );
    }

    final texto = r.total == 1 ? '1 reacción' : '${r.total} reacciones';

    return InkWell(
      onTap: () => _mostrarQuienReacciono(r),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          texto,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.3,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  void _mostrarQuienReacciono(ComunicadoReacciones r) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Text(
                  'Personas que reaccionaron',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: r.usuarios.length,
                  itemBuilder: (_, i) {
                    final u = r.usuarios[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFE0F2FE),
                        child: Text(
                          _iniciales(u.nombre),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: LuvegiColors.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        u.nombre.isEmpty ? 'Usuario' : u.nombre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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

  Widget _botonReaccion(Comunicado c, String tipo, String emoji) {
    final activa = c.reacciones.tiene(tipo);
    final cuenta = c.reacciones.cuenta(tipo);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _reaccionar(c, tipo),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: activa ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activa ? LuvegiColors.primary : const Color(0xFFE2E8F0),
              width: activa ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              if (cuenta > 0) ...[
                const SizedBox(width: 5),
                Text(
                  '$cuenta',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: activa ? LuvegiColors.primary : const Color(0xFF475569),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // TARJETA INDIVIDUAL DE NOTICIA (Estilo FB/IG con Límite de Altura)
  // ========================================================================
  Widget _buildTarjetaComunicado(dynamic c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.importante
              ? Colors.orange.shade300
              : const Color(0xFFE2E8F0),
          width: c.importante ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: c.importante
                ? Colors.orange.withOpacity(0.1)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CABECERA DESTACADA SI ES IMPORTANTE
          if (c.importante)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.orange.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade800,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AVISO PRIORITARIO',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),

          // IMAGEN ADAPTATIVA CON LÍMITE (maxHeight)
          if (c.tieneImagen)
            InkWell(
              onTap: () => _abrirImagenZoom(c),
              child: ClipRRect(
                borderRadius: c.importante
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(15)),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight:
                            450, // Límite de altura para que no ocupe toda la pantalla
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Image.network(
                          _service.imagenUrl(c.id, widget.token),
                          fit: BoxFit.cover,
                          alignment: Alignment
                              .topCenter, // Si se recorta, muestra la parte superior
                          errorBuilder: (_, __, ___) => const SizedBox(),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Shimmer.fromColors(
                              baseColor: Colors.grey.shade200,
                              highlightColor: Colors.grey.shade50,
                              child: Container(
                                height: 300,
                                width: double.infinity,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Icono flotante "Ampliar Imagen"
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Ampliar Imagen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // CONTENIDO DE TEXTO DE LA TARJETA
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.titulo,
                  style: TextStyle(
                    fontSize: 22 * (_escalaFuente > 1.2 ? 1.2 : _escalaFuente),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Metadatos (Autor y Fecha)
                Row(
                  children: [
                    if (c.autor.isNotEmpty) ...[
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        c.autor,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _fecha(c.creadoEn),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),

                // Texto Principal
                if (c.contenido.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    c.contenido,
                    style: TextStyle(
                      fontSize: 15 * _escalaFuente,
                      height: 1.6,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],

                // Botones de archivos adjuntos (En el Muro)
                if (c.archivos.isNotEmpty &&
                    (c.tieneImagen || c.contenido.trim().isNotEmpty)) ...[
                  const SizedBox(height: 20),
                  ...c.archivos.map(
                    (adjunto) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _descargarArchivo(c.id, adjunto.id),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Colors.redAccent,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    adjunto.nombre.isNotEmpty
                                        ? adjunto.nombre
                                        : 'Ver documento adjunto',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF334155),
                                      fontSize: 13 * _escalaFuente,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: LuvegiColors.primary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // Barra de reacciones del personal
                _buildBarraReacciones(c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Lógica para abrir la imagen en pantalla completa (Lightbox)
  void _abrirImagenZoom(dynamic c) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 5.0,
                child: Image.network(
                  _service.imagenUrl(c.id, widget.token),
                  fit: BoxFit
                      .contain, // Aquí sí se muestra 100% entera sin recortar
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(double paddingHorizontal) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: paddingHorizontal,
        vertical: LuvegiSpacing.lg,
      ),
      itemCount: 2,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 250,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 24,
                        width: 280,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                      ),
                      Container(
                        height: 14,
                        width: 200,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 24),
                      ),
                      Container(
                        height: 14,
                        width: double.infinity,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                      ),
                      Container(
                        height: 14,
                        width: double.infinity,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                      ),
                      Container(height: 14, width: 150, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
