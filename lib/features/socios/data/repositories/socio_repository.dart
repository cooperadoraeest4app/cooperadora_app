import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/services/log_cambio_service.dart';
import '../../domain/models/socio.dart';
import '../../domain/models/subtipo_socio.dart';
import '../../domain/models/tipo_socio.dart';

class SocioRepository {
  final _col = FirebaseFirestore.instance.collection('socios');
  final _tiposCol = FirebaseFirestore.instance.collection('tipos_socio');
  final _subtiposCol =
      FirebaseFirestore.instance.collection('subtipos_socio');

  // ── Socios ─────────────────────────────────────────────────────────────────

  Stream<List<Socio>> obtenerTodos() {
    return _col.snapshots().map((s) {
      final list = s.docs.map((d) => Socio.fromMap(d.data(), d.id)).toList()
        ..sort((a, b) => a.numeroSocio.compareTo(b.numeroSocio));
      return list;
    });
  }

  Stream<List<Socio>> obtenerActivos() {
    return _col.where('activo', isEqualTo: true).snapshots().map((s) {
      final list = s.docs.map((d) => Socio.fromMap(d.data(), d.id)).toList()
        ..sort((a, b) => a.numeroSocio.compareTo(b.numeroSocio));
      return list;
    });
  }

  Future<int> _siguienteNumeroSocio() async {
    final snap = await _col.get();
    return snap.docs.length + 1;
  }

  Future<String> agregar(Socio socio) async {
    final numeroSocio = await _siguienteNumeroSocio();
    final conNumero = socio.copyWith(numeroSocio: numeroSocio);
    final ref = await _col.add(conNumero.toMap());
    await LogCambioService().registrar(
      entidadTipo: 'socio',
      entidadId: ref.id,
      usuarioId: socio.usuarioId ?? '',
      accion: 'creacion',
      nuevo: conNumero.toMap(),
    );
    return ref.id;
  }

  Future<void> actualizar(Socio socio, String usuarioId) async {
    final snap = await _col.doc(socio.id).get();
    final anterior = snap.data();
    final actualizado = socio.copyWith(
      ultimaModificacionPor: usuarioId,
      ultimaModificacionFecha: DateTime.now(),
    );
    await _col.doc(socio.id).update(actualizado.toMap());
    await LogCambioService().registrar(
      entidadTipo: 'socio',
      entidadId: socio.id,
      usuarioId: usuarioId,
      accion: 'modificacion',
      anterior: anterior,
      nuevo: actualizado.toMap(),
    );
  }

  Future<void> activarDesactivar(String id, bool activo) =>
      _col.doc(id).update({'activo': activo});

  // ── Tipos y Subtipos ───────────────────────────────────────────────────────

  Stream<List<TipoSocio>> obtenerTipos() {
    return _tiposCol.snapshots().map((s) {
      final list = s.docs
          .map((d) => TipoSocio.fromMap(d.data(), d.id))
          .where((t) => t.activo)
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
      return list;
    });
  }

  Stream<List<SubtipoSocio>> obtenerSubtipos(String tipoSocioId) {
    return _subtiposCol
        .where('aplicaA', arrayContains: tipoSocioId)
        .snapshots()
        .map((s) {
      final list = s.docs
          .map((d) => SubtipoSocio.fromMap(d.data(), d.id))
          .where((t) => t.activo)
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
      return list;
    });
  }

  // ── Inicialización ─────────────────────────────────────────────────────────

  Future<void> inicializarDatosDefault() async {
    final snap = await _tiposCol.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // Tipos con IDs fijos para que subtipos puedan referenciarlos
    final tipos = [
      ('activo', 'Activo', true, true, true, 1),
      ('honorario', 'Honorario', false, true, false, 2),
      ('adherente', 'Adherente', false, true, true, 3),
    ];
    for (final (id, nombre, voto, voz, cuota, orden) in tipos) {
      batch.set(_tiposCol.doc(id), {
        'nombre': nombre,
        'tieneVoto': voto,
        'tieneVozConsultiva': voz,
        'requiereCuota': cuota,
        'orden': orden,
        'activo': true,
      });
    }

    // Subtipos para activo / adherente
    final generales = [
      'Padre', 'Madre', 'Familiar', 'Docente', 'Auxiliar',
      'No docente', 'Directivo', 'Alumno', 'Ex-alumno', 'Otro',
    ];
    for (int i = 0; i < generales.length; i++) {
      batch.set(_subtiposCol.doc(), {
        'nombre': generales[i],
        'aplicaA': ['activo', 'adherente'],
        'orden': i + 1,
        'activo': true,
      });
    }

    // Subtipos para honorario
    final honorarios = ['Empresa', 'Persona física', 'Organización', 'Otro'];
    for (int i = 0; i < honorarios.length; i++) {
      batch.set(_subtiposCol.doc(), {
        'nombre': honorarios[i],
        'aplicaA': ['honorario'],
        'orden': i + 1,
        'activo': true,
      });
    }

    await batch.commit();
  }
}
