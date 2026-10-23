import 'dart:io';
import 'package:flutter/material.dart';
import '../data/models/plant_record.dart';
import '../services/plant_storage_service.dart';

class PlantDetailScreen extends StatelessWidget {
  final PlantRecord plant;
  final VoidCallback onDeleted;

  const PlantDetailScreen(
      {super.key, required this.plant, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final PlantStorageService storageService = PlantStorageService();

    return Scaffold(
      appBar: AppBar(
        title: Text(plant.plantName),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen grande de la planta
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(plant.imagePath),
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 100),
              ),
            ),
            const SizedBox(height: 20),

            // Nueva Tarjeta de Parámetros Botánicos
            // Tarjeta única de Ficha Botánica y Cuidados
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🌱 Ficha Botánica y Cuidados',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const Divider(height: 20),
                    if (plant.commonName != null &&
                        plant.commonName!.isNotEmpty) ...[
                      _buildBotanicRow(
                          Icons.eco, 'Nombre común:', plant.commonName!),
                      const SizedBox(height: 10),
                    ],
                    _buildBotanicRow(Icons.science, 'Nombre científico:',
                        plant.scientificName ?? 'No especificado'),
                    const SizedBox(height: 10),
                    _buildBotanicRow(Icons.account_tree, 'Familia:',
                        plant.family ?? 'General / Ornamental'),
                    const SizedBox(height: 10),
                    _buildBotanicRow(Icons.wb_sunny, 'Luz recomendada:',
                        plant.light ?? 'Luz indirecta brillante'),
                    const SizedBox(height: 10),
                    _buildBotanicRow(
                        Icons.water_drop,
                        'Riego:',
                        plant.watering ??
                            'Moderado (dejar secar la tierra entre riegos)'),
                    const SizedBox(height: 10),
                    _buildBotanicRow(
                        Icons.spa,
                        'Consejos de cuidado:',
                        plant.careTips ??
                            'Evitar encharcamientos y limpiar las hojas regularmente.'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      // Ventana de confirmación antes de borrar
                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) => AlertDialog(
                          title: const Text('¿Estás seguro?'),
                          content: const Text(
                              'Esta acción eliminará el registro y la foto guardada permanentemente. No se podrá recuperar.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(
                                  dialogContext), // Cierra la alerta sin borrar
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () async {
                                // Capturamos todo ANTES del await (evita usar
                                // el context después de una pausa asíncrona)
                                final navigator = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);

                                Navigator.pop(dialogContext); // Cierra la alerta
                                await storageService.deletePlant(
                                    plant); // Borra del almacenamiento
                                onDeleted(); // Actualiza la lista en la biblioteca
                                navigator.pop(); // Sale de la pantalla de detalles
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Registro eliminado de la biblioteca')),
                                );
                              },
                              child: const Text('Sí, eliminar',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete),
                    label:
                        const Text('Eliminar', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para alinear los parámetros botánicos con íconos
  Widget _buildBotanicRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.green[700]),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              children: [
                TextSpan(
                    text: '$title ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
