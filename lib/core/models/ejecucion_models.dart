class EjecucionDetallada {
  final String id;
  final String tramiteId;
  final String nodoId;
  final String? departamentoId;
  final String? funcionarioId;
  final String estado;
  final String? tramiteTitulo;
  final String? nodoNombre;
  final String? departamentoNombre;
  final String? funcionarioNombre;
  final String? prioridad;
  final String? fechaLimite;
  final String? iniciadoEn;
  final String? tiempoTranscurrido;
  final String? nombrePolitica;

  const EjecucionDetallada({
    required this.id,
    required this.tramiteId,
    required this.nodoId,
    this.departamentoId,
    this.funcionarioId,
    required this.estado,
    this.tramiteTitulo,
    this.nodoNombre,
    this.departamentoNombre,
    this.funcionarioNombre,
    this.prioridad,
    this.fechaLimite,
    this.iniciadoEn,
    this.tiempoTranscurrido,
    this.nombrePolitica,
  });

  factory EjecucionDetallada.fromJson(Map<String, dynamic> json) {
    return EjecucionDetallada(
      id: json['id'] as String? ?? '',
      tramiteId: json['tramiteId'] as String? ?? '',
      nodoId: json['nodoId'] as String? ?? '',
      departamentoId: json['departamentoId'] as String?,
      funcionarioId: json['funcionarioId'] as String?,
      estado: json['estado'] as String? ?? '',
      tramiteTitulo: (json['tramiteTitulo'] ?? json['tituloTramite']) as String?,
      nodoNombre: (json['nodoNombre'] ?? json['nombreNodo']) as String?,
      departamentoNombre: json['departamentoNombre'] as String?,
      funcionarioNombre: json['funcionarioNombre'] as String?,
      prioridad: json['prioridad'] as String?,
      fechaLimite: json['fechaLimite'] as String?,
      iniciadoEn: json['iniciadoEn'] as String?,
      tiempoTranscurrido: json['tiempoTranscurrido'] as String?,
      nombrePolitica: json['nombrePolitica'] as String?,
    );
  }
}

class FormularioCampo {
  final String nombre;
  final String etiqueta;
  final String tipo;
  final bool requerido;
  final bool esCampoPrioridad;
  final List<String> opciones;
  final int? filas;
  final List<String> columnas;

  const FormularioCampo({
    required this.nombre,
    required this.etiqueta,
    required this.tipo,
    required this.requerido,
    this.esCampoPrioridad = false,
    this.opciones = const [],
    this.filas,
    this.columnas = const [],
  });

