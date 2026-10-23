import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/plant_identification.dart';

class PlantApiService {
  // La API key NO va escrita en el código (el repositorio es público).
  // Se entrega al compilar/ejecutar:
  //   flutter run --dart-define=PLANTNET_API_KEY=tu_clave
  //   flutter build apk --dart-define=PLANTNET_API_KEY=tu_clave
  static const String _apiKey = String.fromEnvironment('PLANTNET_API_KEY');
  static const String _baseUrl = 'https://my-api.plantnet.org/v2/identify/all';

  /// Identifica la planta usando una o varias fotos (hasta [kMaxPhotos]).
  ///
  /// Devuelve las coincidencias ordenadas de mayor a menor confianza.
  /// Devuelve `null` si hubo un error (sin clave, sin internet, API caída)
  /// y una lista vacía si la consulta funcionó pero no hubo coincidencias.
  Future<List<PlantMatch>?> identifyPlant(List<PlantPhoto> photos) async {
    if (_apiKey.isEmpty) {
      debugPrint(
          'Falta la API key. Ejecuta con --dart-define=PLANTNET_API_KEY=tu_clave');
      return null;
    }
    if (photos.isEmpty) return [];

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'api-key': _apiKey,
        'lang': 'es', // nombres comunes en español cuando existan
        'nb-results': '5',
      });

      final request = http.MultipartRequest('POST', uri);

      // La API espera un campo "organs" por cada imagen, en el mismo orden.
      // MultipartRequest.fields no permite repetir claves, así que cada
      // "organs" se agrega como parte de texto sin nombre de archivo, que el
      // servidor lee como un campo normal.
      for (final photo in photos.take(kMaxPhotos)) {
        request.files.add(
          await http.MultipartFile.fromPath('images', photo.file.path),
        );
        request.files.add(
          http.MultipartFile.fromString('organs', photo.organ),
        );
      }

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = (data['results'] as List?) ?? [];

        return results.map<PlantMatch>((r) {
          final species = r['species'] ?? {};

          final String scientificName =
              species['scientificNameWithoutAuthor'] ?? 'Desconocida';
          final List commonNames = species['commonNames'] ?? [];
          final String commonName =
              commonNames.isNotEmpty ? commonNames[0] : scientificName;
          final String family =
              species['family']?['scientificNameWithoutAuthor'] ??
                  'General / Ornamental';

          return PlantMatch(
            scientificName: scientificName,
            commonName: commonName,
            family: family,
            score: (r['score'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();
      } else {
        debugPrint(
            'Error en la API de Pl@ntNet (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Excepción de red: $e');
    }
    return null;
  }
}
