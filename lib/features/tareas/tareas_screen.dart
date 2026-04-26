import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/ejecucion_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';

const _colorFondo = Color(0xFF1a1a00);
const _colorCard = Color(0xFF2e2e14);
const _colorPrimario = Color(0xFFC0C080);
const _colorTexto = Color(0xFFF5F5E8);
const _colorMuted = Color(0xFF9D9D60);
const _colorBorde = Color(0xFF565620);

class TareasScreen extends StatefulWidget {
  const TareasScreen({super.key});

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

class _TareasScreenState extends State<TareasScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  List<EjecucionDetallada> _tareas = [];
  bool _cargando = false;
  String? _error;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _inicializarPantalla();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted && !_cargando) {
        _cargar();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _inicializarPantalla() async {
    await _auth.ensureUserLoaded();
    if (!mounted) return;
    await _cargar();
  }

  Future<void> _cargar() async {
    await _auth.ensureUserLoaded();
    final userId = _auth.userId;
    final token = await _auth.getToken();
    if (userId == null || token == null) {
      setState(() {
        _error = 'Sesion invalida. Vuelve a iniciar sesion.';
        _cargando = false;
      });
      return;
    }

    setState(() { _cargando = true; _error = null; });
    try {
      final todas = await _api.listarTareasFuncionario(userId, token);
      // Mostrar solo PENDIENTE y EN_PROCESO, ordenar por prioridad luego fecha
      final activas = todas.where((t) =>
          t.estado == 'PENDIENTE' || t.estado == 'EN_PROCESO').toList();
      activas.sort((a, b) {
        const orden = {'ALTA': 0, 'MEDIA': 1, 'BAJA': 2};
        final pa = orden[a.prioridad] ?? 1;
        final pb = orden[b.prioridad] ?? 1;
        if (pa != pb) return pa.compareTo(pb);
        return (a.iniciadoEn ?? '').compareTo(b.iniciadoEn ?? '');
      });
      setState(() { _tareas = activas; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _cargando = false; });
    }
  }

  Color _colorPrioridad(String? p) {
    switch (p) {
      case 'ALTA': return const Color(0xFFF44250);
      case 'BAJA': return const Color(0xFF6BD968);
      default: return const Color(0xFFFECC1B);
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'EN_PROCESO': return const Color(0xFFFECC1B);
      default: return const Color(0xFF3992FF);
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
            const Text('Mis Tareas', style: TextStyle(color: _colorTexto, fontSize: 16)),
            Text('$userName · $userDept', 
              style: const TextStyle(color: _colorMuted, fontSize: 12, fontWeight: FontWeight.w400),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _colorPrimario),
            onPressed: _cargar,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: _colorMuted),
            onPressed: () async {
              await _auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: _colorPrimario));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFF44250), size: 48),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFF44250)), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargar,
                style: ElevatedButton.styleFrom(backgroundColor: _colorPrimario),
                child: const Text('Reintentar', style: TextStyle(color: _colorFondo)),
              ),
            ],
          ),
        ),
      );
    }
    if (_tareas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: _colorMuted, size: 64),
            const SizedBox(height: 16),
            const Text('Sin tareas pendientes', style: TextStyle(color: _colorMuted, fontSize: 16)),
            const SizedBox(height: 8),
            TextButton(onPressed: _cargar, child: const Text('Actualizar', style: TextStyle(color: _colorPrimario))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _colorPrimario,
      backgroundColor: _colorCard,
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tareas.length,
        itemBuilder: (context, index) => _buildCard(_tareas[index]),
      ),
    );
  }

  Widget _buildCard(EjecucionDetallada tarea) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).pushNamed('/ejecutar_tarea', arguments: tarea.id);
        _cargar();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _colorCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _colorBorde),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _colorPrioridad(tarea.prioridad).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(tarea.prioridad ?? 'MEDIA',
                        style: TextStyle(color: _colorPrioridad(tarea.prioridad), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _colorEstado(tarea.estado).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(tarea.estado,
                        style: TextStyle(color: _colorEstado(tarea.estado), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(tarea.tramiteTitulo ?? 'Trámite',
                  style: const TextStyle(color: _colorTexto, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(tarea.nodoNombre ?? 'Tarea',
                  style: const TextStyle(color: _colorPrimario, fontSize: 13)),
              if (tarea.departamentoNombre != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.business, size: 12, color: _colorMuted),
                  const SizedBox(width: 4),
                  Text(tarea.departamentoNombre!, style: const TextStyle(color: _colorMuted, fontSize: 12)),
                ]),
              ],
              if (tarea.tiempoTranscurrido != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.schedule, size: 12, color: _colorMuted),
                  const SizedBox(width: 4),
                  Text(tarea.tiempoTranscurrido!, style: const TextStyle(color: _colorMuted, fontSize: 12)),
                ]),
              ],
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Abrir tarea', style: TextStyle(color: _colorPrimario, fontSize: 12)),
                  Icon(Icons.arrow_forward_ios, size: 12, color: _colorPrimario),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
