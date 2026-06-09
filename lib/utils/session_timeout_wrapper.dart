import 'dart:async';
import 'package:flutter/material.dart';

class SessionTimeoutWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTimeout;
  final Duration duration;

  const SessionTimeoutWrapper({
    super.key,
    required this.child,
    required this.onTimeout,
    this.duration = const Duration(minutes: 5), // Configurado a 5 min
  });

  @override
  State<SessionTimeoutWrapper> createState() => _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends State<SessionTimeoutWrapper> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.duration, widget.onTimeout);
  }

  // Reinicia el contador con cualquier interacción
  void _handleInteraction([_]) => _startTimer();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleInteraction,
      onPointerMove: _handleInteraction,
      onPointerUp: _handleInteraction,
      child: widget.child,
    );
  }
}