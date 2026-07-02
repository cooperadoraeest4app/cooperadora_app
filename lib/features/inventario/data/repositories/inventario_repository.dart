import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/services/log_cambio_service.dart';
import '../../domain/models/bien_inventario.dart';

class InventarioRepository {
  final _col = FirebaseFirestore.instance.collection('inventario');

  Stream<List<BienInventario>> obtenerTodos() {
    return _col
        .orderBy('fechaAlta', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => BienInventario.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<BienInventario>> obtenerActivos() {
    return _col
        .where('estado', isNotEqualTo: 'dado_de_baja')
        .orderBy('estado')
        .orderBy('fechaAlta', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => BienInventario.fromMap(d.data(), d.id)).toList());
  }

  Future<String> agregar(BienInventario bien) async {
    final anio = bien.fechaAlta.year;
    final correlativo = await _siguienteCorrelativo(anio);
    final codigo = 'INV-$anio-${correlativo.toString().padLeft(3, '0')}';
    final conCodigo = bien.copyWith(codigo: codigo);
    final ref = await _col.add(conCodigo.toMap());
    await LogCambioService().registrar(
      entidadTipo: 'inventario',
      entidadId: ref.id,
      usuarioId: bien.usuarioId,
      accion: 'creacion',
      nuevo: conCodigo.toMap(),
    );
    return ref.id;
  }

  Future<void> actualizar(BienInventario bien, String usuarioId) async {
    final snap = await _col.doc(bien.id).get();
    final anterior = snap.data();
    final actualizado = bien.copyWith(
      ultimaModificacionPor: usuarioId,
      ultimaModificacionFecha: DateTime.now(),
    );
    await _col.doc(bien.id).update(actualizado.toMap());
    await LogCambioService().registrar(
      entidadTipo: 'inventario',
      entidadId: bien.id,
      usuarioId: usuarioId,
      accion: 'modificacion',
      anterior: anterior,
      nuevo: actualizado.toMap(),
    );
  }

  Future<void> registrarBaja(
    String id,
    Map<String, dynamic> datosBaja,
    String usuarioId,
  ) async {
    final snap = await _col.doc(id).get();
    final anterior = snap.data();
    final data = {
      ...datosBaja,
      'estado': 'dado_de_baja',
      'ultimaModificacionPor': usuarioId,
      'ultimaModificacionFecha': FieldValue.serverTimestamp(),
    };
    await _col.doc(id).update(data);
    await LogCambioService().registrar(
      entidadTipo: 'inventario',
      entidadId: id,
      usuarioId: usuarioId,
      accion: 'baja',
      anterior: anterior,
      nuevo: data,
    );
  }

  Future<int> _siguienteCorrelativo(int anio) async {
    final snap = await _col
        .where('codigo', isGreaterThanOrEqualTo: 'INV-$anio-')
        .where('codigo', isLessThan: 'INV-${anio + 1}-')
        .get();
    return snap.docs.length + 1;
  }
}
