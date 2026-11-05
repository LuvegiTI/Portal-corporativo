import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tracking.dart';

const String baseImg = "https://contacto.luvegi.com/recursos/";
const String logoLuvegi = "logo.webp";
const String urlLuvegi = "https://www.luvegi.com";

void main() {
  runApp(const LuvegiApp());
}

class Ejecutivo {
  final String nombre;
  final String cargo;
  final String wsp;
  final String foto;

  const Ejecutivo({
    required this.nombre,
    required this.cargo,
    required this.wsp,
    required this.foto,
  });
}

final Map<String, Ejecutivo> ejecutivos = {
  "01": const Ejecutivo(nombre: "HUGO TORRES", cargo: "JEFE COMERCIAL", wsp: "991999471", foto: "fotoHugo.webp"),
  "02": const Ejecutivo(nombre: "ANGELA VARGAS", cargo: "EJECUTIVA COMERCIAL", wsp: "991999461", foto: "fotoAngela.webp"),
  "03": const Ejecutivo(nombre: "RAFAEL BOLIVAR", cargo: "EJECUTIVO COMERCIAL", wsp: "991999459", foto: "fotoRafael.webp"),
  "04": const Ejecutivo(nombre: "ROCIO SALINAS", cargo: "EJECUTIVA COMERCIAL", wsp: "991999452", foto: "fotoRocio.webp"),
  "05": const Ejecutivo(nombre: "JIMMY SÁNCHEZ", cargo: "EJECUTIVO COMERCIAL", wsp: "991999462", foto: "fotoJimmy.webp"),
  "06": const Ejecutivo(nombre: "ENRIQUE NEIRA", cargo: "EJECUTIVO COMERCIAL", wsp: "991999467", foto: "fotoEnrique.webp"),
  "07": const Ejecutivo(nombre: "JULIO HUAREZ", cargo: "EJECUTIVO COMERCIAL", wsp: "991999449", foto: "fotoJulio.webp"),
  "08": const Ejecutivo(nombre: "VALERIA OJEDA", cargo: "EJECUTIVA COMERCIAL", wsp: "991999488", foto: "fotoValeria.webp"),
  "09": const Ejecutivo(nombre: "RENZO GONZALEZ", cargo: "EJECUTIVO COMERCIAL", wsp: "940187291", foto: "fotoRenzo.webp"),
  "10": const Ejecutivo(nombre: "LUIS HURTADO", cargo: "GERENTE COMERCIAL", wsp: "991999475", foto: "fotoLuis.webp"),
  "11": const Ejecutivo(nombre: "ISSAYA CHAVEZ", cargo: "EJECUTIVA COMERCIAL", wsp: "997127370", foto: "fotoIssaya.webp"),
  "12": const Ejecutivo(nombre: "OSCAR ERNAU", cargo: "EJECUTIVO COMERCIAL", wsp: "987212629", foto: "fotoOscar.webp"),
  "13": const Ejecutivo(nombre: "LUIS GIUSTI", cargo: "GERENTE DE DESARROLLO Y ESTRATEGIA DE NEGOCIO", wsp: "991999495", foto: "fotoLuwa.webp"),
  "14": const Ejecutivo(nombre: "DIEGO CASARIEGO", cargo: "EJECUTIVO DE NEGOCIOS RENTA", wsp: "991999490", foto: "fotoDiego.webp"),
  "15": const Ejecutivo(nombre: "LUIS CESPEDES", cargo: "JEFE COMERCIAL DE RENTA", wsp: "965380922", foto: "fotoLuisCespedes.webp"),
  "16": const Ejecutivo(nombre: "JOSE RAMOS", cargo: "EJECUTIVO POSTVENTA", wsp: "991999466", foto: "fotoJose.webp"),
  //"17": const Ejecutivo(nombre: "PAOLA ESCOBEDO", cargo: "EJECUTIVA COMERCIAL", wsp: "959752400", foto: "fotoPaola.webp"),
  "18": const Ejecutivo(nombre: "SERGIO ALVAREZ", cargo: "SUB GERENTE DE PROYECTOS", wsp: "991999451", foto: "fotoSergio.webp"),
  "19": const Ejecutivo(nombre: "JHONATAN TORRES", cargo: "JEFE COMERCIAL DE SERVICIOS", wsp: "991999445", foto: "fotoJhonatan.webp"),
};

