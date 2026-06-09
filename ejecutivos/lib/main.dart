import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

const String baseImg = "https://contacto.luvegi.com/recursos/";

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
  "01": Ejecutivo(nombre: "HUGO TORRES", cargo: "JEFE COMERCIAL", wsp: "991999471", foto: "fotoHugo.webp"),
  "02": Ejecutivo(nombre: "ANGELA VARGAS", cargo: "EJECUTIVA COMERCIAL", wsp: "991999461", foto: "fotoAngela.webp"),
  "03": Ejecutivo(nombre: "RAFAEL BOLIVAR", cargo: "EJECUTIVO COMERCIAL", wsp: "991999459", foto: "fotoRafael.webp"),
  "04": Ejecutivo(nombre: "ROCIO SALINAS", cargo: "EJECUTIVA COMERCIAL", wsp: "991999452", foto: "fotoRocio.webp"),
  "05": Ejecutivo(nombre: "JIMMY SÁNCHEZ", cargo: "EJECUTIVO COMERCIAL", wsp: "991999462", foto: "fotoJimmy.webp"),
  "06": Ejecutivo(nombre: "ENRIQUE NEIRA", cargo: "EJECUTIVO COMERCIAL", wsp: "991999467", foto: "fotoEnrique.webp"),
  "07": Ejecutivo(nombre: "JULIO HUAREZ", cargo: "EJECUTIVO COMERCIAL", wsp: "991999449", foto: "fotoJulio.webp"),
  "08": Ejecutivo(nombre: "VALERIA OJEDA", cargo: "EJECUTIVA COMERCIAL", wsp: "991999488", foto: "fotoValeria.webp"),
  "09": Ejecutivo(nombre: "RENZO GONZALEZ", cargo: "EJECUTIVO COMERCIAL", wsp: "940187291", foto: "fotoRenzo.webp"),
  "10": Ejecutivo(nombre: "LUIS HURTADO", cargo: "GERENTE COMERCIAL", wsp: "991999475", foto: "fotoLuis.webp"),
  "11": Ejecutivo(nombre: "ISSAYA CHAVEZ", cargo: "EJECUTIVA COMERCIAL", wsp: "997127370", foto: "fotoIssaya.webp"),
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

class TarjetaEjecutivaPage extends StatelessWidget {
  const TarjetaEjecutivaPage({super.key});

  Ejecutivo get ejecutivoActual {
    final path = Uri.base.pathSegments.isNotEmpty ? Uri.base.pathSegments.first : "01";
    return ejecutivos[path] ?? ejecutivos["01"]!;
  }

