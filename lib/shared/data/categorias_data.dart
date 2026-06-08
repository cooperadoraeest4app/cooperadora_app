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

// Helpers para mostrar categorías de Firestore
Color colorFromHex(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

IconData iconFromNombre(String nombre) => _kIconoMap[nombre] ?? Icons.label;

const _kIconoMap = <String, IconData>{
  'people': Icons.people,
  'favorite': Icons.favorite,
  'account_balance': Icons.account_balance,
  'celebration': Icons.celebration,
  'sell': Icons.sell,
  'add_circle': Icons.add_circle,
  'bolt': Icons.bolt,
  'menu_book': Icons.menu_book,
  'warehouse': Icons.warehouse,
  'build': Icons.build,
  'point_of_sale': Icons.point_of_sale,
  'remove_circle': Icons.remove_circle,
  'home_repair_service': Icons.home_repair_service,
  'water_drop': Icons.water_drop,
  'local_gas_station': Icons.local_gas_station,
};
