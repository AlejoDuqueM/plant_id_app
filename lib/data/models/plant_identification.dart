import 'dart:io';

/// Máximo de fotos que acepta la API de Pl@ntNet por consulta.
const int kMaxPhotos = 5;

/// Órgano de la planta que muestra cada foto (valor de la API -> texto en pantalla).
/// Indicarlo mejora mucho la precisión, sobre todo en árboles y arbustos.
const Map<String, String> kOrganLabels = {
  'auto': 'Automático',
  'leaf': 'Hoja',
  'flower': 'Flor',
  'fruit': 'Fruto',
  'bark': 'Corteza',
  'habit': 'Planta completa',
  'other': 'Otro',
};

/// Una foto seleccionada junto con la parte de la planta que muestra.
class PlantPhoto {
  final File file;
  String organ;

  PlantPhoto(this.file, {this.organ = 'auto'});
}

/// Una posible coincidencia devuelta por la API.
class PlantMatch {
  final String scientificName;
  final String commonName;
  final String family;

  /// Confianza entre 0.0 y 1.0.
  final double score;

  const PlantMatch({
    required this.scientificName,
    required this.commonName,
    required this.family,
    required this.score,
  });

  int get percent => (score * 100).round();
}
