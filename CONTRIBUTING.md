# Guía de Contribución — wm_mobile

Esta guía define las convenciones para contribuir a la app Flutter del proyecto WorkflowManager.

---

## Flujo de trabajo con Git

### Rama principal

Este proyecto trabaja sobre **una sola rama: `main`**.

- Cada commit debe dejar la app en estado compilable (`flutter build apk --debug` no puede fallar)
- Verificar siempre con `flutter analyze` antes de pushear

### Antes de hacer commit

```bash
# 1. Verificar que no hay errores
flutter analyze

# 2. Verificar que compila
flutter build apk --debug

# 3. Recién entonces, commitear
git add .
git commit -m "feat(tareas): descripción del cambio"
git push origin main
```

---

## Convención de commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/).

### Tipos permitidos

| Tipo | Cuándo usarlo |
|------|---------------|
| `feat` | Nueva pantalla o funcionalidad |
| `fix` | Corrección de bug |
| `style` | Solo cambios visuales, colores, padding |
| `refactor` | Refactorización sin nueva funcionalidad |
| `docs` | Solo documentación |
| `chore` | Dependencias, configuración |
| `test` | Tests |

### Ámbitos del proyecto

```
auth, tareas, ejecutar, monitor, notificaciones,
widgets, core, socket, api
```

### Ejemplos correctos

```bash
git commit -m "feat(auth): implementar pantalla de login con validación"
git commit -m "feat(tareas): agregar lista con pull-to-refresh y badge de prioridad"
git commit -m "feat(ejecutar): implementar formulario dinámico por tipo de campo"
git commit -m "feat(monitor): agregar colores en tiempo real por WebSocket"
git commit -m "fix(socket): resolver pérdida de conexión al ir a background"
git commit -m "fix(notificaciones): corregir navegación al hacer tap en push"
git commit -m "style(tareas): ajustar card de tarea con colores de prioridad"
git commit -m "chore(deps): actualizar firebase_messaging a 14.7.20"
```

### Ejemplos incorrectos

```bash
# ❌ Sin tipo ni ámbito
git commit -m "arreglé el formulario"

# ❌ Sin ámbito
git commit -m "feat: nueva pantalla"

# ❌ Demasiado genérico
git commit -m "fix: varios arreglos"
```

---

## Proceso de desarrollo

### Orden al crear una nueva pantalla

```
1. Model  → Clase Dart con fromJson/toJson
2. Service → Llamadas HTTP o lógica
3. Screen  → Widget StatefulWidget o StatelessWidget
4. Route   → Agregar ruta en app.dart
```

### 1. Model — Clase Dart

**Ubicación:** `lib/core/models/` para modelos globales o `lib/features/[feature]/models/` para específicos

```dart
// lib/core/models/tramite.dart
class Tramite {
  final String id;
  final String titulo;
  final String estado;
  final String prioridad;
  final String? fechaLimite;
  final String nodoActualId;

  Tramite({
    required this.id,
    required this.titulo,
    required this.estado,
    required this.prioridad,
    this.fechaLimite,
    required this.nodoActualId,
  });

  factory Tramite.fromJson(Map<String, dynamic> json) {
    return Tramite(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      estado: json['estado'] as String,
      prioridad: json['prioridad'] as String,
      fechaLimite: json['fechaLimite'] as String?,
      nodoActualId: json['nodoActualId'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'estado': estado,
    'prioridad': prioridad,
    'fechaLimite': fechaLimite,
    'nodoActualId': nodoActualId,
  };

  // Getters útiles
  bool get esUrgente => prioridad == 'ALTA';

  Color get colorPrioridad {
    switch (prioridad) {
      case 'ALTA':   return const Color(0xFFF44250);
      case 'MEDIA':  return const Color(0xFFFECC1B);
      case 'BAJA':   return const Color(0xFF6BD968);
      default:       return const Color(0xFF9D9D60);
    }
  }
}
```

**Reglas:**
- Siempre serialización manual con `fromJson` / `toJson`. Sin generadores de código.
- Los campos opcionales con `?` en el tipo y como `nullable` en el constructor
- Nunca usar `dynamic` sin castear explícitamente
- Agregar getters útiles para la UI (colores, labels, booleanos derivados)

