import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/categoria_repository.dart';

class CategoriaProvider extends ChangeNotifier {
  final _repo = CategoriaRepository();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  List<Map<String, dynamic>> _categorias = [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  CategoriaProvider() {
    _sub = _repo.obtenerTodas().listen(
      (lista) {
        _categorias = lista;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get categorias => _categorias;

  List<Map<String, dynamic>> obtenerActivas(String tipo) {
    return _categorias
        .where((c) => c['tipo'] == tipo && (c['activa'] as bool? ?? false))
        .toList();
  }

  Future<void> crear(Map<String, dynamic> datos) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.crear(datos);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> actualizar(String id, Map<String, dynamic> datos) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizar(id, datos);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> activarDesactivar(String id, bool activa) async {
    try {
      await _repo.activarDesactivar(id, activa);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> inicializarDatosDefault() async {
    if (!(await _repo.estaVacia())) return;
    try {
      await _repo.crearLote(_kDefaultCategorias);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  static const _kDefaultCategorias = <Map<String, dynamic>>[
    {'nombre': 'Cuota Social', 'tipo': 'ingreso', 'icono': 'people', 'color': '#2E6DA4', 'activa': true},
    {'nombre': 'Donación', 'tipo': 'ingreso', 'icono': 'favorite', 'color': '#2E9E7A', 'activa': true},
    {'nombre': 'Subsidio', 'tipo': 'ingreso', 'icono': 'account_balance', 'color': '#1A3A5C', 'activa': true},
    {'nombre': 'Evento', 'tipo': 'ingreso', 'icono': 'celebration', 'color': '#9B59B6', 'activa': true},
    {'nombre': 'Venta', 'tipo': 'ingreso', 'icono': 'sell', 'color': '#F39C12', 'activa': true},
    {'nombre': 'Otros ingresos', 'tipo': 'ingreso', 'icono': 'add_circle', 'color': '#6B7A99', 'activa': true},
    {'nombre': 'Servicios', 'tipo': 'gasto', 'icono': 'bolt', 'color': '#E67E22', 'activa': true},
    {'nombre': 'Materiales escolares', 'tipo': 'gasto', 'icono': 'menu_book', 'color': '#2E6DA4', 'activa': true},
    {'nombre': 'Equipamiento', 'tipo': 'gasto', 'icono': 'warehouse', 'color': '#1A3A5C', 'activa': true},
    {'nombre': 'Mantenimiento', 'tipo': 'gasto', 'icono': 'build', 'color': '#7F8C8D', 'activa': true},
    {'nombre': 'Honorarios', 'tipo': 'gasto', 'icono': 'point_of_sale', 'color': '#8E44AD', 'activa': true},
    {'nombre': 'Eventos', 'tipo': 'gasto', 'icono': 'celebration', 'color': '#9B59B6', 'activa': true},
    {'nombre': 'Otros gastos', 'tipo': 'gasto', 'icono': 'remove_circle', 'color': '#6B7A99', 'activa': true},
  ];
}
