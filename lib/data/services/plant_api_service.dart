import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PlantApiService {
  // La API key ya NO va escrita en el código (el repositorio es público).
  // Se entrega al compilar/ejecutar:
  //   flutter run --dart-define=PLANTNET_API_KEY=tu_clave
  //   flutter build apk --dart-define=PLANTNET_API_KEY=tu_clave
  static const String _apiKey = String.fromEnvironment('PLANTNET_API_KEY');
  static const String _baseUrl = 'https://my-api.plantnet.org/v2/identify/all';

  Future<Map<String, dynamic>?> identifyPlant(File imageFile) async {
    if (_apiKey.isEmpty) {
      debugPrint(
          'Falta la API key. Ejecuta con --dart-define=PLANTNET_API_KEY=tu_clave');
      return null;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl?api-key=$_apiKey'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('images', imageFile.path),
      );
      request.fields['organs'] = 'auto';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['results'] != null && data['results'].isNotEmpty) {
          final bestMatch = data['results'][0];
          final species = bestMatch['species'];

          final String scientificName =
              species['scientificNameWithoutAuthor'] ?? 'Desconocida';

          final List commonNames = species['commonNames'] ?? [];
          final String commonName =
              commonNames.isNotEmpty ? commonNames[0] : scientificName;

          final String family =
              species['family']?['scientificNameWithoutAuthor'] ??
                  'General / Ornamental';

          return {
            'scientificName': scientificName,
            'commonName': commonName,
            'family': family,
          };
        }
      } else {
        debugPrint('Error en la API de Pl@ntNet: ${response.body}');
      }
    } catch (e) {
      debugPrint('Excepción de red: $e');
    }
    return null;
  }
}
