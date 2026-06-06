import 'package:flutter/material.dart';

class CategoriaItem {
  final String nombre;
  final IconData icono;
  final Color color;

  const CategoriaItem(this.nombre, this.icono, this.color);
}

const categoriasIngreso = [
  CategoriaItem('Cuota Social', Icons.people, Color(0xFF2E6DA4)),
  CategoriaItem('Donación', Icons.favorite, Color(0xFF2E9E7A)),
  CategoriaItem('Subsidio', Icons.account_balance, Color(0xFF1A3A5C)),
  CategoriaItem('Evento', Icons.celebration, Color(0xFF9B59B6)),
  CategoriaItem('Venta', Icons.sell, Color(0xFFF39C12)),
  CategoriaItem('Otros ingresos', Icons.add_circle, Color(0xFF6B7A99)),
];

const categoriasGasto = [
  CategoriaItem('Servicios', Icons.bolt, Color(0xFFE67E22)),
  CategoriaItem('Materiales escolares', Icons.menu_book, Color(0xFF2E6DA4)),
  CategoriaItem('Equipamiento', Icons.warehouse, Color(0xFF1A3A5C)),
  CategoriaItem('Mantenimiento', Icons.build, Color(0xFF7F8C8D)),
  CategoriaItem('Honorarios', Icons.point_of_sale, Color(0xFF8E44AD)),
  CategoriaItem('Eventos', Icons.celebration, Color(0xFF9B59B6)),
  CategoriaItem('Otros gastos', Icons.remove_circle, Color(0xFF6B7A99)),
];

CategoriaItem? findCategoria(String nombre, {required bool esIngreso}) {
  final lista = esIngreso ? categoriasIngreso : categoriasGasto;
  try {
    return lista.firstWhere((c) => c.nombre == nombre);
  } catch (_) {
    return null;
  }
}
