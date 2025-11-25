import 'package:flutter/material.dart';
import 'dart:async';

import 'package:fnoise_meter/core/utils/decibel_colors.dart' as db_colors;
import 'package:fnoise_meter/core/utils/permission_handler_utility.dart';
import 'package:fnoise_meter/core/utils/notification_service.dart';

import 'package:fnoise_meter/core/widgets/status_card.dart';
import 'package:fnoise_meter/core/widgets/decibel_display.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

class DecibelMeterPage extends StatefulWidget {
  const DecibelMeterPage({super.key});

  @override
  State<DecibelMeterPage> createState() => _DecibelMeterPageState();
}

class _DecibelMeterPageState extends State<DecibelMeterPage> {
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  
  double _currentDecibel = 0.0;
  double _maxDecibel = 0.0;
  double _minDecibel = 0.0;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _noiseMeter = NoiseMeter();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true, // Richiedi il permesso per gli alert
      requestBadgePermission: true, // Richiedi il permesso per il badge dell'app
      requestSoundPermission: true, // Richiedi il permesso per il suono
    );
    var initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    super.dispose();
  }

  /// Mostra un dialogo con il messaggio appropriato per il permesso
  void _showPermissionDialog(PermissionResult result) {
    final message = PermissionHandlerUtility.getPermissionMessage(result);
    final isPermanentlyDenied = result == PermissionResult.permanentlyDenied;
    
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
          if (isPermanentlyDenied)
            TextButton(
              onPressed: () {
                PermissionHandlerUtility.openSettings();
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

            if (_currentDecibel >= 50) {
              showSimpleNotification(flutterLocalNotificationsPlugin);
            }
          });
        },
        onError: (error) {
          _stopRecording();
          _showErrorDialog('Errore nella lettura del microfono: $error');
        },
      );
      
      setState(() {
        _isRecording = true;
        _maxDecibel = 0.0;
        _minDecibel = 0.0;
      });
    } catch (e) {
      _showErrorDialog('Errore: $e');
    }
  }

  void _stopRecording() {
    _noiseSubscription?.cancel();
    setState(() {
      _isRecording = false;
      _currentDecibel = 0.0;
    });
  }

  void _toggleRecording() async {
    if (_isRecording) {
      _stopRecording();
    } else {
      // Prima richiedi il permesso del microfono
      final micResult = await PermissionHandlerUtility.requestPermission(Permission.microphone);
      
      if (micResult != PermissionResult.granted) {
        _showPermissionDialog(micResult);
        return; // Esci se il permesso non è concesso
      }
      
      // Poi richiedi il permesso delle notifiche
      await PermissionHandlerUtility.requestPermission(Permission.notification);
      
      // Infine avvia la registrazione
      _startRecording();
    }
  }

  /// Mostra un dialogo per errori generici
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Errore'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
              DecibelDisplay(
                    currentDecibel: _currentDecibel,
                    isRecording: _isRecording,
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
                    buildStatCard('Minimo', _minDecibel, Colors.blue),
                    buildStatCard('Massimo', _maxDecibel, Colors.red),
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
}