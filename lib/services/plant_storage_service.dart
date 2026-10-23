import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/plant_record.dart';

class PlantStorageService {
  static const String _key = 'plant_history';

  // Guardar un nuevo registro en el historial
  Future<void> savePlant(PlantRecord record) async {
    final history = await getHistory();
    history.insert(0, record); // Inserta el más reciente al inicio
    await _writeHistory(history);
  }

  // Obtener todo el historial guardado
  Future<List<PlantRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key);

    if (jsonList == null) return [];

    final history = <PlantRecord>[];
    for (final item in jsonList) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        history.add(PlantRecord.fromJson(map));
      } catch (e) {
        // Si un registro está dañado, lo saltamos en vez de romper toda la lista
        debugPrint('Registro ignorado por estar dañado: $e');
      }
    }
    return history;
  }

  // Eliminar un registro del historial
  Future<void> deletePlant(PlantRecord recordToDelete) async {
    final history = await getHistory();

    history.removeWhere((plant) =>
        plant.imagePath == recordToDelete.imagePath &&
        plant.date == recordToDelete.date);

    await _writeHistory(history);
  }

  // Un único lugar donde se serializa la lista. Usa PlantRecord.toJson(),
  // así se guardan TODOS los campos (científico, familia, luz, riego, etc.).
  Future<void> _writeHistory(List<PlantRecord> history) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = history.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }
}