class LuvegiApp extends StatelessWidget {
  const LuvegiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(textTheme: GoogleFonts.montserratTextTheme()),
      home: const TarjetaEjecutivaPage(),
    );
  }
}

/// Resuelve el ejecutivo a partir de la URL.
///
/// Acepta `/01`, `/ejecutivos/01` (subdirectorio) y `?e=01` o `?e=rafael-bolivar`.
/// Si la ruta no corresponde a ningun ejecutivo devuelve null, para no mostrar la
/// tarjeta de otra persona.
Ejecutivo? resolverEjecutivo(Uri uri) {
  for (final segmento in uri.pathSegments.reversed) {
    final encontrado = ejecutivos[segmento];
    if (encontrado != null) return encontrado;
  }

  final parametro = uri.queryParameters[_parametroEjecutivo]?.trim().toLowerCase();
  if (parametro == null || parametro.isEmpty) return null;

  return ejecutivos[parametro] ?? ejecutivoPorNombre[parametro];
}

const String _parametroEjecutivo = "e";

final Map<String, Ejecutivo> ejecutivoPorNombre = {
  for (final entrada in ejecutivos.entries)
    _slugNombre(entrada.value.nombre): entrada.value,
};

String _slugNombre(String nombre) =>
    nombre.toLowerCase().replaceAll(" ", "-");

String? codigoDe(Ejecutivo ejecutivo) {
  for (final entrada in ejecutivos.entries) {
    if (identical(entrada.value, ejecutivo) ||
        entrada.value.nombre == ejecutivo.nombre) {
      return entrada.key;
    }
  }
  return null;
}

class TarjetaEjecutivaPage extends StatefulWidget {
  final Ejecutivo? ejecutivo;

  const TarjetaEjecutivaPage({super.key, this.ejecutivo});

  @override
  State<TarjetaEjecutivaPage> createState() => _TarjetaEjecutivaPageState();
}

class _TarjetaEjecutivaPageState extends State<TarjetaEjecutivaPage> {
  @override
  void initState() {
    super.initState();

    final actual = widget.ejecutivo ?? resolverEjecutivo(Uri.base);
    if (actual != null) {
      TarjetaTracking.visita(codigoDe(actual));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.ejecutivo ?? resolverEjecutivo(Uri.base);
    if (actual == null) return const _TarjetaNoEncontradaPage();

    return _TarjetaEjecutivaLayout(ejecutivo: actual);
  }
}

class _TarjetaEjecutivaLayout extends StatelessWidget {
  final Ejecutivo ejecutivo;

  const _TarjetaEjecutivaLayout({required this.ejecutivo});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final isMobile = w < 700;
        final isTablet = w >= 700 && w < 1100;
        final isDesktop = w >= 1100;

