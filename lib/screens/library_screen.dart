import 'dart:io';
import 'package:flutter/material.dart';
import '../data/models/plant_record.dart';
import '../services/plant_storage_service.dart';
import 'plant_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final PlantStorageService _storageService = PlantStorageService();
  List<PlantRecord> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _storageService.getHistory();
    if (!mounted) return;
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  // Método para abrir la pantalla de detalles completa
  void _showPlantDetails(PlantRecord plant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDetailScreen(
          plant: plant,
          onDeleted: () {
            _loadHistory(); // Recarga la lista al volver si se eliminó
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Biblioteca de Plantas'),
        backgroundColor: Colors.green[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(
                  child: Text(
                    'Aún no tienes plantas guardadas.\n¡Identifica una y guárdala!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final plant = _history[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () => _showPlantDetails(plant),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(plant.imagePath),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 60),
                          ),
                        ),
                        title: Text(
                          plant.commonName ?? plant.plantName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            if (plant.commonName != null &&
                                plant.commonName!.isNotEmpty)
                              Text(
                                  'Científico: ${plant.scientificName ?? plant.plantName}'),
                            Text(
                                'Fecha: ${plant.date.toLocal().toString().split(' ')[0]}'),
                            if (!plant.isCorrect && plant.suggestedName != null)
                              Text(
                                'Sugerencia: ${plant.suggestedName}',
                                style: TextStyle(
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext dialogContext) =>
                                  AlertDialog(
                                title: const Text('¿Estás seguro?'),
                                content: const Text(
                                    'Esta acción eliminará el registro y la foto guardada permanentemente. No se podrá recuperar.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    onPressed: () async {
                                      final messenger =
                                          ScaffoldMessenger.of(this.context);
                                      Navigator.pop(dialogContext);
                                      await _storageService.deletePlant(plant);
                                      await _loadHistory();
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
                        ),
                      ), // <--- Cierre correcto del ListTile
                    ); // <--- Cierre correcto del Card
                  },
                ),
    );
  }
}
