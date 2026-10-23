import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/plant_record.dart';

class PlantStorageService {
  static const String _key = 'plant_history';

  // Guardar un nuevo registro en el historial
  Future<void> savePlant(PlantRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    List<PlantRecord> history = await getHistory();

    history.insert(0, record); // Inserta el más reciente al inicio

    List<String> jsonList = history
        .map((p) => jsonEncode({
              'imagePath': p.imagePath,
              'plantName': p.plantName,
              'date': p.date.toIso8601String(),
              'isCorrect': p.isCorrect,
              'suggestedName': p.suggestedName,
            }))
        .toList();

    await prefs.setStringList(_key, jsonList);
  }

  // Obtener todo el historial guardado
  Future<List<PlantRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? jsonList = prefs.getStringList(_key);

    if (jsonList == null) return [];

    return jsonList.map((item) {
      Map<String, dynamic> map = jsonDecode(item);
      return PlantRecord(
        imagePath: map['imagePath'],
        plantName: map['plantName'],
        commonName: map['commonName'],
        scientificName: map['scientificName'],
        date: DateTime.parse(map['date']),
        isCorrect: map['isCorrect'] ?? true,
        suggestedName: map['suggestedName'],
      );
    }).toList();
  }

  // Método para eliminar un registro del historial
  Future<void> deletePlant(PlantRecord recordToDelete) async {
    final prefs = await SharedPreferences.getInstance();
    List<PlantRecord> history = await getHistory();

    // Filtramos la lista eliminando el registro que coincida
    history.removeWhere((plant) =>
        plant.imagePath == recordToDelete.imagePath &&
        plant.date == recordToDelete.date);

    // Guardamos la lista convertida de nuevo a JSON usando la misma lógica que usaste para guardar
    List<String> jsonList = history
        .map((plant) => jsonEncode({
              'imagePath': plant.imagePath,
              'plantName': plant.plantName,
              'date': plant.date.toIso8601String(),
              'isCorrect': plant.isCorrect,
              'suggestedName': plant.suggestedName,
            }))
        .toList();

    await prefs.setStringList('plant_history', jsonList);
  }
}