        return Scaffold(
          backgroundColor: isMobile ? Colors.white : const Color(0xFFFF0000),
          body: Stack(
            children: [
              if (!isMobile) const Positioned.fill(child: _FondoPuntos()),

              if (isMobile)
                SizedBox.expand(
                  child: _TarjetaCentral(
                    ejecutivo: ejecutivo,
                    cardWidth: w,
                    mode: _CardMode.mobile,
                  ),
                ),

              if (isTablet)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 500,
                        height: 860,
                        child: Center(
                          child: _TarjetaCentral(
                            ejecutivo: ejecutivo,
                            cardWidth: 500,
                            mode: _CardMode.tablet,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              if (isDesktop)
                _DesktopLayout(
                  ejecutivo: ejecutivo,
                  screenWidth: w,
                  screenHeight: h,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TarjetaNoEncontradaPage extends StatelessWidget {
  const _TarjetaNoEncontradaPage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final escala = isMobile ? 1.0 : (constraints.maxWidth / 1100).clamp(1.0, 1.6);

        return Scaffold(
          backgroundColor: isMobile ? Colors.white : const Color(0xFFFF0000),
          body: Stack(
            children: [
              if (!isMobile) const Positioned.fill(child: _FondoPuntos()),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 28 * escala, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 190 * escala,
                        height: 60 * escala,
                        alignment: Alignment.center,
                        child: Image.network(
                          "$baseImg$logoLuvegi",
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Text(
                            "LUVEGI",
                            style: GoogleFonts.montserrat(
                              color: isMobile ? const Color(0xFF111111) : Colors.white,
                              fontSize: 34 * escala,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 40 * escala),
                      Text(
                        "TARJETA NO ENCONTRADA",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: isMobile ? const Color(0xFF111111) : Colors.white,
                          fontSize: 28 * escala,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 16 * escala),
                      Text(
                        "El enlace que abriste no corresponde a ningún ejecutivo. "
                        "Revisa la dirección o escríbenos por nuestros canales oficiales.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: isMobile ? const Color(0xFF555555) : Colors.white.withValues(alpha: .92),
                          fontSize: 15 * escala,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 34 * escala),
                      Semantics(
                        button: true,
                        label: "Ir al sitio web de LUVEGI",
                        child: GestureDetector(
                          onTap: () => _abrirExterno(urlLuvegi),
                          child: Container(
                            width: 220 * escala,
                            height: 46 * escala,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Text(
                              urlLuvegi.replaceFirst("https://", ""),
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 14 * escala,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final Ejecutivo ejecutivo;
  final double screenWidth;
  final double screenHeight;

  const _DesktopLayout({
    required this.ejecutivo,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    const double designW = 1500;
    const double designH = 860;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: designW,
            height: designH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 500,
                  height: 760,
                  child: _PanelIzquierdo(),
                ),
                const SizedBox(width: 50),
                SizedBox(
                  width: 400,
                  height: designH,
                  child: Center(
                    child: _TarjetaCentral(
                      ejecutivo: ejecutivo,
                      cardWidth: 400,
                      mode: _CardMode.desktop,
                    ),
                  ),
                ),
                const SizedBox(width: 50),
                const SizedBox(
                  width: 500,
                  height: 760,
                  child: _PanelDerecho(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FondoPuntos extends StatelessWidget {
  const _FondoPuntos();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PuntosPainter());
}

class _PuntosPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    const gap = 20.0;
    const radius = 2.3;

    for (double x = -10; x <= size.width + 10; x += gap) {
      for (double y = -10; y <= size.height + 10; y += gap) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _PanelIzquierdo extends StatelessWidget {
  const _PanelIzquierdo();

  @override
  Widget build(BuildContext context) {
    const shadow = [
      Shadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 5)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final zonaNumTop = h * 0.34;
        final zonaNumHeight = h * 0.38;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: h * 0.04,
              left: 0,
              right: 0,
              child: Text(
                "Desde 1980",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Positioned(
              top: h * 0.18,
              left: 30,
              right: 30,
              child: Container(height: 2.5, color: Colors.white.withValues(alpha: .65)),
            ),
            Positioned(
              top: h * 0.21,
              left: 0,
              right: 0,
              child: Text(
                "Más de",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 76,
                  height: .9,
                  fontWeight: FontWeight.w900,
                  shadows: shadow,
                ),
              ),
            ),
            Positioned(
              top: zonaNumTop,
              left: 0,
              right: 0,
              height: zonaNumHeight,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  "45",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 400,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -5,
                    shadows: const [
                      Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 7)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: h * 0.725,
              left: 0,
              right: 0,
              child: Text(
                "años de",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 68,
                  height: .82,
                  fontWeight: FontWeight.w900,
                  shadows: shadow,
                ),
              ),
            ),
            Positioned(
              top: h * 0.845,
              left: 0,
              right: 0,
              child: Text(
                "experiencia",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 68,
                  height: .82,
                  fontWeight: FontWeight.w900,
                  shadows: shadow,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PanelDerecho extends StatelessWidget {
  const _PanelDerecho();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: h * 0.04,
              left: 0,
              right: 0,
              child: Text(
                "Marcas\nAsociadas",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 42,
                  height: 1.1,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            Positioned(
              top: h * 0.18,
              left: 30,
              right: 30,
              child: Container(height: 2.5, color: Colors.white.withValues(alpha: .6)),
            ),
            Positioned(
              top: h * 0.23,
              left: 0,
              right: 0,
              child: SizedBox(
                width: 349,
                height: 597,
                child: _ImagenRemota(
                  nombre: "recurso.webp",
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _CardMode { mobile, tablet, desktop }

class _TarjetaCentral extends StatelessWidget {
  final Ejecutivo ejecutivo;
  final double cardWidth;
  final _CardMode mode;

  const _TarjetaCentral({
    required this.ejecutivo,
    required this.cardWidth,
    required this.mode,
  });

  bool get isMobile => mode == _CardMode.mobile;
  bool get isTablet => mode == _CardMode.tablet;
  bool get isDesktop => mode == _CardMode.desktop;

  Future<void> _whatsapp() {
    if (ejecutivo.wsp.trim().isEmpty) return Future.value();

    final mensaje =
        "Hola ${ejecutivo.nombre}, quisiera más información.";
    final numero = "51${ejecutivo.wsp}";

    TarjetaTracking.clicWhatsapp(codigoDe(ejecutivo), numero, mensaje);

    return _abrirExterno(
      "https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}",
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 860.0;

        final baseW = isMobile ? 390.0 : 400.0;
        final baseH = isMobile ? 760.0 : 760.0;

        final scaleW = cardWidth / baseW;
        final scaleH = maxH / baseH;

        final s = isMobile
            ? math.min(scaleW, scaleH).clamp(0.70, 1.15)
            : (cardWidth / 400).clamp(0.78, 1.25);

        double v(double x) => x * s;
        double fs(double x) => x * s.clamp(0.88, 1.10);

        final fotoVacia = ejecutivo.foto.trim().isEmpty;

        final logoH = v(isMobile ? 84 : 82);
        final bannerH = v(isMobile ? 170 : 186);
        final avatarD = v(isMobile ? 118 : 134);
        final avatarOffset = avatarD / 2 + v(4);

        final cargoFs = fs(isMobile ? 11.5 : 13);
        final nombreFs = fs(isMobile ? 22 : 26);
        final btnH = v(isMobile ? 48 : 38);
        final btnWebH = v(isMobile ? 34 : 34);

        return SizedBox(
          width: cardWidth,
          height: isMobile ? double.infinity : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(28),
              boxShadow: isMobile
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .18),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Container(
                  height: logoH,
                  width: double.infinity,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: _ImagenRemota(
                    nombre: "logo.webp",
                    width: v(isMobile ? 220 : 200),
                    height: v(isMobile ? 65 : 62),
                  ),
                ),

                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    ClipPath(
                      clipper: _CurvaConvexaClipper(),
                      child: Container(
                        height: bannerH,
                        width: double.infinity,
                        color: const Color(0xFFFF0000),
                        child: Column(
                          children: [
                            SizedBox(height: v(22)),
                            SizedBox(
                              height: v(32),
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: v(18)),
                                  child: Text(
                                    ejecutivo.cargo.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white.withValues(alpha: .95),
                                      fontSize: cargoFs,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.2,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: v(6)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: v(18)),
                              child: Text(
                                ejecutivo.nombre.toUpperCase(),
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: nombreFs,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -avatarOffset,
                      child: Container(
                        width: avatarD,
                        height: avatarD,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .10),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(v(5)),
                        child: ClipOval(
                          child: fotoVacia
                              ? Container(
                                  color: Colors.white,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.person,
                                    size: v(58),
                                    color: Colors.grey.shade300,
                                  ),
                                )
                              : _ImagenRemota(
                                  nombre: ejecutivo.foto,
                                  fit: BoxFit.cover,
                                  marcador: Container(
                                    color: Colors.white,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.person,
                                      size: v(58),
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: avatarOffset + v(10)),

                Text(
                  "EXPERIENCIA EN EL RUBRO:",
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFF111111),
                    fontSize: fs(isMobile ? 12.5 : 13.5),
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                SizedBox(height: v(10)),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: v(isMobile ? 28 : 10)),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: v(isMobile ? 10 : 16),
                      horizontal: v(isMobile ? 10 : 12),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Rubro("INDUSTRIAL", scale: s),
                              SizedBox(height: v(6)),
                              _Rubro("CONSTRUCCIÓN", scale: s),
                              SizedBox(height: v(6)),
                              _Rubro("SECTOR PÚBLICO", scale: s),
                              SizedBox(height: v(6)),
                              _Rubro("TELECOMUNICACIONES", scale: s),
                            ],
                          ),
                        ),
                        SizedBox(width: v(8)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Rubro("SALUD", scale: s),
                              SizedBox(height: v(6)),
                              _Rubro("MINERÍA", scale: s),
                              SizedBox(height: v(6)),
                              _Rubro("EDUCATIVO", scale: s),
                              SizedBox(height: v(6)),
                              _Rubro("TECNOLOGÍA", scale: s),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: v(14)),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: v(isMobile ? 22 : 4)),
                  child: Row(
                    children: [
                      Expanded(child: _Producto("GRUPOS\nELECTRÓGENOS", "grupo.webp", scale: s)),
                      Expanded(child: _Producto("TABLEROS\nELÉCTRICOS", "tableros.webp", scale: s)),
                      Expanded(child: _Producto("PANELES\nSOLARES", "panel.webp", scale: s)),
                    ],
                  ),
                ),

                SizedBox(height: v(20)),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: v(isMobile ? 30 : 28)),
                  child: Semantics(
                    button: true,
                    enabled: ejecutivo.wsp.trim().isNotEmpty,
                    label: "Contactar por WhatsApp a ${ejecutivo.nombre}",
                    child: GestureDetector(
                      onTap: ejecutivo.wsp.trim().isEmpty ? null : _whatsapp,
                      child: Container(
                        width: double.infinity,
                        height: btnH,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000),
                          borderRadius: BorderRadius.circular(35),
                        ),
                        child: Text(
                          isMobile ? "GUARDAR CONTACTO" : "CONTACTAR POR WHATSAPP",
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: fs(isMobile ? 17 : 12),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: v(14)),

                Semantics(
                  button: true,
                  label: "Ir al sitio web de LUVEGI",
                  child: GestureDetector(
                    onTap: () => _abrirExterno(urlLuvegi),
                    child: Container(
                      width: v(isMobile ? 180 : 165),
                      height: btnWebH,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        urlLuvegi.replaceFirst("https://", ""),
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: fs(isMobile ? 13 : 12),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: v(14)),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Social("fb.webp", "https://www.facebook.com/luvegiperu/", scale: s),
                    SizedBox(width: v(14)),
                    _Social("in.webp", "https://www.linkedin.com/company/luvegi", scale: s),
                    SizedBox(width: v(14)),
                    _Social("ig.webp", "https://www.instagram.com/luvegi.pe/", scale: s),
                    SizedBox(width: v(14)),
                    _Social("yt.webp", "https://www.youtube.com/@LuvegiIngenieros", scale: s),
                  ],
                ),

                if (isMobile) const Spacer(),

                SizedBox(height: v(isMobile ? 14 : 20)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CurvaConvexaClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 38);
    path.cubicTo(
      size.width * .23,
      size.height + 14,
      size.width * .77,
      size.height + 14,
      size.width,
      size.height - 38,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _Rubro extends StatelessWidget {
  final String text;
  final double scale;

  const _Rubro(this.text, {required this.scale});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          "•",
          style: TextStyle(
            color: const Color(0xFFFF0000),
            fontSize: 16 * scale.clamp(0.85, 1.05),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 4 * scale),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                color: const Color(0xFF222222),
                fontSize: 12 * scale.clamp(0.85, 1.05),
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Producto extends StatelessWidget {
  final String titulo;
  final String img;
  final double scale;

  const _Producto(this.titulo, this.img, {required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale.clamp(0.78, 1.10);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            color: const Color(0xFFFF0000),
            fontSize: 8.5 * s,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8 * s),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 90 * s,
            maxHeight: 56 * s,
          ),
          child: _ImagenRemota(nombre: img),
        ),
      ],
    );
  }
}

class _Social extends StatelessWidget {
  final String img;
  final String url;
  final double scale;

  const _Social(this.img, this.url, {required this.scale});

  Future<void> _abrir() => _abrirExterno(url);

  @override
  Widget build(BuildContext context) {
    final size = 26 * scale.clamp(0.85, 1.05);

    return Semantics(
      button: true,
      label: "Abrir $url",
      child: GestureDetector(
        onTap: _abrir,
        child: _ImagenRemota(
          nombre: img,
          width: size,
          height: size,
        ),
      ),
    );
  }
}

Future<void> _abrirExterno(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Imagen remota con estados de carga y error, para que un fallo de red no
/// deje un hueco roto ni desplace el layout.
class _ImagenRemota extends StatelessWidget {
  final String nombre;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final Widget? marcador;

  const _ImagenRemota({
    required this.nombre,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.marcador,
  });

  @override
  Widget build(BuildContext context) {
    final reemplazo = marcador ??
        SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: Icon(Icons.image_not_supported_outlined, size: 28),
          ),
        );

    return Image.network(
      "$baseImg$nombre",
      width: width,
      height: height,
      fit: fit,
      color: color,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return SizedBox(width: width, height: height);
      },
      errorBuilder: (context, error, stackTrace) => reemplazo,
    );
  }
}