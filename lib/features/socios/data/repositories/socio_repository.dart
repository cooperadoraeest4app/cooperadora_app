import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/integrante.dart';
import '../../domain/models/socio.dart';
import '../../domain/models/subtipo_socio.dart';
import '../../domain/models/tipo_socio.dart';

class SocioRepository {
  final _col = FirebaseFirestore.instance.collection('socios');
  final _integrantesCol =
      FirebaseFirestore.instance.collection('integrantes');
  final _tiposCol =
      FirebaseFirestore.instance.collection('tipos_socio');
  final _subtiposCol =
      FirebaseFirestore.instance.collection('subtipos_socio');

  // ── Socios ─────────────────────────────────────────────────────────────────

  Stream<List<Socio>> obtenerTodos() {
    return _col.snapshots().map((s) {
      final list =
          s.docs.map((d) => Socio.fromMap(d.data(), d.id)).toList()
            ..sort((a, b) =>
                a.nombreDisplay.compareTo(b.nombreDisplay));
      return list;
    });
  }

  Stream<List<Socio>> obtenerActivos() {
    return _col.where('activo', isEqualTo: true).snapshots().map((s) {
      final list =
          s.docs.map((d) => Socio.fromMap(d.data(), d.id)).toList()
            ..sort((a, b) =>
                a.nombreDisplay.compareTo(b.nombreDisplay));
      return list;
    });
  }

  Future<void> agregar(Socio socio) => _col.add(socio.toMap());

  Future<void> actualizar(Socio socio) =>
      _col.doc(socio.id).update(socio.toMap());

  Future<void> activarDesactivar(String id, bool activo) =>
      _col.doc(id).update({'activo': activo});

  // ── Integrantes ────────────────────────────────────────────────────────────

  Stream<List<Integrante>> obtenerIntegrantes(String socioId) {
    return _integrantesCol
        .where('socioId', isEqualTo: socioId)
        .snapshots()
        .map((s) {
      final list = s.docs
          .map((d) => Integrante.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre));
      return list;
    });
  }

  Future<void> agregarIntegrante(Integrante integrante) =>
      _integrantesCol.add(integrante.toMap());

  Future<void> eliminarIntegrante(String id) =>
      _integrantesCol.doc(id).delete();

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
      ('consultante', 'Consultante', false, true, false, 4),
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

    // Subtipos para activo / adherente / consultante
    final generales = [
      'Padre', 'Madre', 'Familiar', 'Docente', 'Auxiliar',
      'No docente', 'Directivo', 'Alumno', 'Ex-alumno', 'Otro',
    ];
    for (int i = 0; i < generales.length; i++) {
      batch.set(_subtiposCol.doc(), {
        'nombre': generales[i],
        'aplicaA': ['activo', 'adherente', 'consultante'],
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
