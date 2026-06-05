import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

const _metodosPago = [
  'Efectivo',
  'Transferencia',
  'Débito',
  'Crédito',
  'Cheque',
];

const _categoriasIngreso = [
  'Cuota',
  'Donación',
  'Evento',
  'Rifas',
  'Subsidio',
  'Otros',
];

const _categoriasGasto = [
  'Útiles',
  'Mantenimiento',
  'Servicios',
  'Personal',
  'Eventos',
  'Otros',
];

class AgregarMovimientoScreen extends StatefulWidget {
  const AgregarMovimientoScreen({super.key});

  @override
  State<AgregarMovimientoScreen> createState() =>
      _AgregarMovimientoScreenState();
}

class _AgregarMovimientoScreenState extends State<AgregarMovimientoScreen> {
  final _formKey = GlobalKey<FormState>();

  String _tipo = 'ingreso';
  DateTime _fecha = DateTime.now();
  String? _metodoPago;
  String? _categoria;
  bool _esMiembro = false;
  String? _socioSeleccionado;
  String? _nombreComprobante;

  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _fechaController = TextEditingController();
  final _donanteController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fechaController.text = _formatFecha(DateTime.now());
  }

  @override
  void dispose() {
    _montoController.dispose();
    _descripcionController.dispose();
    _fechaController.dispose();
    _donanteController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  bool get _esIngreso => _tipo == 'ingreso';

  Color get _colorActivo =>
      _esIngreso ? AppTheme.verdeIngreso : AppTheme.rojoGasto;

  List<String> get _categorias =>
      _esIngreso ? _categoriasIngreso : _categoriasGasto;

  String _formatFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  void _cambiarTipo(String tipo) {
    if (_tipo == tipo) return;
    setState(() {
      _tipo = tipo;
      _categoria = null;
    });
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _fecha = picked;
        _fechaController.text = _formatFecha(picked);
      });
    }
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Movimiento guardado (próximamente conectado a Firestore)'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _colorActivo,
        foregroundColor: AppTheme.blanco,
        iconTheme: const IconThemeData(color: AppTheme.blanco),
        titleTextStyle: const TextStyle(
          color: AppTheme.blanco,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: Text(_esIngreso ? 'Nuevo Ingreso' : 'Nuevo Gasto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSelectorTipo(),
              const SizedBox(height: 16),
              _buildFormCard(),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorActivo,
                  foregroundColor: AppTheme.blanco,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                onPressed: _guardar,
                child: Text(
                  _esIngreso ? 'Guardar Ingreso' : 'Guardar Gasto',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorTipo() {
    return Row(
      children: [
        Expanded(
          child: _BotonTipo(
            label: 'Ingreso',
            icono: Icons.arrow_downward,
            activo: _esIngreso,
            color: AppTheme.verdeIngreso,
            onTap: () => _cambiarTipo('ingreso'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BotonTipo(
            label: 'Gasto',
            icono: Icons.arrow_upward,
            activo: !_esIngreso,
            color: AppTheme.rojoGasto,
            onTap: () => _cambiarTipo('gasto'),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _montoController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: '\$ ',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresá el monto';
                final parsed = double.tryParse(v);
                if (parsed == null || parsed <= 0) {
                  return 'Ingresá un monto válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fechaController,
              readOnly: true,
              onTap: _seleccionarFecha,
              decoration: const InputDecoration(
                labelText: 'Fecha',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _metodoPago,
              decoration:
                  const InputDecoration(labelText: 'Método de pago'),
              items: _metodosPago
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _metodoPago = v),
              validator: (v) =>
                  v == null ? 'Seleccioná un método de pago' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_tipo),
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _categorias
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _categoria = v),
              validator: (v) =>
                  v == null ? 'Seleccioná una categoría' : null,
            ),
            if (_esIngreso) ..._buildCamposIngreso(),
            _buildComprobante(),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarFoto() async {
    final result =
        await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _nombreComprobante = result.files.first.name);
    }
  }

  Future<void> _adjuntarArchivo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _nombreComprobante = result.files.first.name);
    }
  }

  Widget _buildComprobante() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Comprobante (opcional)',
          style: TextStyle(
            color: AppTheme.textoSecundario,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        if (_nombreComprobante != null) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _colorActivo.withAlpha(25),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(color: _colorActivo.withAlpha(80)),
            ),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined,
                    size: 18, color: _colorActivo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nombreComprobante!,
                    style:
                        TextStyle(color: _colorActivo, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _nombreComprobante = null),
                  child: const Icon(Icons.close,
                      size: 18, color: AppTheme.textoSecundario),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _colorActivo,
                  side: BorderSide(color: _colorActivo),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _seleccionarFoto,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Sacar foto'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _colorActivo,
                  side: BorderSide(color: _colorActivo),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _adjuntarArchivo,
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Adjuntar archivo'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildCamposIngreso() {
    return [
      const SizedBox(height: 8),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
            '¿El donante es miembro de la Cooperadora?'),
        value: _esMiembro,
        activeColor: AppTheme.verdeIngreso,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (v) => setState(() {
          _esMiembro = v ?? false;
          _socioSeleccionado = null;
          _donanteController.clear();
          _emailController.clear();
          _telefonoController.clear();
        }),
      ),
      if (_esMiembro) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _socioSeleccionado,
          decoration: const InputDecoration(labelText: 'Miembro'),
          items: const [
            DropdownMenuItem(value: 'yo', child: Text('Soy yo')),
            DropdownMenuItem(
                value: 'otro', child: Text('Otro miembro')),
          ],
          onChanged: (v) => setState(() => _socioSeleccionado = v),
        ),
      ] else ...[
        const SizedBox(height: 16),
        TextFormField(
          controller: _donanteController,
          decoration:
              const InputDecoration(labelText: 'Nombre donante'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration:
              const InputDecoration(labelText: 'Email donante'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _telefonoController,
          keyboardType: TextInputType.phone,
          decoration:
              const InputDecoration(labelText: 'Teléfono donante'),
        ),
      ],
    ];
  }
}

class _BotonTipo extends StatelessWidget {
  const _BotonTipo({
    required this.label,
    required this.icono,
    required this.activo,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icono;
  final bool activo;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: activo ? color : AppTheme.blanco,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              color: activo ? AppTheme.blanco : color,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: activo ? AppTheme.blanco : color,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
