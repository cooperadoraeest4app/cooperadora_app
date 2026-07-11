import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/services/log_cambio_service.dart';
import '../../domain/models/item_proyecto.dart';
import '../../domain/models/presupuesto_proyecto.dart';
import '../../domain/models/proyecto.dart';
import '../../domain/models/tipo_proyecto.dart';

class ProyectoRepository {
  final _col = FirebaseFirestore.instance.collection('proyectos');
  final _tiposCol = FirebaseFirestore.instance.collection('tipos_proyecto');

  Stream<List<Proyecto>> obtenerPorEstado(String estado) {
    return _col
        .where('estado', isEqualTo: estado)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => Proyecto.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
          return list;
        });
  }

  Future<void> agregar(Proyecto p) => _col.add(p.toMap());

  Future<void> actualizar(Proyecto p) => _col.doc(p.id).update(p.toMap());

  Future<void> eliminar(String id) => _col.doc(id).delete();

  Stream<List<TipoProyecto>> obtenerTipos() {
    return _tiposCol
        .orderBy('orden')
        .snapshots()
        .map((s) => s.docs
            .map((d) => TipoProyecto.fromMap(d.data(), d.id))
            .where((t) => t.activo)
            .toList());
  }

  // ── Items ─────────────────────────────────────────────────────────────────

  final _itemsCol = FirebaseFirestore.instance.collection('items_proyecto');

  Stream<List<ItemProyecto>> obtenerItems(String proyectoId) {
    return _itemsCol
        .where('proyectoId', isEqualTo: proyectoId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => ItemProyecto.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
          return list;
        });
  }

  Future<void> agregarItem(ItemProyecto item, String usuarioId) async {
    final itemConUid = item.copyWith(usuarioId: usuarioId);
    final ref = await _itemsCol.add(itemConUid.toMap());
    await LogCambioService().registrar(
      entidadTipo: 'item_proyecto',
      entidadId: ref.id,
      usuarioId: usuarioId,
      accion: 'creacion',
      anterior: null,
      nuevo: itemConUid.toMap(),
    );
  }

  Future<void> actualizarItem(ItemProyecto item, String usuarioId) async {
    final snap = await _itemsCol.doc(item.id).get();
    final anterior = snap.data();
    final actualizado = item.copyWith(
      ultimaModificacionPor: usuarioId,
      ultimaModificacionFecha: DateTime.now(),
    );
    await _itemsCol.doc(item.id).update(actualizado.toMap());
    await LogCambioService().registrar(
      entidadTipo: 'item_proyecto',
      entidadId: item.id,
      usuarioId: usuarioId,
      accion: 'modificacion',
      anterior: anterior,
      nuevo: actualizado.toMap(),
    );
  }

  Future<void> eliminarItem(String id, String usuarioId) async {
    final snap = await _itemsCol.doc(id).get();
    final anterior = snap.data();
    await _itemsCol.doc(id).delete();
    if (anterior != null) {
      await LogCambioService().registrar(
        entidadTipo: 'item_proyecto',
        entidadId: id,
        usuarioId: usuarioId,
        accion: 'eliminacion',
        anterior: anterior,
        nuevo: null,
      );
    }
  }

  // ── Presupuestos ──────────────────────────────────────────────────────────

  final _presupuestosCol =
      FirebaseFirestore.instance.collection('presupuestos_proyecto');

  Stream<List<PresupuestoProyecto>> obtenerPresupuestos(String proyectoId) {
    return _presupuestosCol
        .where('proyectoId', isEqualTo: proyectoId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => PresupuestoProyecto.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
          return list;
        });
  }

  Future<void> agregarPresupuesto(
      PresupuestoProyecto presupuesto, String usuarioId) async {
    final item = presupuesto.copyWith(usuarioId: usuarioId);
    final ref = await _presupuestosCol.add(item.toMap());
    await LogCambioService().registrar(
      entidadTipo: 'presupuesto_proyecto',
      entidadId: ref.id,
      usuarioId: usuarioId,
      accion: 'creacion',
      anterior: null,
      nuevo: item.toMap(),
    );
  }

  Future<void> actualizarPresupuesto(
      PresupuestoProyecto presupuesto, String usuarioId) async {
    final snap = await _presupuestosCol.doc(presupuesto.id).get();
    final anterior = snap.data();
    final actualizado = presupuesto.copyWith(
      ultimaModificacionPor: usuarioId,
      ultimaModificacionFecha: DateTime.now(),
    );
    await _presupuestosCol.doc(presupuesto.id).update(actualizado.toMap());
    await LogCambioService().registrar(
      entidadTipo: 'presupuesto_proyecto',
      entidadId: presupuesto.id,
      usuarioId: usuarioId,
      accion: 'modificacion',
      anterior: anterior,
      nuevo: actualizado.toMap(),
    );
  }

  Future<void> eliminarPresupuesto(String id, String usuarioId) async {
    final snap = await _presupuestosCol.doc(id).get();
    final anterior = snap.data();
    await _presupuestosCol.doc(id).delete();
    if (anterior != null) {
      await LogCambioService().registrar(
        entidadTipo: 'presupuesto_proyecto',
        entidadId: id,
        usuarioId: usuarioId,
        accion: 'eliminacion',
        anterior: anterior,
        nuevo: null,
      );
    }
  }

  // ── Tipos default ──────────────────────────────────────────────────────────

  Future<void> inicializarTiposDefault() async {
    final snap = await _tiposCol.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final defaults = [
      {'nombre': 'Evento', 'orden': 1, 'activo': true},
      {'nombre': 'Infraestructura', 'orden': 2, 'activo': true},
      {'nombre': 'Viaje de Estudios', 'orden': 3, 'activo': true},
      {'nombre': 'Equipamiento', 'orden': 4, 'activo': true},
      {'nombre': 'Otros', 'orden': 5, 'activo': true},
    ];
    for (final d in defaults) {
      batch.set(_tiposCol.doc(), d);
    }
    await batch.commit();
  }
}