### 2. Service — Llamadas HTTP

**Ubicación:** `lib/core/services/` para servicios globales

```dart
// lib/core/services/ejecucion_service.dart
import 'dart:convert';
import 'api_service.dart';
import '../models/ejecucion.dart';

class EjecucionService {
  final ApiService _api = ApiService();

  Future<List<Ejecucion>> obtenerPendientesFuncionario(String usuarioId) async {
    final response = await _api.get('/api/v1/ejecuciones/funcionario/$usuarioId');
    final List<dynamic> data = response['data'] as List<dynamic>;
    return data.map((json) => Ejecucion.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> completar(String id, Map<String, dynamic> respuestas) async {
    await _api.put('/api/v1/ejecuciones/$id/completar', {
      'respuestaFormulario': respuestas,
    });
  }

  Future<void> rechazar(String id, String observacion) async {
    await _api.put('/api/v1/ejecuciones/$id/rechazar', {
      'observaciones': observacion,
    });
  }
}
```

**Reglas:**
- Usar siempre `ApiService` (maneja JWT y errores globalmente)
- Retornar siempre tipos específicos, nunca `dynamic` o `Map<String, dynamic>` directamente
- Capturar errores específicos y relanzar con mensajes claros

### 3. Screen — Widget

**Ubicación:** `lib/features/[feature]/[nombre]_screen.dart`

```dart
// lib/features/funcionario/tareas_screen.dart
import 'package:flutter/material.dart';
import '../../core/models/ejecucion.dart';
import '../../core/services/ejecucion_service.dart';
import '../../widgets/common_widgets.dart';

class TareasScreen extends StatefulWidget {
  const TareasScreen({super.key});

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

class _TareasScreenState extends State<TareasScreen> {
  final EjecucionService _service = EjecucionService();
  List<Ejecucion> _tareas = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final tareas = await _service.obtenerPendientesFuncionario('usuario-id');
      setState(() { _tareas = tareas; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a00),
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        backgroundColor: const Color(0xFF242410),
        foregroundColor: const Color(0xFFf5f5e8),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xFFF44250))),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_tareas.isEmpty) {
      return const Center(
        child: Text(
          'No tienes tareas pendientes',
          style: TextStyle(color: Color(0xFF9D9D60)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tareas.length,
      itemBuilder: (context, index) => _TareaCard(tarea: _tareas[index]),
    );
  }
}
```

**Reglas:**
- Siempre manejar los 3 estados: `_isLoading`, `_error`, lista vacía
- Siempre `RefreshIndicator` para pull-to-refresh en listas
- Nombres privados para métodos y variables de estado: `_cargar()`, `_tareas`, `_isLoading`
- Colores siempre como constantes `const Color(0xFF...)` o desde `common_widgets.dart`

### 4. Agregar ruta en app.dart

```dart
// lib/app.dart
routes: {
  '/login':     (context) => const LoginScreen(),
  '/tareas':    (context) => const TareasScreen(),
  '/ejecutar':  (context) => const EjecutarTareaScreen(),
  '/monitor':   (context) => const MonitorScreen(),
  // Nueva ruta aquí:
  '/nueva':     (context) => const NuevaPantallaScreen(),
},
```

---

## Manejo de errores

### ApiService maneja automáticamente

- Token expirado (401) → limpia storage y navega a login
- Errores de red → lanza `Exception('Sin conexión a internet')`
- Errores del servidor (500) → lanza `Exception('Error del servidor')`

### En las pantallas

```dart
try {
  final data = await _service.obtener();
  setState(() { _data = data; });
} on Exception catch (e) {
  setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
} finally {
  setState(() { _isLoading = false; });
}
```

---

## Checklist antes de hacer commit

```
□ flutter analyze no tiene errores ni warnings críticos
□ flutter build apk --debug compila correctamente
□ La pantalla maneja los 3 estados: loading, error, lista vacía
□ Se usa RefreshIndicator en listas
□ Los colores usan las constantes de common_widgets.dart
□ El modelo tiene fromJson/toJson sin dynamic sin castear
□ google-services.json NO está en el commit (está en .gitignore)
□ La URL de la API en api_url.dart apunta al entorno local, no a producción
□ El commit sigue Conventional Commits
```
