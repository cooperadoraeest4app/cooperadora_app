import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Dado el nombre de un método de pago, retorna el ícono y color asociados.
class MetodoPagoIcon {
  const MetodoPagoIcon._();

  static IconData iconOf(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('efectivo')) return Icons.payments;
    if (n.contains('transfer')) return Icons.swap_horiz;
    if (n.contains('débit') || n.contains('debit')) return Icons.credit_card;
    if (n.contains('crédit') || n.contains('credit')) return Icons.credit_score;
    if (n.contains('cheque')) return Icons.description;
    return Icons.payment;
  }

  static Color colorOf(String nombre) => AppTheme.azulMedio;
}

/// Widget para mostrar en `items` y `selectedItemBuilder` de un dropdown.
class MetodoPagoRow extends StatelessWidget {
  const MetodoPagoRow({super.key, required this.nombre});
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final icon = MetodoPagoIcon.iconOf(nombre);
    final color = MetodoPagoIcon.colorOf(nombre);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(nombre, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
