import 'package:flutter/material.dart';

/// Mantiene vivos los controladores de un dialogo hasta que la ruta termina
/// de desmontarse. Disponerlos justo despues de `await showDialog` provoca
/// el assert `_dependents.isEmpty` porque los TextField aun estan montados
/// durante la animacion de salida.
class DialogControllers extends StatefulWidget {
  final List<TextEditingController> controllers;
  final Widget Function(BuildContext, StateSetter) builder;

  const DialogControllers({
    super.key,
    required this.controllers,
    required this.builder,
  });

  @override
  State<DialogControllers> createState() => _DialogControllersState();
}

class _DialogControllersState extends State<DialogControllers> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, setState);
}
