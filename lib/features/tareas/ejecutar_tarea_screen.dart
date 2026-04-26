import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/models/ejecucion_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';

const _colorFondo = Color(0xFF1a1a00);
const _colorCard = Color(0xFF2e2e14);
const _colorPrimario = Color(0xFFC0C080);
const _colorTexto = Color(0xFFF5F5E8);
const _colorMuted = Color(0xFF9D9D60);
const _colorBorde = Color(0xFF565620);
const _colorError = Color(0xFFF44250);

class EjecutarTareaScreen extends StatefulWidget {
  final String ejecucionId;
  const EjecutarTareaScreen({super.key, required this.ejecucionId});

  @override
  State<EjecutarTareaScreen> createState() => _EjecutarTareaScreenState();
}

class _EjecutarTareaScreenState extends State<EjecutarTareaScreen> {
  final _api = ApiService();
  final _auth = AuthService();

  EjecucionDetallada? _tarea;
  Formulario? _formulario;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  final Map<String, dynamic> _respuesta = {};
  final Map<String, bool> _subiendoArchivo = {};
  final Map<String, String> _nombresArchivo = {};
  final _obsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final token = await _auth.getToken();
    if (token == null) return;

    setState(() { _cargando = true; _error = null; });
    try {
      _tarea = await _api.obtenerEjecucion(widget.ejecucionId, token);
      if (_tarea!.estado == 'PENDIENTE') {
        await _api.iniciarEjecucion(widget.ejecucionId, token);
      }
      _formulario = await _api.obtenerFormularioPorNodo(_tarea!.nodoId, token);
      if (_formulario != null) {
        for (final campo in _formulario!.campos) {
          _respuesta[campo.nombre] = '';
        }
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _cargando = false; });
    }
  }

  Future<void> _completar() async {
    if (!_validar()) return;
    final token = await _auth.getToken();
    if (token == null) return;

    setState(() { _guardando = true; });
    try {
      await _api.completarEjecucion(widget.ejecucionId, _respuesta, token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarea completada'), backgroundColor: Color(0xFF6BD968)));
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _guardando = false; });
    }
  }

  Future<void> _rechazar() async {
    final obs = await _mostrarDialogoRechazo();
    if (obs == null) return;
    final token = await _auth.getToken();
    if (token == null) return;

    setState(() { _guardando = true; });
    try {
      await _api.rechazarEjecucion(widget.ejecucionId, obs, token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarea rechazada'), backgroundColor: _colorError));
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _guardando = false; });
    }
  }

  bool _validar() {
    if (_formulario == null) return true;
    for (final campo in _formulario!.campos) {
      if (campo.requerido) {
        final val = _respuesta[campo.nombre];
        if (val == null || val.toString().isEmpty) {
          setState(() { _error = 'El campo "${campo.etiqueta}" es requerido'; });
          return false;
        }
      }
    }
    return true;
  }

  Future<String?> _mostrarDialogoRechazo() async {
    _obsController.clear();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colorCard,
        title: const Text('Rechazar tarea', style: TextStyle(color: _colorTexto)),
        content: TextField(
          controller: _obsController,
          maxLines: 3,
          style: const TextStyle(color: _colorTexto),
          decoration: const InputDecoration(
            hintText: 'Ingresa el motivo del rechazo (requerido)',
            hintStyle: TextStyle(color: _colorMuted),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _colorBorde)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _colorPrimario)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: _colorMuted))),
          ElevatedButton(
            onPressed: () {
              final obs = _obsController.text.trim();
              if (obs.isEmpty) return;
              Navigator.pop(ctx, obs);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _colorError),
            child: const Text('Rechazar', style: TextStyle(color: _colorTexto)),
          ),
        ],
      ),
    );
  }

  Future<void> _subirImagen(String nombreCampo) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    final token = await _auth.getToken();
    if (token == null) return;

    setState(() { _subiendoArchivo[nombreCampo] = true; });
    try {
      final url = await _api.subirArchivo(picked.path, picked.name, 'image/jpeg', token);
      setState(() {
        _respuesta[nombreCampo] = url;
        _nombresArchivo[nombreCampo] = picked.name;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al subir imagen'), backgroundColor: _colorError));
    } finally {
      setState(() { _subiendoArchivo[nombreCampo] = false; });
    }
  }

  Future<void> _subirArchivo(String nombreCampo) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    final token = await _auth.getToken();
    if (token == null) return;

    setState(() { _subiendoArchivo[nombreCampo] = true; });
    try {
      final url = await _api.subirArchivo(file.path!, file.name, 'application/octet-stream', token);
      setState(() {
        _respuesta[nombreCampo] = url;
        _nombresArchivo[nombreCampo] = file.name;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al subir archivo'), backgroundColor: _colorError));
    } finally {
      setState(() { _subiendoArchivo[nombreCampo] = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: AppBar(
        backgroundColor: _colorCard,
        title: Text(_tarea?.nodoNombre ?? 'Ejecutar Tarea',
            style: const TextStyle(color: _colorTexto)),
        iconTheme: const IconThemeData(color: _colorPrimario),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _colorPrimario))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera del trámite
                if (_tarea != null) _buildCabecera(),
                const SizedBox(height: 20),

                // Error
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _colorError.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _colorError.withOpacity(0.3)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: _colorError, fontSize: 13)),
                  ),

                // Formulario
                if (_formulario != null) ...[
                  Text(_formulario!.nombre,
                      style: const TextStyle(color: _colorPrimario, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  ..._formulario!.campos.map(_buildCampo),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _colorCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _colorBorde),
                    ),
                    child: const Text(
                      'Esta tarea no requiere formulario.\nPuedes completarla directamente.',
                      style: TextStyle(color: _colorMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        _buildAcciones(),
      ],
    );
  }

  Widget _buildCabecera() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _colorCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _colorBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_tarea!.tramiteTitulo ?? '', style: const TextStyle(color: _colorTexto, fontWeight: FontWeight.bold, fontSize: 15)),
          if (_tarea!.nombrePolitica != null)
            Text(_tarea!.nombrePolitica!, style: const TextStyle(color: _colorMuted, fontSize: 12)),
          if (_tarea!.departamentoNombre != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.business, size: 12, color: _colorMuted),
              const SizedBox(width: 4),
              Text(_tarea!.departamentoNombre!, style: const TextStyle(color: _colorMuted, fontSize: 12)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildCampo(FormularioCampo campo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(campo.etiqueta, style: const TextStyle(color: _colorPrimario, fontSize: 12, fontWeight: FontWeight.w600)),
            if (campo.requerido) const Text(' *', style: TextStyle(color: _colorError)),
          ]),
          const SizedBox(height: 6),
          _buildInputPorTipo(campo),
        ],
      ),
    );
  }

  Widget _buildInputPorTipo(FormularioCampo campo) {
    switch (campo.tipo) {
      case 'SELECCION':
        return DropdownButtonFormField<String>(
          value: (_respuesta[campo.nombre] as String?)?.isEmpty == true ? null : _respuesta[campo.nombre] as String?,
          dropdownColor: _colorCard,
          style: const TextStyle(color: _colorTexto),
          decoration: _inputDecoration(),
          hint: const Text('Selecciona una opción', style: TextStyle(color: _colorMuted)),
          items: campo.opciones.map((op) =>
            DropdownMenuItem(value: op, child: Text(op))).toList(),
          onChanged: (v) => setState(() => _respuesta[campo.nombre] = v ?? ''),
        );

      case 'NUMERO':
        return TextFormField(
          keyboardType: TextInputType.number,
          style: const TextStyle(color: _colorTexto),
          decoration: _inputDecoration(),
          onChanged: (v) => _respuesta[campo.nombre] = v,
        );

      case 'FECHA':
        return GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _colorPrimario)),
                child: child!,
              ),
            );
            if (date != null) {
              setState(() {
                _respuesta[campo.nombre] = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: _colorBorde),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 16, color: _colorMuted),
              const SizedBox(width: 8),
              Text(
                (_respuesta[campo.nombre] as String?)?.isNotEmpty == true
                    ? _respuesta[campo.nombre] as String
                    : 'Seleccionar fecha',
                style: TextStyle(
                  color: (_respuesta[campo.nombre] as String?)?.isNotEmpty == true ? _colorTexto : _colorMuted,
                ),
              ),
            ]),
          ),
        );

      case 'IMAGEN':
        return _buildUploadArea(campo.nombre, esImagen: true);

      case 'ARCHIVO':
        return _buildUploadArea(campo.nombre, esImagen: false);

      default: // TEXTO
        return TextFormField(
          style: const TextStyle(color: _colorTexto),
          decoration: _inputDecoration(),
          onChanged: (v) => _respuesta[campo.nombre] = v,
        );
    }
  }

  Widget _buildUploadArea(String nombreCampo, {required bool esImagen}) {
    final subiendo = _subiendoArchivo[nombreCampo] == true;
    final nombre = _nombresArchivo[nombreCampo];
    final tieneArchivo = nombre != null;

    return GestureDetector(
      onTap: subiendo ? null : () => esImagen ? _subirImagen(nombreCampo) : _subirArchivo(nombreCampo),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: tieneArchivo ? const Color(0xFF6BD968) : _colorBorde,
            style: BorderStyle.solid,
            width: tieneArchivo ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: _colorCard,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (subiendo) ...[
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _colorPrimario)),
              const SizedBox(width: 8),
              const Text('Subiendo...', style: TextStyle(color: _colorMuted)),
            ] else if (tieneArchivo) ...[
              const Icon(Icons.check_circle, color: Color(0xFF6BD968), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(nombre, style: const TextStyle(color: Color(0xFF6BD968), fontSize: 12), overflow: TextOverflow.ellipsis)),
            ] else ...[
              Icon(esImagen ? Icons.photo : Icons.attach_file, color: _colorMuted, size: 18),
              const SizedBox(width: 8),
              Text(esImagen ? 'Seleccionar imagen' : 'Seleccionar archivo',
                  style: const TextStyle(color: _colorMuted, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: _colorCard,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _colorBorde)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _colorPrimario)),
      hintStyle: const TextStyle(color: _colorMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildAcciones() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: _colorCard,
        border: Border(top: BorderSide(color: _colorBorde)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _guardando ? null : _rechazar,
              style: OutlinedButton.styleFrom(
                foregroundColor: _colorError,
                side: const BorderSide(color: _colorError),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Rechazar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _guardando ? null : _completar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorPrimario,
                foregroundColor: _colorFondo,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _guardando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _colorFondo))
                  : const Text('Completar tarea', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
