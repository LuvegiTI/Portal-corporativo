import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/luvegi_colors.dart'; // Asumo que usas tu archivo de colores
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';

class PluzCortesPage extends StatefulWidget {
  const PluzCortesPage({super.key});

  @override
  State<PluzCortesPage> createState() => _PluzCortesPageState();
}

class _PluzCortesPageState extends State<PluzCortesPage> {
  late Future<List<dynamic>> _futureCortes;

  @override
  void initState() {
    super.initState();
    _futureCortes = fetchCortes();
  }

  // Función para consumir tu API en PHP
  Future<List<dynamic>> fetchCortes() async {
    // Reemplaza esta URL con la ruta real de tu servidor PHP
    final url = Uri.parse('https://portal.luvegi.com/api_luvegi/api_cortes.php');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error en el servidor al cargar los cortes.');
      }
    } catch (e) {
      throw Exception('Error de conexión: Verifica tu red o el backend.');
    }
  }

  // Permite recargar los datos al hacer "Pull to refresh"
  Future<void> _refreshData() async {
    setState(() {
      _futureCortes = fetchCortes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado interno de la página
        Padding(
          padding: const EdgeInsets.all(LuvegiSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Próximos Cortes de Energía',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: LuvegiColors.textPrimary, // Usa tu color corporativo
                ),
              ),
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Información extraída de las concesionarias (Pluz Energía / Luz del Sur)',
                style: TextStyle(
                  fontSize: 14,
                  color: LuvegiColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        
        // Listado de cortes
        Expanded(
          child: RefreshIndicator(
            color: LuvegiColors.secondary,
            onRefresh: _refreshData,
            child: FutureBuilder<List<dynamic>>(
              future: _futureCortes,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: LuvegiColors.secondary,
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: LuvegiColors.textPrimary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LuvegiColors.secondary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return ListView( // Usamos ListView para que el RefreshIndicator funcione
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Text(
                          'No hay cortes programados en este momento.',
                          style: TextStyle(fontSize: 16, color: LuvegiColors.textSecondary),
                        ),
                      ),
                    ],
                  );
                }

                final cortes = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: LuvegiSpacing.lg),
                  itemCount: cortes.length,
                  itemBuilder: (context, index) {
                    final corte = cortes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: LuvegiSpacing.md),
                      decoration: BoxDecoration(
                        color: LuvegiColors.surface,
                        borderRadius: BorderRadius.circular(LuvegiRadius.md),
                        border: Border.all(color: LuvegiColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08101828),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(LuvegiSpacing.md),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E5), // Fondo naranja claro
                            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Colors.orange, // Naranja eléctrico
                            size: 32,
                          ),
                        ),
                        title: Text(
                          corte['distrito'] ?? 'Distrito desconocido',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: LuvegiColors.textPrimary,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                corte['zonasAfectadas'] ?? '',
                                style: const TextStyle(
                                  color: LuvegiColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.redAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    corte['fecha'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}