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

  // Seed con rubroId fijos (ver RubroRepository._kDefaultRubros para los IDs)
  static const _kDefaultCategorias = <Map<String, dynamic>>[
    // Recursos Propios
    {'nombre': 'Cuota Social', 'tipo': 'ingreso', 'icono': 'people', 'color': '#2E6DA4', 'activa': true, 'rubroId': 'rubro_recursos_propios', 'esPredeterminado': true},
    {'nombre': 'Bono Contribución', 'tipo': 'ingreso', 'icono': 'sell', 'color': '#27AE60', 'activa': true, 'rubroId': 'rubro_recursos_propios', 'esPredeterminado': true},
    {'nombre': 'Rifas', 'tipo': 'ingreso', 'icono': 'confirmation_number', 'color': '#9B59B6', 'activa': true, 'rubroId': 'rubro_recursos_propios', 'esPredeterminado': true},
    {'nombre': 'Festival/Evento/Quermese', 'tipo': 'ingreso', 'icono': 'celebration', 'color': '#F39C12', 'activa': true, 'rubroId': 'rubro_recursos_propios', 'esPredeterminado': true},
    {'nombre': 'Kiosco', 'tipo': 'ingreso', 'icono': 'storefront', 'color': '#E67E22', 'activa': true, 'rubroId': 'rubro_recursos_propios', 'esPredeterminado': true},
    // Recursos Oficiales
    {'nombre': 'Subsidio Municipio', 'tipo': 'ingreso', 'icono': 'account_balance', 'color': '#1A3A5C', 'activa': true, 'rubroId': 'rubro_recursos_oficiales', 'esPredeterminado': true},
    // Otros ingresos
    {'nombre': 'Otros', 'tipo': 'ingreso', 'icono': 'add_circle', 'color': '#6B7A99', 'activa': true, 'rubroId': 'rubro_otros_ingresos', 'esPredeterminado': true},
    // Gastos para el/la alumno/a
    {'nombre': 'Ropa y calzado', 'tipo': 'gasto', 'icono': 'checkroom', 'color': '#9B59B6', 'activa': true, 'rubroId': 'rubro_gastos_alumnos', 'esPredeterminado': true},
    {'nombre': 'Libros y útiles', 'tipo': 'gasto', 'icono': 'menu_book', 'color': '#2E6DA4', 'activa': true, 'rubroId': 'rubro_gastos_alumnos', 'esPredeterminado': true},
    {'nombre': 'Excursiones', 'tipo': 'gasto', 'icono': 'directions_bus', 'color': '#27AE60', 'activa': true, 'rubroId': 'rubro_gastos_alumnos', 'esPredeterminado': true},
    {'nombre': 'Golosinas y medallas', 'tipo': 'gasto', 'icono': 'star', 'color': '#F39C12', 'activa': true, 'rubroId': 'rubro_gastos_alumnos', 'esPredeterminado': true},
    // Gastos para la escuela
    {'nombre': 'Material Didáctico', 'tipo': 'gasto', 'icono': 'school', 'color': '#1A3A5C', 'activa': true, 'rubroId': 'rubro_gastos_escuela', 'esPredeterminado': true},
    {'nombre': 'Mant. y mejoras c/subsidios', 'tipo': 'gasto', 'icono': 'build', 'color': '#7F8C8D', 'activa': true, 'rubroId': 'rubro_gastos_escuela', 'esPredeterminado': true},
    {'nombre': 'Mant. y mejoras c/fondos propios', 'tipo': 'gasto', 'icono': 'home_repair_service', 'color': '#E67E22', 'activa': true, 'rubroId': 'rubro_gastos_escuela', 'esPredeterminado': true},
    {'nombre': 'Artículos de limpieza', 'tipo': 'gasto', 'icono': 'water_drop', 'color': '#2E9E7A', 'activa': true, 'rubroId': 'rubro_gastos_escuela', 'esPredeterminado': true},
    {'nombre': 'Combustible y calefacción', 'tipo': 'gasto', 'icono': 'local_gas_station', 'color': '#E74C3C', 'activa': true, 'rubroId': 'rubro_gastos_escuela', 'esPredeterminado': true},
    {'nombre': 'Librería y fotocopia', 'tipo': 'gasto', 'icono': 'print', 'color': '#6B7A99', 'activa': true, 'rubroId': 'rubro_gastos_escuela', 'esPredeterminado': true},
    {'nombre': 'Mobiliario', 'tipo': 'gasto', 'icono': 'warehouse', 'color': '#8E44AD', 'activa': true, 'rubroId': 'rubro_gastos_escuela', 'esPredeterminado': true},
    // Gastos propios de la entidad
    {'nombre': 'Organización de rifas', 'tipo': 'gasto', 'icono': 'confirmation_number', 'color': '#9B59B6', 'activa': true, 'rubroId': 'rubro_gastos_entidad', 'esPredeterminado': true},
    {'nombre': 'Organización de festivales', 'tipo': 'gasto', 'icono': 'celebration', 'color': '#F39C12', 'activa': true, 'rubroId': 'rubro_gastos_entidad', 'esPredeterminado': true},
    {'nombre': 'Kiosco (gastos)', 'tipo': 'gasto', 'icono': 'storefront', 'color': '#E67E22', 'activa': true, 'rubroId': 'rubro_gastos_entidad', 'esPredeterminado': true},
    {'nombre': 'Otros/impuestos bancarios', 'tipo': 'gasto', 'icono': 'remove_circle', 'color': '#6B7A99', 'activa': true, 'rubroId': 'rubro_gastos_entidad', 'esPredeterminado': true},
  ];
}
