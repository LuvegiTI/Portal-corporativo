import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';

const Color luvegiBlue = Color(0xFF003366);
const Color luvegiCyan = Colors.cyanAccent;
const Color backgroundGray = Color(0xFFF1F5F9);

class DashboardPage extends StatefulWidget {
  final String token;
  final String nombre;
  final String rol;
  final Function(String) onNavigate;

  const DashboardPage({
    super.key,
    required this.token,
    required this.nombre,
    required this.rol,
    required this.onNavigate,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _dbService = DashboardService();
  
  // Datos de estado
  String _totalBoletas = "0";
  String _totalUsuarios = "0";
  //List<dynamic> _ultimasBoletas = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  // Carga sincronizada de datos desde el backend
  Future<void> _cargarTodo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // 1. Cargar estadísticas si el rol es administrativo
      if (_esAdminORRH()) {
        final stats = await _dbService.getStats(widget.token);
        _totalBoletas = (stats['boletas'] ?? "0").toString();
        _totalUsuarios = (stats['usuarios'] ?? "0").toString();
      }

      // 2. Cargar las últimas boletas registradas para el usuario logueado
      //final boletas = await _dbService.getUltimasBoletas(widget.token);
      
      if (mounted) {
        setState(() {
       //   _ultimasBoletas = boletas;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error al sincronizar Dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _esAdminORRH() {
    final r = widget.rol.toUpperCase();
    return r == 'ADMIN' || r == 'RRHH';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: luvegiBlue));
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: backgroundGray,
      child: RefreshIndicator(
        onRefresh: _cargarTodo,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeBanner(),
              const SizedBox(height: 40),
              
              if (_esAdminORRH()) ...[
                _buildSectionTitle("Resumen del Sistema"),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _cardStats("Boletas en Sistema", _totalBoletas, Icons.description, Colors.blue),
                    _cardStats("Usuarios Registrados", _totalUsuarios, Icons.people_alt_rounded, Colors.indigo),
                  ],
                ),
                const SizedBox(height: 40),
              ],
              
              _buildSectionTitle("Accesos rápidos"),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _quickBtn("Mis Boletas", Icons.receipt_long, () => widget.onNavigate('Mis Boletas')),
                  if (widget.rol.toUpperCase() == 'ADMIN')
                    _quickBtn("Control de Accesos", Icons.manage_accounts, () => widget.onNavigate('Usuarios')),
                ],
              ),

              const SizedBox(height: 40),

             // _buildSectionTitle("Mis Boletas Recientes"),
             // const SizedBox(height: 20),
             // _buildRecentBoletasList(),
              
              const SizedBox(height: 40),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE COMPONENTES ---

  Widget _buildSectionTitle(String title) {
    return Text(title, 
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: luvegiBlue));
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [luvegiBlue, Color(0xFF00509E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: luvegiBlue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Hola, ${widget.nombre} 👋", 
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          Text(
            _esAdminORRH() 
                ? "Tienes el control total del sistema Luvegi." 
                : "Bienvenido a tu portal.", 
            style: const TextStyle(color: Colors.white70, fontSize: 16)
          ),
        ],
      ),
    );
  }

  /* Widget _buildRecentBoletasList() {
    if (_ultimasBoletas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Column(
          children: [
            Icon(Icons.folder_open, color: Colors.grey, size: 40),
            SizedBox(height: 10),
            Text("No se encontraron boletas recientes.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: _ultimasBoletas.map((b) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.picture_as_pdf, color: Colors.red),
          ),
          title: Text("Boleta de Pago - ${b['mes']} ${b['anio']}", 
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Fecha de subida: ${b['fecha'] ?? 'N/A'}"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: luvegiBlue),
          onTap: () => widget.onNavigate('Mis Boletas'),
        ),
      )).toList(),
    );
  }*/ 

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: luvegiCyan.withOpacity(0.5), width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.security_outlined, color: luvegiBlue, size: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tus datos están protegidos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: luvegiBlue)),
                const SizedBox(height: 5),
                Text("Este portal garantiza que solo tú veas tu información de forma segura.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardStats(String t, String v, IconData i, Color c) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, color: c, size: 30),
          const SizedBox(height: 15),
          Text(v, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(t, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _quickBtn(String label, IconData icon, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: luvegiBlue, size: 32),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: luvegiBlue)),
          ],
        ),
      ),
    );
  }
}