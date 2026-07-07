import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NumeroChequeWidget extends StatelessWidget {
  final String? metodoPago;
  final TextEditingController controller;

  const NumeroChequeWidget({
    super.key,
    required this.metodoPago,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (metodoPago?.toLowerCase().contains('cheque') != true) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Número de cheque',
          hintText: 'Ej: 12345678',
          prefixIcon: Icon(Icons.numbers),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) => (v == null || v.trim().isEmpty)
            ? 'El número de cheque es obligatorio'
            : null,
      ),
    );
  }
}
