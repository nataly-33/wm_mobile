# wm_mobile

> Sistema de Gestión de Trámites y Políticas de Negocio — App Móvil

Aplicación Flutter del sistema **WorkflowManager**. Permite a los funcionarios ver sus tareas asignadas, ejecutarlas y recibir notificaciones push. Los administradores pueden monitorear el estado de las políticas en tiempo real.

---

## Stack

| Tecnología | Versión | Uso |
|------------|---------|-----|
| Flutter | 3.x | Framework principal |
| Dart | 3.x | Lenguaje principal |
| http | ^1.2.0 | Llamadas HTTP |
| flutter_secure_storage | ^9.0.0 | Almacenamiento seguro del JWT |
| provider | ^6.1.2 | Estado de la aplicación |
| socket_io_client | ^2.0.3+1 | WebSockets en tiempo real |
| firebase_core | ^2.27.1 | Core de Firebase |
| firebase_messaging | ^14.7.20 | Push notifications |
| flutter_local_notifications | ^17.1.2 | Notificaciones en foreground |
| file_picker | ^8.0.3 | Selección de archivos adjuntos |
| intl | ^0.19.0 | Formateo de fechas |

---

## Requisitos previos

```bash
flutter --version    # Flutter 3.x
dart --version       # Dart 3.x
git --version        # Git (cualquier versión reciente)

# Android
# Android Studio con SDK instalado
# O emulador configurado, o dispositivo físico con USB debugging

# Para verificar que todo está listo:
flutter doctor
# Todos los ítems deben estar en verde
```

---

## Instalación y ejecución local

### 1. Clonar el repositorio

```bash
git clone https://github.com/TU_USUARIO/wm_mobile.git
cd wm_mobile
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Configurar Firebase

1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/)
2. Agrega una app Android con el package name `com.workflow.workflow_mobile`
3. Descarga el archivo `google-services.json`
4. Colócalo en `android/app/google-services.json`

> Sin este archivo, las notificaciones push no funcionarán. El archivo **nunca** se sube al repositorio (está en `.gitignore`).

### 4. Configurar la URL del backend

Edita `lib/core/constants/api_url.dart`:

```dart
class ApiConstants {
  // Para emulador Android (el host de la máquina es 10.0.2.2)
  static const String baseUrl = 'http://10.0.2.2:8080';

  // Para dispositivo físico (usa la IP de tu máquina en la red local)
  // static const String baseUrl = 'http://192.168.x.x:8080';

  // Para producción (Azure)
  // static const String baseUrl = 'https://wm-backend.azurewebsites.net';
}
```

### 5. Ejecutar la app

```bash
# Ver dispositivos disponibles
flutter devices

# Ejecutar en el emulador o dispositivo conectado
flutter run

# Ejecutar en un dispositivo específico
flutter run -d emulator-5554
```

---

## Estructura del proyecto

```
lib/
├── main.dart                       ← Entry point
├── app.dart                        ← MaterialApp con rutas
│
├── core/
│   ├── config/
│   │   └── dio_client.dart         ← (Futuro: si se migra a Dio)
│   ├── constants/
│   │   └── api_url.dart            ← URLs del backend
│   ├── models/
│   │   ├── api_response.dart       ← Modelo de respuesta estándar
│   │   └── user.dart               ← Modelo del usuario logueado
│   └── services/
│       ├── auth_service.dart        ← Login, logout, JWT storage
│       ├── api_service.dart         ← Llamadas HTTP con JWT
│       ├── socket_service.dart      ← WebSockets en tiempo real
│       └── notification_service.dart ← Push notifications FCM
│
├── features/
│   ├── auth/
│   │   └── login_screen.dart       ← Pantalla de login
│   │
│   ├── funcionario/
│   │   ├── tareas_screen.dart      ← Lista de tareas pendientes
│   │   └── ejecutar_tarea_screen.dart ← Rellenar formulario del nodo
│   │
│   └── admin/
│       └── monitor_screen.dart     ← Monitor verde/amarillo/rojo
│
└── widgets/
    └── common_widgets.dart         ← Botones, inputs, badges reutilizables
```

---

## Vistas de la aplicación

### Funcionario

| Pantalla | Descripción |
|----------|-------------|
| Login | Autenticación con email y contraseña |
| Lista de tareas | Tareas pendientes del departamento del funcionario, ordenadas por prioridad |
| Ejecutar tarea | Formulario dinámico del nodo actual. Campos: texto, número, fecha, selección, archivo |

### Admin / Admin Departamento

| Pantalla | Descripción |
|----------|-------------|
| Login | Autenticación con email y contraseña |
| Monitor | Diagrama de la política con colores: 🟢 verde, 🟡 amarillo, 🔴 rojo. Actualizado en tiempo real por WebSocket |

---

## Notificaciones push

La app usa **Firebase Cloud Messaging (FCM)** para notificaciones push:

| Evento | Quién recibe |
|--------|-------------|
| Tarea asignada en tu departamento | Funcionario del departamento destino |
| Trámite completado | Admin General de la empresa |
| Trámite rechazado | Admin General de la empresa |

---

## Paleta de colores

La app sigue el mismo sistema de colores del frontend web:

```dart
// lib/widgets/common_widgets.dart
const Color primaryLight   = Color(0xFFC0C080);  // #C0C080
const Color primaryMid     = Color(0xFF9D9D60);  // #9D9D60
const Color primaryDark    = Color(0xFF333300);  // #333300
const Color bgDark         = Color(0xFF1a1a00);  // Fondo principal
const Color bgCard         = Color(0xFF2e2e14);  // Cards

const Color success = Color(0xFF6BD968);
const Color danger  = Color(0xFFF44250);
const Color warning = Color(0xFFFECC1B);
const Color info    = Color(0xFF3992FF);
```

---

## Variables de entorno / Configuración sensible

| Archivo | Descripción | ¿Se sube al repo? |
|---------|-------------|------------------|
| `android/app/google-services.json` | Credenciales Firebase Android | ❌ No |
| `lib/core/constants/api_url.dart` | URL del backend | ✅ Sí (con URL local) |

---

## Build y distribución

### APK de desarrollo

```bash
flutter build apk --debug
# APK en: build/app/outputs/flutter-apk/app-debug.apk
```

### APK de producción

```bash
# Actualizar lib/core/constants/api_url.dart con la URL de Azure primero
flutter build apk --release
# APK en: build/app/outputs/flutter-apk/app-release.apk
```

### Instalar APK en dispositivo

```bash
# Con ADB (Android Debug Bridge)
adb install build/app/outputs/flutter-apk/app-release.apk

# O transferir el archivo directamente al dispositivo
```

---

## Convención de commits

Este proyecto sigue [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(auth): implementar pantalla de login con validación
feat(tareas): agregar lista de tareas con badge de prioridad
fix(socket): resolver reconexión perdida en background
chore(deps): actualizar firebase_messaging a 14.7.20
style(monitor): ajustar colores de los badges de estado
```

---

## Licencia

Proyecto académico — Universidad Autónoma Gabriel René Moreno  
Materia: Ingeniería de Software I — Ing. Martínez Canedo
