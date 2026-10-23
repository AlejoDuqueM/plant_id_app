import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/plant_identification.dart';
import '../../../data/models/plant_record.dart';
import '../../../data/services/plant_api_service.dart';
import '../../../services/plant_storage_service.dart';
import '../../../screens/library_screen.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final PlantStorageService _storageService = PlantStorageService();
  final PlantApiService _apiService = PlantApiService();
  final ImagePicker _picker = ImagePicker();

  // Estado
  bool _isLoading = false;
  final List<PlantPhoto> _photos = [];

  // Resultado de la identificación
  bool _identified = false; // ya se consultó la API con las fotos actuales
  List<PlantMatch> _matches = [];
  int _selectedMatch = 0; // coincidencia elegida (por defecto, la mejor)

  PlantMatch? get _current =>
      _matches.isEmpty ? null : _matches[_selectedMatch];

  bool get _canAddMore => _photos.length < kMaxPhotos;

  void _mostrarMensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  // Cuando cambian las fotos, el resultado anterior deja de ser válido
  void _limpiarResultado() {
    _identified = false;
    _matches = [];
    _selectedMatch = 0;
  }

  // ---------- Selección de fotos ----------

  Future<void> _addFromCamera() async {
    if (!_canAddMore) return;
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (!mounted || picked == null) return;

    setState(() {
      _photos.add(PlantPhoto(File(picked.path)));
      _limpiarResultado();
    });
  }

  Future<void> _addFromGallery() async {
    if (!_canAddMore) return;
    final remaining = kMaxPhotos - _photos.length;

    final picked = await _picker.pickMultiImage(
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (!mounted || picked.isEmpty) return;

    if (picked.length > remaining) {
      _mostrarMensaje('Solo se pueden usar $kMaxPhotos fotos por consulta.');
    }

    setState(() {
      for (final file in picked.take(remaining)) {
        _photos.add(PlantPhoto(File(file.path)));
      }
      _limpiarResultado();
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      _limpiarResultado();
    });
  }

  void _changeOrgan(int index, String organ) {
    setState(() {
      _photos[index].organ = organ;
      _limpiarResultado();
    });
  }

  // ---------- Identificación ----------

  Future<void> _identificar() async {
    if (_photos.isEmpty || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final matches = await _apiService.identifyPlant(_photos);
      if (!mounted) return;

      if (matches == null) {
        _mostrarMensaje('No se pudo identificar la planta. Intenta de nuevo.');
      } else {
        setState(() {
          _matches = matches;
          _selectedMatch = 0;
          _identified = true;
        });
        if (matches.isEmpty) {
          _mostrarMensaje(
              'No se encontraron coincidencias. Prueba con más fotos.');
        }
      }
    } catch (e) {
      debugPrint('Error al identificar la planta: $e');
      _mostrarMensaje('No se pudo identificar la planta. Intenta de nuevo.');
    } finally {
      // Se ejecuta siempre: así el spinner nunca se queda cargando para siempre
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- Guardado ----------

  void _mostrarDialogoSugerencia() {
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
                if (sugerencia.isNotEmpty && _photos.isNotEmpty) {
                  await _storageService.savePlant(
                    PlantRecord(
                      imagePath: _photos.first.file.path,
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
    ).then((_) => suggestionController.dispose());
  }

  Future<void> _guardarIdentificacionCorrecta() async {
    final match = _current;
    if (_photos.isEmpty || match == null) return;

    final messenger = ScaffoldMessenger.of(context);

    await _storageService.savePlant(
      PlantRecord(
        imagePath: _photos.first.file.path,
        plantName: match.commonName,
        commonName: match.commonName,
        scientificName: match.scientificName,
        family: match.family,
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

  // ---------- Interfaz ----------

  Widget _buildPhotoStrip() {
    if (_photos.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.green.shade50,
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_florist, size: 60, color: Colors.green),
            SizedBox(height: 8),
            Text('Ninguna imagen seleccionada',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final photo = _photos[index];
          return SizedBox(
            width: 130,
            child: Column(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        photo.file,
                        width: 130,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                          width: 130,
                          height: 130,
                          child: Icon(Icons.broken_image, size: 50),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: _isLoading ? null : () => _removePhoto(index),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child:
                              Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Qué parte de la planta muestra esta foto
                DropdownButton<String>(
                  value: photo.organ,
                  isExpanded: true,
                  isDense: true,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  items: kOrganLabels.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          if (value != null) _changeOrgan(index, value);
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResult() {
    if (_isLoading) {
      return const Column(
        children: [
          CircularProgressIndicator(color: Colors.green),
          SizedBox(height: 10),
          Text('Analizando planta...'),
        ],
      );
    }

    if (!_identified) {
      return const Text(
        'Agrega una o más fotos y pulsa "Identificar".',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
      );
    }

    final current = _current;
    if (current == null) {
      return const Text(
        'No se encontraron coincidencias.\nPrueba con más fotos (hoja, corteza, fruto o flor).',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      children: [
        Text(
          'Planta identificada:\n${current.commonName}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${current.scientificName} · ${current.percent}% de confianza',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        if (_matches.first.score < 0.4) ...[
          const SizedBox(height: 8),
          Text(
            'Confianza baja: agrega más fotos (hoja, corteza, fruto o flor) '
            'o revisa las otras opciones.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange[800], fontSize: 13),
          ),
        ],
        if (_matches.length > 1) ...[
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Otras posibilidades (toca para elegir):',
                style: TextStyle(color: Colors.grey)),
          ),
          for (var i = 0; i < _matches.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              selected: i == _selectedMatch,
              selectedColor: Colors.green[800],
              leading: Icon(i == _selectedMatch
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(_matches[i].commonName),
              subtitle: Text(_matches[i].scientificName),
              trailing: Text('${_matches[i].percent}%'),
              onTap: () => setState(() => _selectedMatch = i),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDecide = !_isLoading && _current != null;

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
                MaterialPageRoute(builder: (context) => const LibraryScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPhotoStrip(),
            const SizedBox(height: 8),
            Text(
              '${_photos.length} de $kMaxPhotos fotos',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Botones de Cámara y Galería (deshabilitados al cargar o llegar al máximo)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: (_isLoading || !_canAddMore) ? null : _addFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Cámara'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      (_isLoading || !_canAddMore) ? null : _addFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Consejo para mejorar la precisión
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                '💡 Para árboles y arbustos, usa 2 a 5 fotos de la misma planta: '
                'hoja, corteza, fruto o flor y la planta completa. '
                'Indica debajo de cada foto qué parte muestra.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (_photos.isEmpty || _isLoading) ? null : _identificar,
                icon: const Icon(Icons.search),
                label: Text(_photos.length > 1
                    ? 'Identificar con ${_photos.length} fotos'
                    : 'Identificar'),
              ),
            ),
            const SizedBox(height: 24),

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
                  _buildResult(),
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
                            canDecide ? _guardarIdentificacionCorrecta : null,
                      ),
                      const SizedBox(width: 20),

                      // Pulgar abajo: sugerir nombre
                      IconButton(
                        icon: const Icon(Icons.thumb_down, size: 30),
                        color: Colors.red,
                        onPressed: (_isLoading || _photos.isEmpty)
                            ? null
                            : _mostrarDialogoSugerencia,
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
