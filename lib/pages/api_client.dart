import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../pages/login_page.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;
  bool _logoutInProgress = false;

  Timer? _sessionTimer; // 🔐 Timer para polling

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://portal.luvegi.com/api_luvegi/',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 🔐 Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            await _forzarLogout();
          }
          return handler.next(e);
        },
      ),
    );
  }

  // =========================================================
  // 🔥 INICIAR VERIFICACIÓN AUTOMÁTICA DE SESIÓN
  // =========================================================
  void startSessionCheck() {
    _sessionTimer?.cancel();

    _sessionTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkSession(),
    );
  }

  // =========================================================
  // 🔎 LLAMADA A check_session.php
  // =========================================================
  Future<void> _checkSession() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final response = await dio.get('mis_permisos.php');

    // Si el usuario está inactivo o hay error, forzar logout
    if (response.data['ok'] != true) {
      await _forzarLogout();
    }
  } catch (e) {
    if (e is DioException && e.response?.statusCode == 400) {
      await _forzarLogout();
    }
  }
}

  // =========================================================
  // 🚨 FORZAR LOGOUT GLOBAL
  // =========================================================
  Future<void> _forzarLogout() async {
    if (_logoutInProgress) return;
    _logoutInProgress = true;

    _sessionTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );

    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text("Tu sesión ha sido cerrada."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    _logoutInProgress = false;
  }
}