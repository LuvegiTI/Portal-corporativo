import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/admin_usuarios_service.dart';
import '../models/usuario.dart';

class AdminUsuariosModel extends ChangeNotifier {
  final AdminUsuariosService _service;

  AdminUsuariosModel(this._service);

  List<Usuario> usuarios = [];
  bool loading = false;
  bool loadingMore = false;
  int page = 1;
  int perPage = 20;
  int total = 0;
  bool hasMore = true;
  String query = '';

  Timer? _debounce;

  Future<void> init(String token, {int perPage = 20}) async {
    this.perPage = perPage;
    await load(token);
  }

  void setQuery(String q, String token) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      query = q;
      await load(token);
    });
  }

  Future<void> load(String token) async {
    loading = true;
    page = 1;
    hasMore = true;
    notifyListeners();

    final res = await _service.listarPaged(token, page: page, perPage: perPage, q: query);
    final list = List<Map<String, dynamic>>.from(res['usuarios'] ?? []);
    total = res['total'] ?? list.length;
    usuarios = list.map((m) => Usuario.fromMap(m)).toList();
    hasMore = usuarios.length < total;

    loading = false;
    notifyListeners();
  }

  Future<void> loadMore(String token) async {
    if (!hasMore || loadingMore) return;
    loadingMore = true;
    page += 1;
    notifyListeners();

    final res = await _service.listarPaged(token, page: page, perPage: perPage, q: query);
    final list = List<Map<String, dynamic>>.from(res['usuarios'] ?? []);
    final more = list.map((m) => Usuario.fromMap(m)).toList();
    usuarios.addAll(more);
    total = res['total'] ?? total;
    hasMore = usuarios.length < total;

    loadingMore = false;
    notifyListeners();
  }

  Future<bool> crear(String token, String usuario, String nombre, String password, String rol) async {
    final ok = await _service.crear(token, usuario, nombre, password, rol);
    if (ok) await load(token);
    return ok;
  }

  Future<bool> cambiarRol(String token, int id, String rol) async {
    // Optimistic: update local list immediately, rollback on failure
    final idx = usuarios.indexWhere((u) => u.id == id);
    if (idx == -1) return false;
    final old = usuarios[idx];
    usuarios[idx] = Usuario(id: old.id, email: old.email, nombre: old.nombre, rol: rol, activo: old.activo);
    notifyListeners();

    try {
      final ok = await _service.cambiarRol(token, id, rol);
      if (ok) {
        await load(token);
        return true;
      } else {
        // rollback
        usuarios[idx] = old;
        notifyListeners();
        return false;
      }
    } catch (_) {
      usuarios[idx] = old;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String token, int id, String password) async {
    final ok = await _service.resetPassword(token, id, password);
    return ok;
  }

  Future<bool> toggle(String token, int id) async {
    final idx = usuarios.indexWhere((u) => u.id == id);
    if (idx == -1) return false;
    final old = usuarios[idx];
    // optimistic toggle
    usuarios[idx] = Usuario(id: old.id, email: old.email, nombre: old.nombre, rol: old.rol, activo: !old.activo);
    notifyListeners();

    try {
      final ok = await _service.toggle(token, id);
      if (ok) {
        await load(token);
        return true;
      } else {
        // rollback
        usuarios[idx] = old;
        notifyListeners();
        return false;
      }
    } catch (_) {
      usuarios[idx] = old;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
