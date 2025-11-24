import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import '../utils/decibel_colors.dart' as db_colors;
import '../../styles/light_theme.dart' as db_light_theme;

class DecibelMeterPage extends StatefulWidget {
  //coostruttore del Widget
  const DecibelMeterPage({super.key});

  @override
  State<DecibelMeterPage> createState() => _DecibelMeterPageState();
}

class _DecibelMeterPageState extends State<DecibelMeterPage> {
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  
  double _currentDecibel = 0.0;
  double _maxDecibel = 0.0;
  double _minDecibel = 0.0;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _noiseMeter = NoiseMeter();
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _startRecording();
    } else if (status.isDenied) {
      _showPermissionDialog('Permesso negato');
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog('Permesso negato permanentemente. Vai nelle impostazioni per abilitarlo.');
    }
  }

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permesso Microfono'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (message.contains('impostazioni'))
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Impostazioni'),
            ),
        ],
      ),
    );
  }

  void _startRecording() {
    try {
      _noiseSubscription = _noiseMeter?.noise.listen(
        (NoiseReading reading) {
          setState(() {
            _currentDecibel = reading.meanDecibel;
            
            if (_maxDecibel == 0.0 || _currentDecibel > _maxDecibel) {
              _maxDecibel = _currentDecibel;
            }
            
            if (_minDecibel == 0.0 || _currentDecibel < _minDecibel) {
              _minDecibel = _currentDecibel;
            }
          });
        },
        onError: (error) {
          _stopRecording();
          _showPermissionDialog('Errore nella lettura del microfono: $error');
        },
      );
      
      setState(() {
        _isRecording = true;
        _maxDecibel = 0.0;
        _minDecibel = 0.0;
      });
    } catch (e) {
      _showPermissionDialog('Errore: $e');
    }
  }

  void _stopRecording() {
    _noiseSubscription?.cancel();
    setState(() {
      _isRecording = false;
    });
  }

  void _toggleRecording() async {
    if (_isRecording) {
      _stopRecording();
    } else {
      await _requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Misuratore Decibel'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: db_colors.getDecibelColor(_currentDecibel).withOpacity(0.2),
                  border: Border.all(
                    color: db_colors.getDecibelColor(_currentDecibel),
                    width: 4,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentDecibel.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 60,
                        //fontWeight: FontWeight.bold,
                        color: db_colors.getDecibelColor(_currentDecibel),
                      ),
                    ),
                    const Text(
                      'dB',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                db_colors.getNoiseLevel(_currentDecibel),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              if (_isRecording) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard('Minimo', _minDecibel, Colors.blue),
                    _buildStatCard('Massimo', _maxDecibel, Colors.red),
                  ],
                ),
                const SizedBox(height: 30),
              ],
              ElevatedButton.icon(
                onPressed: _toggleRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? 'Ferma' : 'Inizia Misurazione'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, double value, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${value.toStringAsFixed(1)} dB',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}