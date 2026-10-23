class PlantRecord {
  final String imagePath;
  final String plantName;
  final String? commonName;
  final String? scientificName;
  final String? family;
  final String? light;
  final String? watering;
  final String? careTips;
  final DateTime date;
  final bool isCorrect;
  final String? suggestedName;

  PlantRecord({
    required this.imagePath,
    required this.plantName,
    this.commonName,
    this.scientificName,
    this.family,
    this.light,
    this.watering,
    this.careTips,
    required this.date,
    required this.isCorrect,
    this.suggestedName,
  });

  // Convierte el objeto a JSON para guardarlo en SharedPreferences
  Map<String, dynamic> toJson() => {
        'imagePath': imagePath,
        'plantName': plantName,
        'commonName': commonName,
        'scientificName': scientificName,
        'family': family,
        'light': light,
        'watering': watering,
        'careTips': careTips,
        'date': date.toIso8601String(),
        'isCorrect': isCorrect,
        'suggestedName': suggestedName,
      };

  // Crea el objeto PlantRecord a partir del JSON almacenado
  factory PlantRecord.fromJson(Map<String, dynamic> json) => PlantRecord(
        imagePath: json['imagePath'] ?? '',
        plantName: json['plantName'] ?? 'Desconocida',
        commonName: json['commonName'],
        scientificName: json['scientificName'],
        family: json['family'],
        light: json['light'],
        watering: json['watering'],
        careTips: json['careTips'],
        date: json['date'] != null
            ? DateTime.parse(json['date'])
            : DateTime.now(),
        isCorrect: json['isCorrect'] ?? true,
        suggestedName: json['suggestedName'],
      );
}
