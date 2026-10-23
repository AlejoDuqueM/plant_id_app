import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class PlantApiService {
  static const String _apiKey =
      '2b10O4ILAppel3kMdDeGNiRGQO'; // Tu API Key real del Dashboard
  static const String _baseUrl = 'https://my-api.plantnet.org/v2/identify/all';

  Future<Map<String, dynamic>?> identifyPlant(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl?api-key=$_apiKey'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('images', imageFile.path),
      );
      request.fields['organs'] = 'auto';

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['results'] != null && data['results'].isNotEmpty) {
          var bestMatch = data['results'][0];
          var species = bestMatch['species'];

          String scientificName =
              species['scientificNameWithoutAuthor'] ?? 'Desconocida';

          List commonNames = species['commonNames'] ?? [];
          String commonName =
              commonNames.isNotEmpty ? commonNames[0] : scientificName;

          String family = species['family']?['scientificNameWithoutAuthor'] ??
              'General / Ornamental';

          return {
            'scientificName': scientificName,
            'commonName': commonName,
            'family': family,
          };
        }
      } else {
        print('Error en la API de Pl@ntNet: ${response.body}');
      }
    } catch (e) {
      print('Excepción de red: $e');
    }
    return null;
  }
}