  factory FormularioCampo.fromJson(Map<String, dynamic> json) {
    return FormularioCampo(
      nombre: json['nombre'] as String? ?? '',
      etiqueta: json['etiqueta'] as String? ?? '',
      tipo: json['tipo'] as String? ?? 'TEXTO',
      requerido: json['requerido'] as bool? ?? false,
      esCampoPrioridad: json['esCampoPrioridad'] as bool? ?? false,
      opciones: (json['opciones'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      filas: json['filas'] as int?,
      columnas: (json['columnas'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

class Formulario {
  final String id;
  final String nombre;
  final String nodoId;
  final List<FormularioCampo> campos;

  const Formulario({
    required this.id,
    required this.nombre,
    required this.nodoId,
    required this.campos,
  });

  factory Formulario.fromJson(Map<String, dynamic> json) {
    return Formulario(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      nodoId: json['nodoId'] as String? ?? '',
      campos: (json['campos'] as List<dynamic>?)
              ?.map((c) => FormularioCampo.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Politica {
  final String id;
  final String nombre;
  final String estado;

  const Politica({required this.id, required this.nombre, required this.estado});

  factory Politica.fromJson(Map<String, dynamic> json) {
    return Politica(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      estado: json['estado'] as String? ?? '',
    );
  }
}

// ── Monitor ─────────────────────────────────────────────────────────────────

class MonitorEstadisticas {
  final int activos;
  final int completados;
  final int rechazados;

  const MonitorEstadisticas({
    required this.activos,
    required this.completados,
    required this.rechazados,
  });

  factory MonitorEstadisticas.fromJson(Map<String, dynamic> json) {
    return MonitorEstadisticas(
      activos: json['activos'] as int? ?? 0,
      completados: json['completados'] as int? ?? 0,
      rechazados: json['rechazados'] as int? ?? 0,
    );
  }
}

class MonitorTramiteActivo {
  final String tramiteId;
  final String titulo;
  final String prioridad;
  final String? funcionarioNombre;
  final String? tiempoTranscurrido;
  final String? departamentoActualNombre;

  const MonitorTramiteActivo({
    required this.tramiteId,
    required this.titulo,
    required this.prioridad,
    this.funcionarioNombre,
    this.tiempoTranscurrido,
    this.departamentoActualNombre,
  });

  factory MonitorTramiteActivo.fromJson(Map<String, dynamic> json) {
    return MonitorTramiteActivo(
      tramiteId: json['tramiteId'] as String? ?? '',
      titulo: json['titulo'] as String? ?? '',
      prioridad: json['prioridad'] as String? ?? 'MEDIA',
      funcionarioNombre: json['funcionarioNombre'] as String?,
      tiempoTranscurrido: json['tiempoTranscurrido'] as String?,
      departamentoActualNombre: json['departamentoActualNombre'] as String?,
    );
  }
}

class MonitorNodoActivo {
  final String nombreNodo;
  final List<MonitorTramiteActivo> tramitesActivos;

  const MonitorNodoActivo({required this.nombreNodo, required this.tramitesActivos});

  factory MonitorNodoActivo.fromJson(Map<String, dynamic> json) {
    return MonitorNodoActivo(
      nombreNodo: json['nombreNodo'] as String? ?? '',
      tramitesActivos: (json['tramitesActivos'] as List<dynamic>?)
              ?.map((t) => MonitorTramiteActivo.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MonitorDepartamento {
  final String departamentoId;
  final String nombreDepartamento;
  final String color;
  final List<MonitorNodoActivo> nodosActivos;

  const MonitorDepartamento({
    required this.departamentoId,
    required this.nombreDepartamento,
    required this.color,
    required this.nodosActivos,
  });

  factory MonitorDepartamento.fromJson(Map<String, dynamic> json) {
    return MonitorDepartamento(
      departamentoId: json['departamentoId'] as String? ?? '',
      nombreDepartamento: json['nombreDepartamento'] as String? ?? '',
      color: json['color'] as String? ?? 'VACIO',
      nodosActivos: (json['nodosActivos'] as List<dynamic>?)
              ?.map((n) => MonitorNodoActivo.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MonitorPolitica {
  final String? politicaId;
  final String? nombrePolitica;
  final MonitorEstadisticas estadisticas;
  final List<MonitorDepartamento> departamentos;
  final List<MonitorTramiteActivo> tramitesActivos;

  const MonitorPolitica({
    this.politicaId,
    this.nombrePolitica,
    required this.estadisticas,
    required this.departamentos,
    required this.tramitesActivos,
  });

  factory MonitorPolitica.fromJson(Map<String, dynamic> json) {
    return MonitorPolitica(
      politicaId: json['politicaId'] as String?,
      nombrePolitica: json['nombrePolitica'] as String?,
      estadisticas: json['estadisticas'] != null
          ? MonitorEstadisticas.fromJson(json['estadisticas'] as Map<String, dynamic>)
          : const MonitorEstadisticas(activos: 0, completados: 0, rechazados: 0),
      departamentos: (json['departamentos'] as List<dynamic>?)
              ?.map((d) => MonitorDepartamento.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      tramitesActivos: (json['tramitesActivos'] as List<dynamic>?)
              ?.map((t) => MonitorTramiteActivo.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
