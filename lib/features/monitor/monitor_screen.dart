import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/ejecucion_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/socket_service.dart';

const _colorFondo = Color(0xFF1a1a00);
const _colorCard = Color(0xFF2e2e14);
const _colorPrimario = Color(0xFFC0C080);
const _colorTexto = Color(0xFFF5F5E8);
const _colorMuted = Color(0xFF9D9D60);
const _colorBorde = Color(0xFF565620);

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  final _socket = SocketService();

  List<Politica> _politicas = [];
  Politica? _politicaSeleccionada;
  MonitorPolitica? _monitor;
  bool _cargando = false;
  String? _error;
  final List<Map<String, dynamic>> _eventosRecientes = [];
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _inicializar();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!mounted) return;
      if (_politicaSeleccionada == null) return;

      if (!_socket.isConnected) {
        final token = await _auth.getToken();
        if (token != null) {
          _conectarWebSocket(token);
        }
      }

      if (!_cargando) {
        _cargarMonitor();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _socket.desconectar();
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _auth.ensureUserLoaded();
    final token = await _auth.getToken();
    if (token == null) return;

    setState(() { _cargando = true; });
    try {
      final politicas = await _api.listarPoliticasActivas(token);
      setState(() { _politicas = politicas; });

      if (politicas.isNotEmpty) {
        _politicaSeleccionada = politicas.first;
        await _cargarMonitor();
        _conectarWebSocket(token);
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _cargando = false; });
    }
  }

  Future<void> _cargarMonitor() async {
    final token = await _auth.getToken();
    final politicaId = _politicaSeleccionada?.id;
    if (token == null || politicaId == null) return;

    setState(() { _error = null; });
    try {
      final monitor = await _api.obtenerMonitor(politicaId, token);
      setState(() { _monitor = monitor; });
    } catch (e) {
      setState(() { _error = 'Error al cargar monitor'; });
    }
  }

  void _conectarWebSocket(String token) {
    _socket.conectar(
      token: token,
      onConnected: () {
        if (_politicaSeleccionada != null) {
          _socket.suscribirAMonitor(_politicaSeleccionada!.id, _onEvento);
        }
      },
    );
  }

  void _onEvento(Map<String, dynamic> evento) {
    setState(() {
      _eventosRecientes.insert(0, evento);
      if (_eventosRecientes.length > 8) _eventosRecientes.removeLast();

      // Actualizar estadísticas optimistamente
      if (_monitor != null) {
        final tipo = evento['tipo'] as String?;
        if (tipo == 'TRAMITE_COMPLETADO') {
          _monitor = MonitorPolitica(
            politicaId: _monitor!.politicaId,
            nombrePolitica: _monitor!.nombrePolitica,
            estadisticas: MonitorEstadisticas(
              activos: (_monitor!.estadisticas.activos - 1).clamp(0, 9999),
              completados: _monitor!.estadisticas.completados + 1,
              rechazados: _monitor!.estadisticas.rechazados,
            ),
            departamentos: _monitor!.departamentos,
            tramitesActivos: _monitor!.tramitesActivos,
          );
        } else if (tipo == 'TRAMITE_RECHAZADO') {
          _monitor = MonitorPolitica(
            politicaId: _monitor!.politicaId,
            nombrePolitica: _monitor!.nombrePolitica,
            estadisticas: MonitorEstadisticas(
              activos: (_monitor!.estadisticas.activos - 1).clamp(0, 9999),
              completados: _monitor!.estadisticas.completados,
              rechazados: _monitor!.estadisticas.rechazados + 1,
            ),
            departamentos: _monitor!.departamentos,
            tramitesActivos: _monitor!.tramitesActivos,
          );
        } else if (tipo == 'TRAMITE_INICIADO') {
          _monitor = MonitorPolitica(
            politicaId: _monitor!.politicaId,
            nombrePolitica: _monitor!.nombrePolitica,
            estadisticas: MonitorEstadisticas(
              activos: _monitor!.estadisticas.activos + 1,
              completados: _monitor!.estadisticas.completados,
              rechazados: _monitor!.estadisticas.rechazados,
            ),
            departamentos: _monitor!.departamentos,
            tramitesActivos: _monitor!.tramitesActivos,
          );
        }
      }
    });
    // Recargar datos completos con pequeño delay
    Future.delayed(const Duration(milliseconds: 500), _cargarMonitor);
  }

  void _cambiarPolitica(Politica p) async {
    if (_politicaSeleccionada?.id == p.id) return;
    _socket.desuscribir('/topic/politica/${_politicaSeleccionada?.id}');
    setState(() {
      _politicaSeleccionada = p;
      _monitor = null;
      _eventosRecientes.clear();
    });
    await _cargarMonitor();
    if (_socket.isConnected) {
      _socket.suscribirAMonitor(p.id, _onEvento);
    }
  }

  Color _colorDepto(String color) {
    switch (color) {
      case 'ROJO': return const Color(0xFFF44250);
      case 'AMARILLO': return const Color(0xFFFECC1B);
      default: return _colorBorde;
    }
  }

  Color _colorPrioridad(String p) {
    switch (p) {
      case 'ALTA': return const Color(0xFFF44250);
      case 'BAJA': return const Color(0xFF6BD968);
      default: return const Color(0xFFFECC1B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _auth.userName ?? 'Usuario';
    final userDept = _auth.userDepartamento ?? 'Departamento';
    
    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: AppBar(
        backgroundColor: _colorCard,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monitor', style: TextStyle(color: _colorTexto, fontSize: 16)),
            Text('$userName · $userDept', 
              style: const TextStyle(color: _colorMuted, fontSize: 12, fontWeight: FontWeight.w400),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _colorPrimario), onPressed: _cargarMonitor),
          IconButton(
            icon: const Icon(Icons.logout, color: _colorMuted),
            onPressed: () async {
              await _auth.logout();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _colorPrimario))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de política
          if (_politicas.isNotEmpty) _buildSelectorPolitica(),
          const SizedBox(height: 16),

          // Error
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFFF44250).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFF44250))),
            ),

          // Estadísticas
          if (_monitor != null) ...[
            _buildEstadisticas(),
            const SizedBox(height: 16),
            _buildDepartamentos(),
            const SizedBox(height: 16),
            if (_eventosRecientes.isNotEmpty) _buildEventos(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectorPolitica() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _colorCard, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _colorBorde),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Politica>(
          value: _politicaSeleccionada,
          isExpanded: true,
          dropdownColor: _colorCard,
          style: const TextStyle(color: _colorTexto),
          iconEnabledColor: _colorPrimario,
          items: _politicas.map((p) =>
            DropdownMenuItem(value: p, child: Text(p.nombre))).toList(),
          onChanged: (p) { if (p != null) _cambiarPolitica(p); },
        ),
      ),
    );
  }

  Widget _buildEstadisticas() {
    final stats = _monitor!.estadisticas;
    return Row(children: [
      _statChip('${stats.activos} activo${stats.activos != 1 ? 's' : ''}', const Color(0xFFFECC1B)),
      const SizedBox(width: 8),
      _statChip('${stats.completados} completado${stats.completados != 1 ? 's' : ''}', const Color(0xFF6BD968)),
      const SizedBox(width: 8),
      _statChip('${stats.rechazados} rechazado${stats.rechazados != 1 ? 's' : ''}', const Color(0xFFF44250)),
    ]);
  }

  Widget _statChip(String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDepartamentos() {
    if (_monitor!.departamentos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Departamentos', style: TextStyle(color: _colorMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        ..._monitor!.departamentos.map(_buildDeptoCard),
      ],
    );
  }

  Widget _buildDeptoCard(MonitorDepartamento depto) {
    final color = _colorDepto(depto.color);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _colorCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(depto.nombreDepartamento,
                  style: const TextStyle(color: _colorTexto, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (depto.nodosActivos.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text('Sin actividad', style: TextStyle(color: _colorMuted, fontSize: 12)),
            )
          else
            ...depto.nodosActivos.map((nodo) => _buildNodoActivo(nodo)),
        ],
      ),
    );
  }

  Widget _buildNodoActivo(MonitorNodoActivo nodo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Text(nodo.nombreNodo,
              style: const TextStyle(color: _colorPrimario, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        ...nodo.tramitesActivos.map((t) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _colorFondo,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _colorPrioridad(t.prioridad).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(t.prioridad, style: TextStyle(color: _colorPrioridad(t.prioridad), fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(t.titulo, style: const TextStyle(color: _colorTexto, fontSize: 12), overflow: TextOverflow.ellipsis)),
              if (t.tiempoTranscurrido != null)
                Text(t.tiempoTranscurrido!, style: const TextStyle(color: _colorMuted, fontSize: 11)),
            ]),
          ),
        )),
      ],
    );
  }

  Widget _buildEventos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Eventos recientes', style: TextStyle(color: _colorMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: _colorCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: _colorBorde)),
          child: Column(
            children: _eventosRecientes.asMap().entries.map((entry) {
              final e = entry.value;
              final tipo = e['tipo'] as String? ?? '';
              final titulo = e['titulo'] as String?;
              final isCompletado = tipo == 'TRAMITE_COMPLETADO';
              final isRechazado = tipo == 'TRAMITE_RECHAZADO';

              Color bgColor = Colors.transparent;
              Color badgeColor = _colorMuted;
              if (isCompletado) { bgColor = const Color(0xFF6BD968).withOpacity(0.07); badgeColor = const Color(0xFF6BD968); }
              if (isRechazado) { bgColor = const Color(0xFFF44250).withOpacity(0.07); badgeColor = const Color(0xFFF44250); }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: entry.key < _eventosRecientes.length - 1
                    ? const Border(bottom: BorderSide(color: _colorBorde))
                    : null,
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text(tipo.replaceAll('_', ' '), style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(titulo ?? e['tramiteId']?.toString().substring(0, 8) ?? '', style: const TextStyle(color: _colorTexto, fontSize: 12), overflow: TextOverflow.ellipsis)),
                ]),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
