import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/services/auth_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/constants/api_url.dart';
import '../services/agente_service.dart';

// Colores de la app
const _colorFondo = Color(0xFF1a1a00);
const _colorCard = Color(0xFF2e2e14);
const _colorPrimario = Color(0xFFC0C080);
const _colorTexto = Color(0xFFF5F5E8);
const _colorMuted = Color(0xFF9D9D60);
const _colorBorde = Color(0xFF565620);
const _colorAgente = Color(0xFF3a3a20);
const _colorCliente = Color(0xFF4a5a1a);

class MensajeUI {
  final String rol; // 'agente' | 'cliente'
  final String contenido;
  final String tipo;
  final DateTime timestamp;

  MensajeUI({
    required this.rol,
    required this.contenido,
    required this.tipo,
    required this.timestamp,
  });
}

class ChatAgenteScreen extends StatefulWidget {
  const ChatAgenteScreen({super.key});

  @override
  State<ChatAgenteScreen> createState() => _ChatAgenteScreenState();
}

class _ChatAgenteScreenState extends State<ChatAgenteScreen> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _agenteApi = AgenteApiService();
  final _auth = AuthService();
  final _speech = stt.SpeechToText();

  String? _conversacionId;
  String _estadoConversacion = 'DETECTANDO_POLITICA';
  final List<MensajeUI> _mensajes = [];
  bool _procesando = false;
  bool _escuchandoVoz = false;
  bool _vozDisponible = false;
  String? _estadoBadge;
  String _clienteId = '';
  String? _token;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    final user = await _auth.getUser();
    _token = await _auth.getToken();
    setState(() {
      _clienteId = user?['id'] ?? 'anonimo';
    });

    // Verificar disponibilidad de voz
    _vozDisponible = await _speech.initialize(
      onError: (e) => debugPrint('[ChatAgente] Error voz: $e'),
    );

    _agregarMensajeAgente(
      'Hola! Soy el asistente de CRE. Puedo ayudarte a iniciar un tramite '
      'o consultar el estado de uno existente. Que necesitas hoy?',
      'texto',
    );
  }

  // ─── Enviar mensaje ────────────────────────────────────────────────────────

  Future<void> _enviar() async {
    final texto = _inputController.text.trim();
    if (texto.isEmpty || _procesando) return;

    _agregarMensajeCliente(texto, 'texto');
    _inputController.clear();
    setState(() => _procesando = true);

    try {
      final resp = await _agenteApi.enviarMensaje(
        clienteId: _clienteId,
        mensaje: texto,
        conversacionId: _conversacionId,
        tipo: 'texto',
        token: _token,
      );
      _manejarRespuesta(resp);
    } catch (e) {
      _agregarMensajeAgente(
        'Ocurrio un error de conexion. Por favor intenta de nuevo.',
        'texto',
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _enviarConfirmacion(String valor) {
    _inputController.text = valor;
    _enviar();
  }

  // ─── Archivo ──────────────────────────────────────────────────────────────

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final filePath = file.path;
    if (filePath == null) return;

    setState(() => _procesando = true);
    try {
      // Subir archivo al backend
      final uri = Uri.parse('${ApiConstants.baseUrl}/archivos/upload');
      final request = http.MultipartRequest('POST', uri);
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: file.name));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final archivoUrl = data['url'] ?? data['data']?['url'] ?? '';

        _agregarMensajeCliente('[Archivo: ${file.name}]', 'archivo');

        if (_conversacionId != null) {
          final resp = await _agenteApi.notificarArchivo(
            conversacionId: _conversacionId!,
            clienteId: _clienteId,
            archivoUrl: archivoUrl,
            nombreArchivo: file.name,
            token: _token,
          );
          _manejarRespuesta(resp);
        }
      } else {
        _agregarMensajeAgente('Error al subir el archivo. Intenta de nuevo.', 'texto');
      }
    } catch (e) {
      _agregarMensajeAgente('No se pudo subir el archivo. Verifica tu conexion.', 'texto');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ─── Voz ──────────────────────────────────────────────────────────────────

  Future<void> _toggleVoz() async {
    if (!_vozDisponible) return;

    if (_escuchandoVoz) {
      await _speech.stop();
      setState(() => _escuchandoVoz = false);
    } else {
      setState(() => _escuchandoVoz = true);
      await _speech.listen(
        localeId: 'es_BO',
        onResult: (result) {
          if (result.finalResult) {
            setState(() {
              _inputController.text = result.recognizedWords;
              _escuchandoVoz = false;
            });
          }
        },
        cancelOnError: true,
      );
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _manejarRespuesta(Map<String, dynamic> resp) {
    if (mounted) {
      setState(() {
        if (resp['conversacionId'] != null) {
          _conversacionId = resp['conversacionId'] as String;
        }
        if (resp['estadoConversacion'] != null) {
          _estadoConversacion = resp['estadoConversacion'] as String;
        }
        if (resp['mensajeAgente'] != null) {
          final tipo = _estadoConversacion == 'CONFIRMANDO_POLITICA' ? 'confirmacion' : 'texto';
          _agregarMensajeAgente(resp['mensajeAgente'] as String, tipo);
        }
        if (_estadoConversacion == 'COMPLETADO' || _estadoConversacion == 'RECHAZADO') {
          _estadoBadge = _estadoConversacion;
        }
      });
    }
  }

  void _agregarMensajeAgente(String contenido, String tipo) {
    setState(() {
      _mensajes.add(MensajeUI(
        rol: 'agente',
        contenido: contenido,
        tipo: tipo,
        timestamp: DateTime.now(),
      ));
    });
    _scrollAbajo();
  }

  void _agregarMensajeCliente(String contenido, String tipo) {
    setState(() {
      _mensajes.add(MensajeUI(
        rol: 'cliente',
        contenido: contenido,
        tipo: tipo,
        timestamp: DateTime.now(),
      ));
    });
    _scrollAbajo();
  }

  void _scrollAbajo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatHora(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _getBadgeColor() {
    switch (_estadoBadge) {
      case 'COMPLETADO': return Colors.green;
      case 'RECHAZADO': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _getBadgeTexto() {
    switch (_estadoBadge) {
      case 'COMPLETADO': return 'Tramite completado';
      case 'RECHAZADO': return 'Tramite rechazado';
      default: return 'En proceso';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: AppBar(
        backgroundColor: _colorCard,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Asistente CRE',
              style: TextStyle(color: _colorTexto, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'Tramites en linea',
              style: TextStyle(color: _colorMuted, fontSize: 12),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: _colorTexto),
        actions: [
          if (_estadoBadge != null)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getBadgeColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getBadgeTexto(),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Lista de mensajes
          Expanded(
            child: _mensajes.isEmpty
                ? _buildBienvenida()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _mensajes.length + (_procesando ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _mensajes.length && _procesando) {
                        return _buildProcesando();
                      }
                      return _buildMensaje(_mensajes[i]);
                    },
                  ),
          ),

          // Barra de entrada
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildBienvenida() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Bienvenido al asistente de tramites de CRE',
            style: TextStyle(color: _colorTexto, fontSize: 15, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Puedes iniciar un tramite, subir documentos y hacer seguimiento en tiempo real.',
            style: TextStyle(color: _colorMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildSugerencia('Nueva instalacion de medidor'),
          _buildSugerencia('Reconexion de servicio'),
          _buildSugerencia('Reclamo de factura'),
        ],
      ),
    );
  }

  Widget _buildSugerencia(String texto) {
    return GestureDetector(
      onTap: () => _enviarConfirmacion(texto),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _colorCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _colorBorde),
        ),
        child: Text(
          texto,
          style: const TextStyle(color: _colorPrimario, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildMensaje(MensajeUI msg) {
    final esAgente = msg.rol == 'agente';
    return Align(
      alignment: esAgente ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: esAgente ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: esAgente ? _colorAgente : _colorCliente,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: esAgente ? const Radius.circular(4) : const Radius.circular(16),
                  bottomRight: esAgente ? const Radius.circular(16) : const Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.contenido,
                    style: const TextStyle(color: _colorTexto, fontSize: 14, height: 1.4),
                  ),
                  if (msg.tipo == 'confirmacion' && esAgente) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBtnConfirmacion('Si', Colors.green, () => _enviarConfirmacion('Si, correcto')),
                        const SizedBox(width: 8),
                        _buildBtnConfirmacion('No', Colors.red, () => _enviarConfirmacion('No, otro tramite')),
                      ],
                    ),
                  ],
                  if (msg.tipo == 'archivo') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Archivo adjunto',
                        style: TextStyle(color: Colors.blue[300], fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatHora(msg.timestamp),
              style: TextStyle(color: _colorMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBtnConfirmacion(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildProcesando() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _colorAgente,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: const _PuntosAnimados(),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      color: _colorCard,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Boton adjuntar
          IconButton(
            icon: const Icon(Icons.attach_file, color: _colorMuted),
            onPressed: _procesando ? null : _seleccionarArchivo,
            tooltip: 'Adjuntar archivo',
          ),

          // Input texto
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_procesando,
              style: const TextStyle(color: _colorTexto, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Escribe tu consulta...',
                hintStyle: TextStyle(color: _colorMuted, fontSize: 14),
                filled: true,
                fillColor: _colorFondo,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: _colorBorde),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: _colorBorde),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: _colorPrimario),
                ),
              ),
              onSubmitted: (_) => _enviar(),
            ),
          ),

          // Boton voz
          if (_vozDisponible)
            IconButton(
              icon: Icon(
                _escuchandoVoz ? Icons.mic : Icons.mic_none,
                color: _escuchandoVoz ? Colors.red : _colorMuted,
              ),
              onPressed: _procesando ? null : _toggleVoz,
              tooltip: 'Dictado por voz',
            ),

          // Boton enviar
          IconButton(
            icon: Icon(
              Icons.send,
              color: _procesando ? _colorMuted : _colorPrimario,
            ),
            onPressed: _procesando ? null : _enviar,
            tooltip: 'Enviar',
          ),
        ],
      ),
    );
  }
}

// Animacion de puntos
class _PuntosAnimados extends StatefulWidget {
  const _PuntosAnimados();

  @override
  State<_PuntosAnimados> createState() => _PuntosAnimadosState();
}

class _PuntosAnimadosState extends State<_PuntosAnimados> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final opacity = ((_controller.value * 3) - i).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF9D9D60).withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
