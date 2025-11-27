import 'dart:async';
import 'package:noise_meter/noise_meter.dart';

/// Classe che gestisce la logica di misurazione dei decibel
class DecibelService {
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;

  double _currentDecibel = 0.0;
  double _maxDecibel = 0.0;
  double _minDecibel = 0.0;

  // Callback per aggiornamenti
  Function(double current, double max, double min)? onUpdate;
  Function(String error)? onError;

  // Getter per i valori correnti
  double get currentDecibel => _currentDecibel;
  double get maxDecibel => _maxDecibel;
  double get minDecibel => _minDecibel;
  bool get isListening => _noiseSubscription != null;

  /// Inizia la misurazione dei decibel
  Future<void> startMeasuring() async {
    try {
      // Reset dei valori
      _currentDecibel = 0.0;
      _maxDecibel = 0.0;
      _minDecibel = 0.0;

      // Inizializza il noise meter
      _noiseMeter = NoiseMeter();

      // Sottoscrivi allo stream
      _noiseSubscription = _noiseMeter?.noise.listen(
        (NoiseReading reading) {
          _updateDecibel(reading.meanDecibel);
        },
        onError: (error) {
          onError?.call(error.toString());
        },
      );
    } catch (e) {
      onError?.call(e.toString());
      rethrow;
    }
  }

  /// Aggiorna i valori dei decibel
  void _updateDecibel(double value) {
    _currentDecibel = value;

    // Aggiorna il massimo
    if (_maxDecibel == 0.0 || _currentDecibel > _maxDecibel) {
      _maxDecibel = _currentDecibel;
    }

    // Aggiorna il minimo
    if (_minDecibel == 0.0 || _currentDecibel < _minDecibel) {
      _minDecibel = _currentDecibel;
    }

    // Notifica l'aggiornamento
    onUpdate?.call(_currentDecibel, _maxDecibel, _minDecibel);
  }

  /// Ferma la misurazione
  Future<void> stopMeasuring() async {
    await _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _noiseMeter = null;
  }

  /// Reset dei valori (utile per ricominciare)
  void reset() {
    _currentDecibel = 0.0;
    _maxDecibel = 0.0;
    _minDecibel = 0.0;
  }

  /// Dispose delle risorse
  void dispose() {
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _noiseMeter = null;
  }
}
