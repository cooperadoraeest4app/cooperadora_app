import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../home/presentation/screens/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../providers/invitacion_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class InvitacionesScreen extends StatelessWidget {
  const InvitacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitacionProvider>();

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(width: 1, height: 20, color: Colors.white.withOpacity(0.3)),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: Icon(Icons.home, color: Colors.white.withOpacity(0.8), size: 20),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                ),
              ),
            ),
            Container(width: 1, height: 20, color: Colors.white.withOpacity(0.3)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Invitaciones',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [AccionAuthWidget()],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: provider.invitaciones,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final invitaciones = snap.data ?? [];
          if (invitaciones.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invitaciones.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _InvitacionCard(
              invitacion: invitaciones[index],
              provider: provider,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.verdeTeal,
        foregroundColor: AppTheme.blanco,
        onPressed: () => _mostrarCrearSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _mostrarCrearSheet(BuildContext screenContext) {
    showModalBottomSheet(
      context: screenContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: _CrearInvitacionSheet(
          onCreada: (codigo) {
            Navigator.of(sheetCtx).pop();
            _mostrarCodigoDialog(screenContext, codigo);
          },
        ),
      ),
    );
  }

  void _mostrarCodigoDialog(BuildContext context, String codigo) {
    showDialog(
      context: context,
      builder: (_) => _CodigoDialog(codigo: codigo),
    );
  }
}

// ─── Card de invitación ─────────────────────────────────────────────────────

class _InvitacionCard extends StatelessWidget {
  const _InvitacionCard({required this.invitacion, required this.provider});

  final Map<String, dynamic> invitacion;
  final InvitacionProvider provider;

  @override
  Widget build(BuildContext context) {
    final id = invitacion['id'] as String? ?? '';
    final codigo = invitacion['codigo'] as String? ?? '—';
    final tipo = invitacion['tipo'] as String? ?? 'individual';
    final rol = invitacion['rolAsignado'] as String? ?? '';
    final nombreDestino = invitacion['nombreDestino'] as String?;
    final apellidoDestino = invitacion['apellidoDestino'] as String?;
    final emailDestino = invitacion['emailDestino'] as String?;
    final usada = invitacion['usada'] as bool? ?? false;
    final usos = invitacion['usos'] as int? ?? 0;
    final limiteUsos = invitacion['limiteUsos'] as int?;
    final fechaVenc = invitacion['fechaVencimiento'];
    final esSocio = invitacion['esSocio'] as bool? ?? false;
    final tipoSocioCard = invitacion['tipoSocio'] as String?;

    String tipoSocioLabel(String t) => switch (t) {
      'activo' => 'activo',
      'adherente' => 'adherente',
      'honorario' => 'honorario',
      _ => t,
    };

    final nombreCompleto = [nombreDestino, apellidoDestino]
        .where((s) => s?.isNotEmpty ?? false)
        .join(' ');

    String? fechaVencStr;
    bool vencida = false;
    if (fechaVenc is Timestamp) {
      final dt = fechaVenc.toDate();
      fechaVencStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      vencida = dt.isBefore(DateTime.now());
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TipoChip(tipo: tipo),
                const SizedBox(width: 8),
                _RolChip(rol: rol),
                if (esSocio) ...[
                  const SizedBox(width: 8),
                  _TagSmall(
                    label: tipoSocioCard != null
                        ? 'Socio ${tipoSocioLabel(tipoSocioCard)}'
                        : 'Socio',
                    color: AppTheme.verdeTeal,
                  ),
                ],
                if (usada && tipo == 'individual') ...[
                  const SizedBox(width: 8),
                  _TagSmall(
                    label: 'Usada',
                    color: AppTheme.textoSecundario,
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.rojoGasto),
                  tooltip: 'Eliminar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmarEliminar(context, id),
                ),
              ],
            ),
            if (nombreCompleto.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                nombreCompleto,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textoPrincipal,
                ),
              ),
            ],
            if (emailDestino?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                emailDestino!,
                style: const TextStyle(
                    color: AppTheme.textoSecundario, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.celesteFondo,
                    borderRadius:
                        const BorderRadius.all(Radius.circular(6)),
                    border: Border.all(color: AppTheme.celesteBorde),
                  ),
                  child: Text(
                    codigo,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: AppTheme.azulOscuro,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy,
                      size: 18, color: AppTheme.azulMedio),
                  tooltip: 'Copiar código',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codigo));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Código copiado al portapapeles')),
                    );
                  },
                ),
              ],
            ),
            if (tipo == 'generica') ...[
              const SizedBox(height: 6),
              Text(
                limiteUsos != null
                    ? '$usos usos / límite $limiteUsos'
                    : '$usos usos',
                style: const TextStyle(
                    color: AppTheme.textoSecundario, fontSize: 13),
              ),
            ],
            if (fechaVencStr != null) ...[
              const SizedBox(height: 4),
              Text(
                'Vence: $fechaVencStr',
                style: TextStyle(
                  color:
                      vencida ? AppTheme.rojoGasto : AppTheme.textoSecundario,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar invitación'),
        content: const Text(
            '¿Eliminar esta invitación? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.rojoGasto),
            onPressed: () {
              Navigator.pop(context);
              provider.eliminar(id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ─── Chips y etiquetas ───────────────────────────────────────────────────────

class _TipoChip extends StatelessWidget {
  const _TipoChip({required this.tipo});
  final String tipo;

  @override
  Widget build(BuildContext context) {
    final esIndividual = tipo == 'individual';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: esIndividual ? AppTheme.azulMedio : const Color(0xFFFFE0B2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        esIndividual ? 'Individual' : 'Genérica',
        style: TextStyle(
          color: esIndividual ? AppTheme.blanco : const Color(0xFFE65100),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RolChip extends StatelessWidget {
  const _RolChip({required this.rol});
  final String rol;

  static (Color bg, Color fg) _colores(String rol) => switch (rol) {
        'admin' => (AppTheme.azulOscuro, AppTheme.blanco),
        'editor' => (AppTheme.verdeTeal, AppTheme.blanco),
        'solo_lectura' =>
          (const Color(0xFFE0E0E0), AppTheme.textoSecundario),
        'consultante' => (const Color(0xFFFFE0B2), const Color(0xFFE65100)),
        _ => (const Color(0xFFE0E0E0), AppTheme.textoSecundario),
      };

  static String _label(String rol) => switch (rol) {
        'admin' => 'Admin',
        'editor' => 'Editor',
        'solo_lectura' => 'Solo lectura',
        'consultante' => 'Consultante',
        _ => rol,
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colores(rol);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        _label(rol),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TagSmall extends StatelessWidget {
  const _TagSmall({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─── Bottom sheet: crear invitación ─────────────────────────────────────────

class _CrearInvitacionSheet extends StatefulWidget {
  const _CrearInvitacionSheet({required this.onCreada});
  final ValueChanged<String> onCreada;

  @override
  State<_CrearInvitacionSheet> createState() => _CrearInvitacionSheetState();
}

class _CrearInvitacionSheetState extends State<_CrearInvitacionSheet> {
  final _formKey = GlobalKey<FormState>();
  String _tipo = 'individual';
  String _rol = 'consultante';
  bool _esSocio = false;
  String? _tipoSocio;

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _limiteUsosCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  DateTime? _fechaVencimiento;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _limiteUsosCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InvitacionProvider>();
    try {
      final codigo = await provider.crearInvitacion(
        tipo: _tipo,
        rolAsignado: _rol,
        emailDestino: _tipo == 'individual' ? _emailCtrl.text.trim() : null,
        nombreDestino: _tipo == 'individual' ? _nombreCtrl.text.trim() : null,
        apellidoDestino:
            _tipo == 'individual' ? _apellidoCtrl.text.trim() : null,
        telefonoDestino:
            _tipo == 'individual' ? _telefonoCtrl.text.trim() : null,
        limiteUsos: _tipo == 'generica' && _limiteUsosCtrl.text.isNotEmpty
            ? int.tryParse(_limiteUsosCtrl.text)
            : null,
        fechaVencimiento: _fechaVencimiento,
        esSocio: _esSocio,
        tipoSocio: _esSocio ? _tipoSocio : null,
      );
      widget.onCreada(codigo);
    } catch (_) {
      if (!mounted) return;
      final msg = context.read<InvitacionProvider>().error ??
          'Error al crear la invitación';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.rojoGasto,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitacionProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            const Text(
              'Nueva invitación',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textoPrincipal,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTipoBtn('individual', 'Individual')),
                const SizedBox(width: 8),
                Expanded(child: _buildTipoBtn('generica', 'Genérica')),
              ],
            ),
            const SizedBox(height: 16),
            if (_tipo == 'individual') ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nombreCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Nombre'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _apellidoCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Apellido'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El email es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)'),
              ),
              const SizedBox(height: 12),
            ] else ...[
              TextFormField(
                controller: _limiteUsosCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Límite de usos (opcional)',
                  helperText: 'Dejá vacío para usos ilimitados',
                ),
              ),
              const SizedBox(height: 12),
            ],
            Builder(builder: (context) {
              final esAdmin = context.read<AuthProvider>().esAdmin;
              return DropdownButtonFormField<String>(
                value: _rol,
                decoration: const InputDecoration(labelText: 'Rol asignado'),
                items: [
                  if (esAdmin) ...[
                    const DropdownMenuItem(value: 'editor', child: Text('Editor')),
                    const DropdownMenuItem(value: 'auditor', child: Text('Auditor')),
                  ],
                  const DropdownMenuItem(value: 'consultante', child: Text('Consultante')),
                  const DropdownMenuItem(value: 'solo_lectura', child: Text('Solo lectura')),
                ],
                onChanged: (v) => setState(() => _rol = v!),
              );
            }),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Registrar como socio', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Se creará el registro de socio al aceptar la invitación',
                style: TextStyle(fontSize: 12),
              ),
              value: _esSocio,
              onChanged: (v) => setState(() {
                _esSocio = v;
                if (!v) _tipoSocio = null;
              }),
            ),
            if (_esSocio) ...[
              DropdownButtonFormField<String>(
                value: _tipoSocio,
                decoration: const InputDecoration(labelText: 'Tipo de socio *'),
                items: [
                  DropdownMenuItem(
                    value: 'activo',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Activo'),
                        Text('Voz y voto', style: TextStyle(fontSize: 11, color: Color(0xFF757575))),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'adherente',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Adherente'),
                        Text('Solo voz', style: TextStyle(fontSize: 11, color: Color(0xFF757575))),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'honorario',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Honorario'),
                        Text('Solo voz mediante delegado', style: TextStyle(fontSize: 11, color: Color(0xFF757575))),
                      ],
                    ),
                  ),
                ],
                selectedItemBuilder: (context) => const [
                  Text('Activo'),
                  Text('Adherente'),
                  Text('Honorario'),
                ],
                onChanged: (v) => setState(() => _tipoSocio = v),
                validator: (v) => _esSocio && v == null ? 'Seleccioná un tipo de socio' : null,
              ),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _fechaCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Fecha de vencimiento (opcional)',
                suffixIcon: _fechaVencimiento != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _fechaVencimiento = null;
                          _fechaCtrl.clear();
                        }),
                      )
                    : const Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now()
                      .add(const Duration(days: 365 * 2)),
                );
                if (fecha != null) {
                  setState(() {
                    _fechaVencimiento = fecha;
                    _fechaCtrl.text =
                        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.verdeTeal,
                foregroundColor: AppTheme.blanco,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              onPressed: provider.isSaving ? null : _guardar,
              child: provider.isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.blanco,
                      ),
                    )
                  : const Text(
                      'Crear invitación',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoBtn(String valor, String label) {
    final seleccionado = _tipo == valor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: seleccionado ? AppTheme.azulOscuro : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: AppTheme.azulOscuro),
      ),
      child: InkWell(
        onTap: () => setState(() => _tipo = valor),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: seleccionado ? AppTheme.blanco : AppTheme.azulOscuro,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dialog: código generado ─────────────────────────────────────────────────

class _CodigoDialog extends StatelessWidget {
  const _CodigoDialog({required this.codigo});
  final String codigo;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¡Invitación creada!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Compartí este código con el destinatario:',
            style: TextStyle(color: AppTheme.textoSecundario),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.celesteFondo,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(color: AppTheme.celesteBorde),
            ),
            child: Column(
              children: [
                Text(
                  codigo,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                    color: AppTheme.azulOscuro,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codigo));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Código copiado al portapapeles'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar código'),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}

// ─── Estado vacío ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mail_outline,
            size: 64,
            color: AppTheme.textoSecundario.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay invitaciones creadas',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.textoSecundario),
          ),
          const SizedBox(height: 8),
          Text(
            'Presioná + para crear una nueva',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textoSecundario),
          ),
        ],
      ),
    );
  }
}
