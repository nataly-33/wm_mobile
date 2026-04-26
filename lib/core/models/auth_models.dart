class AuthResponse {
  final String token;
  final String id;
  final String nombre;
  final String email;
  final String rol;
  final String? departamentoId;
  final String? departamentoNombre;

  AuthResponse({
    required this.token,
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.departamentoId,
    this.departamentoNombre,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
      rol: json['rol'] as String,
      departamentoId: json['departamentoId'] as String?,
      departamentoNombre: json['departamentoNombre'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'id': id,
      'nombre': nombre,
      'email': email,
      'rol': rol,
      'departamentoId': departamentoId,
      'departamentoNombre': departamentoNombre,
    };
  }
}

class ApiResponse<T> {
  final int status;
  final String message;
  final T? data;

  ApiResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) dataParser) {
    return ApiResponse(
      status: json['status'] as int,
      message: json['message'] as String,
      data: json['data'] != null ? dataParser(json['data'] as Map<String, dynamic>) : null,
    );
  }
}

class User {
  final String id;
  final String nombre;
  final String email;
  final String rol;
  final String? departamentoId;
  final String? departamentoNombre;

  User({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.departamentoId,
    this.departamentoNombre,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
      rol: json['rol'] as String,
      departamentoId: json['departamentoId'] as String?,
      departamentoNombre: json['departamentoNombre'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'rol': rol,
      'departamentoId': departamentoId,
      'departamentoNombre': departamentoNombre,
    };
  }
}
