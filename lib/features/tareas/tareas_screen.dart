import 'package:flutter/material.dart';

class TareasScreen extends StatefulWidget {
  const TareasScreen({Key? key}) : super(key: key);

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

class _TareasScreenState extends State<TareasScreen> {
  // Mock data, para un caso real haríamos API request aquí a /ejecuciones/departamento/X
  List<Map<String, dynamic>> tareas = [
    {
      'id': 'ejec1234',
      'titulo': 'Trámite de Prueba Seeder',
      'nodo': 'Revision Inicial',
      'prioridad': 'ALTA',
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tareas.length,
        itemBuilder: (context, index) {
          final t = tareas[index];
          return Card(
            color: const Color(0xFF2e2e14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: const Color(0xFF9d9d60).withOpacity(0.3)),
            ),
            child: ListTile(
              title: Text(t['titulo'], style: const TextStyle(color: Color(0xFFF5F5E8))),
              subtitle: Text('ID: ${t['id']}\nNodo: ${t['nodo']}', style: const TextStyle(color: Color(0xFFC0C080))),
              isThreeLine: true,
              trailing: Chip(
                label: Text(t['prioridad']),
                backgroundColor: t['prioridad'] == 'ALTA' ? Colors.red.shade900 : Colors.orange.shade700,
              ),
              onTap: () {
                // Aqui navegaríamos a EjecutarTareaScreen
                // Navigator.pushNamed(context, '/ejecutar_tarea', arguments: t['id']);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abriendo formulario de ejecución...'))
                );
              },
            ),
          );
        },
      ),
    );
  }
}