  @override
  Widget build(BuildContext context) {
    final ejecutivo = ejecutivoActual;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 850;

    return Scaffold(
      backgroundColor: const Color(0xFFFF0000),
      body: Stack(
        children: [
          const Positioned.fill(child: FondoPuntos()),
          SafeArea(
            child: isMobile
                ? SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: TarjetaCentral(ejecutivo: ejecutivo),
                    ),
                  )
                : Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 1900,
                        height: 880,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(
                              width: 580,
                              child: PanelIzquierdo(),
                            ),
                            const SizedBox(width: 60),
                            SizedBox(
                              width: 400,
                              child: Align(
                                alignment: Alignment.center,
                                child: SizedBox(
                                  height: 840,
                                  child: TarjetaCentral(ejecutivo: ejecutivo),
                                ),
                              ),
                            ),
                            const SizedBox(width: 60),
                            const SizedBox(
                              width: 580,
                              child: PanelDerecho(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------
   FONDO DE PUNTOS
---------------------------------------- */
class FondoPuntos extends StatelessWidget {
  const FondoPuntos({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: PuntosPainter());
  }
}

class PuntosPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.35)
      ..style = PaintingStyle.fill;

    const gap = 18.0;
    for (double x = 0; x < size.width; x += gap) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.45, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PanelIzquierdo extends StatelessWidget {
  const PanelIzquierdo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "Desde 1980",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w300,
            shadows: const [
              Shadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Container(
          width: 420,
          height: 2,
          color: Colors.white70,
        ),

        const SizedBox(height: 22),

        Text(
          "Más de",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),

        Transform.translate(
          offset: const Offset(0, -4),
          child: Text(
            "45",
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 265,
              height: 0.90,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        Text(
          "años de",
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 62,
            height: 0.95,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),

        Text(
          "experiencia",
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 62,
            height: 0.95,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
class PanelDerecho extends StatelessWidget {
  const PanelDerecho({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 30,
        vertical: 40,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Marcas\nAsociados",
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w300,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: 420,
            height: 2,
            color: Colors.white70,
          ),

          const SizedBox(height: 25),

          Image.network(
            "${baseImg}recurso.webp",
            width: 350,
            fit: BoxFit.contain,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------
   TARJETA CENTRAL
---------------------------------------- */
class TarjetaCentral extends StatelessWidget {
  final Ejecutivo ejecutivo;

  const TarjetaCentral({super.key, required this.ejecutivo});

  Future<void> abrir(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 850;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(mobile ? 0 : 25),
        boxShadow: mobile
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(.25),
                  blurRadius: 24,
                  offset: const Offset(0, 13),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Logo LUVEGI
          Container(
            height: 75,
            alignment: Alignment.center,
            child: Image.network(
              "${baseImg}logo.webp",
              width: 210,
              fit: BoxFit.contain,
            ),
          ),

          // Cabecera roja con curva inferior
          Container(
            height: 170,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFFF0000),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.elliptical(100, 30),
                bottomRight: Radius.elliptical(100, 30),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 25),
                Text(
                  ejecutivo.cargo,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 13,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ejecutivo.nombre,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Foto circular superpuesta sobre la curva
          Transform.translate(
            offset: const Offset(0, -65),
            child: CircleAvatar(
              radius: 69,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 61,
                backgroundImage: NetworkImage("$baseImg${ejecutivo.foto}"),
              ),
            ),
          ),

          // Contenido inferior
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -50),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      "EXPERIENCIA EN EL RUBRO:",
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFF333333),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Grid rubros
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 15),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Rubro("INDUSTRIAL"),
                                SizedBox(height: 13),
                                Rubro("CONSTRUCCIÓN"),
                                SizedBox(height: 13),
                                Rubro("SECTOR PÚBLICO"),
                                SizedBox(height: 13),
                                Rubro("TELECOMUNICACIONES"),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Rubro("SALUD"),
                                SizedBox(height: 13),
                                Rubro("MINERÍA"),
                                SizedBox(height: 13),
                                Rubro("EDUCATIVO"),
                                SizedBox(height: 13),
                                Rubro("TECNOLOGÍA"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Productos
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25),
                      child: Row(
                        children: [
                          Producto("GRUPOS\nELECTRÓGENOS", "grupo.webp"),
                          Producto("TABLEROS\nELÉCTRICOS", "tableros.webp"),
                          Producto("PANELES\nSOLARES", "panel.webp"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Botón WhatsApp
                    InkWell(
                      onTap: () => abrir("https://wa.me/51${ejecutivo.wsp}"),
                      child: Container(
                        width: 300,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          "CONTACTAR POR WHATSAPP",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Botón web
                    InkWell(
                      onTap: () => abrir("https://www.luvegi.com"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          "www.luvegi.com",
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Redes sociales
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Social("fb.webp", "https://www.facebook.com/luvegiperu/"),
                        Social("in.webp", "https://www.linkedin.com/company/luvegi"),
                        Social("ig.webp", "https://www.instagram.com/luvegi.pe/"),
                        Social("yt.webp", "https://www.youtube.com/@LuvegiIngenieros"),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------
   WIDGETS AUXILIARES
---------------------------------------- */
class Rubro extends StatelessWidget {
  final String text;
  const Rubro(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          "•",
          style: TextStyle(
            color: Color(0xFFE50000),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              color: const Color(0xFF333333),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class Producto extends StatelessWidget {
  final String titulo;
  final String img;
  const Producto(this.titulo, this.img, {super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: Colors.red,
              fontSize: 8,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Image.network(
            "$baseImg$img",
            width: 65,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

class Social extends StatelessWidget {
  final String img;
  final String url;
  const Social(this.img, this.url, {super.key});

  Future<void> abrir() async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: abrir,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Image.network(
          "$baseImg$img",
          width: 28,
          height: 28,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}