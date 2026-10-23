import 'dart:io';
import 'package:plant_id_app/data/services/plant_api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../../../data/models/plant_record.dart';
import '../../../services/plant_storage_service.dart';
import '../../../screens/library_screen.dart'; // Ajusta esta ruta si tu pantalla de biblioteca está en otra carpeta

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final PlantStorageService _storageService = PlantStorageService();
  final PlantApiService _apiService = PlantApiService();

  // 1. Variables de estado
  bool _isLoading = false;
  File? _selectedImage;
  String _detectedPlant = "Planta analizada";

  // Datos botánicos que devuelve la API
  String? _scientificName;
  String? _commonName;
  String? _family;

  // 2. Analizar la foto con la API de Pl@ntNet (con manejo de errores)
  Future<void> analizarFoto(File imagen) async {
    setState(() => _isLoading = true);

    try {
      final resultado = await _apiService.identifyPlant(imagen);

      if (resultado != null && mounted) {
        setState(() {
          // Asegúrate de que las llaves coincidan con lo que retorna tu PlantApiService
          _scientificName = resultado['scientificName'];
          _commonName = resultado['commonName'];
          _family = resultado['family'];
          _detectedPlant =
              _commonName ?? _scientificName ?? "Planta identificada";
        });

        debugPrint(
            "API Cargar - Científico: $_scientificName | Familia: $_family");
      }
    } catch (e) {
      debugPrint('Error al identificar la planta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('No se pudo identificar la planta. Intenta de nuevo.')),
        );
      }
    } finally {
      // Se ejecuta siempre: así el spinner nunca se queda cargando para siempre
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. Seleccionar imagen (cámara o galería) y analizarla
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      setState(() {
        _selectedImage = imageFile;
      });

      // Dispara el análisis automático
      await analizarFoto(imageFile);
    }
  }

  void _mostrarDialogoSugerencia(BuildContext context) {
    final TextEditingController suggestionController = TextEditingController();
    String tipoNombre = 'Común'; // Por defecto

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Sugerir nombre correcto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: suggestionController,
                decoration: const InputDecoration(
                    hintText: 'Ej: Bromelia o Guzmania lingulata'),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('¿Qué tipo de nombre es?'),
                  DropdownButton<String>(
                    value: tipoNombre,
                    items: const [
                      DropdownMenuItem(value: 'Común', child: Text('Común')),
                      DropdownMenuItem(
                          value: 'Científico', child: Text('Científico')),
                    ],
                    onChanged: (value) {
                      setStateDialog(() {
                        tipoNombre = value!;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Guardamos referencias ANTES del await para evitar
                // el aviso use_build_context_synchronously
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(this.context);

                final sugerencia = suggestionController.text.trim();
                if (sugerencia.isNotEmpty && _selectedImage != null) {
                  await _storageService.savePlant(
                    PlantRecord(
                      imagePath: _selectedImage!.path,
                      plantName: tipoNombre == 'Científico'
                          ? 'Planta analizada'
                          : sugerencia,
                      commonName: tipoNombre == 'Común' ? sugerencia : null,
                      scientificName: tipoNombre == 'Científico'
                          ? sugerencia
                          : 'No especificado',
                      date: DateTime.now(),
                      isCorrect: false,
                      suggestedName: sugerencia,
                    ),
                  );
                }

                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                      content: Text('Sugerencia guardada como $tipoNombre')),
                );
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarIdentificacionCorrecta() async {
    if (_selectedImage == null) return;

    final messenger = ScaffoldMessenger.of(context);

    debugPrint("Guardando -> Científico: $_scientificName, Familia: $_family");

    await _storageService.savePlant(
      PlantRecord(
        imagePath: _selectedImage!.path,
        plantName: _commonName ?? _scientificName ?? _detectedPlant,
        commonName: _commonName,
        scientificName: _scientificName ?? 'Científico no disponible',
        family: _family ?? 'Familia no disponible',
        date: DateTime.now(),
        isCorrect: true,
        light: 'Luz solar indirecta o semisombra',
        watering: 'Riego moderado según humedad del sustrato',
        careTips: 'Mantener un buen drenaje y limpieza de hojas.',
      ),
    );

    messenger.showSnackBar(
      const SnackBar(content: Text('¡Guardado en tu biblioteca!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlantID Gratis'),
        backgroundColor: Colors.green[700],
        actions: [
          // Botón para ir a la Biblioteca / Historial
          IconButton(
            icon: const Icon(Icons.collections_bookmark),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LibraryScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Contenedor de la imagen o estado inicial
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.green.shade50,
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_florist,
                            size: 60, color: Colors.green),
                        SizedBox(height: 8),
                        Text('Ninguna imagen seleccionada',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            // Botones de Cámara y Galería (deshabilitados mientras carga)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Cámara'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo),
                  label: const Text('Galería'),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Resultado de la planta identificada
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  // Spinner mientras la API analiza; resultado cuando termina
                  _isLoading
                      ? const Column(
                          children: [
                            CircularProgressIndicator(color: Colors.green),
                            SizedBox(height: 10),
                            Text('Analizando planta...'),
                          ],
                        )
                      : Text(
                          'Planta identificada:\n$_detectedPlant',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                  const SizedBox(height: 15),
                  const Divider(),
                  const Text('¿Es correcta esta identificación?',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pulgar arriba: guardar
                      IconButton(
                        icon: const Icon(Icons.thumb_up, size: 30),
                        color: Colors.green,
                        onPressed:
                            _isLoading ? null : _guardarIdentificacionCorrecta,
                      ),
                      const SizedBox(width: 20),

                      // Pulgar abajo: sugerir nombre
                      IconButton(
                        icon: const Icon(Icons.thumb_down, size: 30),
                        color: Colors.red,
                        onPressed: _isLoading
                            ? null
                            : () => _mostrarDialogoSugerencia(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
