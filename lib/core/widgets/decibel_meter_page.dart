import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';

import 'package:fnoise_meter/core/utils/decibel_colors.dart';
import 'package:fnoise_meter/core/utils/permission_handler_utility.dart';
import 'package:fnoise_meter/core/widgets/status_card.dart';
import 'package:fnoise_meter/core/widgets/decibel_display.dart';
import 'package:fnoise_meter/core/widgets/recording_button.dart';
import 'package:fnoise_meter/core/widgets/dialogs/error_dialog.dart';
import 'package:fnoise_meter/core/widgets/dialogs/permission_dialog.dart';
import 'package:fnoise_meter/core/utils/decibel_service.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// ==========================================
// INIZIALIZZAZIONE SERVIZIO BACKGROUND
// ==========================================

Future<void> initializeDecibelService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'decibel_meter_channel',
    'Decibel Meter Service',
    description: 'Questo canale è usato per il servizio di misurazione decibel',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStartDecibelService,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      onStart: onStartDecibelService,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'decibel_meter_channel',
      initialNotificationTitle: 'Misuratore Decibel',
      initialNotificationContent: 'In attesa di iniziare...',
      foregroundServiceNotificationId: 888,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ==========================================
// SERVIZIO BACKGROUND
// ==========================================

@pragma('vm:entry-point')
void onStartDecibelService(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // Usa DecibelService invece di gestire manualmente
  final decibelService = DecibelService();
  Timer? keepAliveTimer;

  // Configura i callback
  decibelService.onUpdate = (current, max, min) {
    // Aggiorna la notifica foreground
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Misuratore Decibel",
        content: "${current.toStringAsFixed(1)} dB",
      );
    }

    // Invia dati all'UI
    service.invoke('update', {'current': current, 'max': max, 'min': min});
  };

  decibelService.onError = (error) {
    service.invoke('error', {'message': error});
  };

  // NUOVO: Rispondi alle richieste di stato
  service.on('requestState').listen((event) {
    final isRecording = decibelService.isListening;
    service.invoke('stateResponse', {
      'isRecording': isRecording,
      'current': decibelService.currentDecibel,
      'max': decibelService.maxDecibel,
      'min': decibelService.minDecibel,
    });
  });

  // Ascolta il comando di stop
  service.on('stopService').listen((event) {
    decibelService.dispose();
    keepAliveTimer?.cancel();
    keepAliveTimer = null;
    service.stopSelf();
  });

  // Ascolta il comando di start
  service.on('startMeasuring').listen((event) async {
    try {
      await decibelService.startMeasuring();
    } catch (e) {
      service.invoke('error', {'message': e.toString()});
    }
  });

  // Timer per mantenere il servizio attivo
  keepAliveTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Servizio attivo
      }
    }
  });
}

// ==========================================
// UI - PAGINA PRINCIPALE
// ==========================================

class DecibelMeterPage extends StatefulWidget {
  const DecibelMeterPage({super.key});

  @override
  State<DecibelMeterPage> createState() => _DecibelMeterPageState();
}

class _DecibelMeterPageState extends State<DecibelMeterPage> {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  double _currentDecibel = 0.0;
  double _maxDecibel = 0.0;
  double _minDecibel = 0.0;
  bool _isRecording = false;
  bool _serviceInitialized = false;

  @override
  void initState() {
    super.initState();

    _initializeService();

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid = const AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    var initializationSettingsIOS = const DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Ascolta gli aggiornamenti dal servizio background
    FlutterBackgroundService().on('update').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _currentDecibel = event['current'] ?? 0.0;
          _maxDecibel = event['max'] ?? 0.0;
          _minDecibel = event['min'] ?? 0.0;
        });
      }
    });

    // NUOVO: Ascolta la risposta dello stato
    FlutterBackgroundService().on('stateResponse').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _isRecording = event['isRecording'] ?? false;
          _currentDecibel = event['current'] ?? 0.0;
          _maxDecibel = event['max'] ?? 0.0;
          _minDecibel = event['min'] ?? 0.0;
        });
      }
    });

    // Ascolta gli errori dal servizio background
    FlutterBackgroundService().on('error').listen((event) {
      if (event != null && mounted) {
        ErrorDialog.show(context, (event['message'] ?? 'Errore sconosciuto'));
        _stopRecording();
      }
    });
  }

  Future<void> _initializeService() async {
    try {
      await initializeDecibelService();
      if (!mounted) return;
      setState(() {
        _serviceInitialized = true;
      });

      // NUOVO: Controlla se il servizio è già in esecuzione
      await _checkServiceState();
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, ('Errore inizializzazione: $e'));
    }
  }

  // NUOVO: Metodo per verificare lo stato del servizio
  Future<void> _checkServiceState() async {
    final isRunning = await FlutterBackgroundService().isRunning();

    if (isRunning) {
      // Il servizio è attivo, richiedi lo stato
      FlutterBackgroundService().invoke('requestState');

      // Aspetta un momento per la risposta
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  void dispose() {
    if (_isRecording) {
      FlutterBackgroundService().invoke('stopService');
    }
    super.dispose();
  }

  void _showPermissionDialog(PermissionResult result) {
    final message = PermissionHandlerUtility.getPermissionMessage(result);
    final isPermanentlyDenied = result == PermissionResult.permanentlyDenied;

    PermissionDialog.show(context, message, isPermanentlyDenied);
  }

  Future<void> _startRecording() async {
    if (!_serviceInitialized) {
      const message = 'Servizio non inizializzato. Riprova tra poco.';
      ErrorDialog.show(context, message);
      return;
    }

    try {
      final isRunning = await FlutterBackgroundService().isRunning();

      if (!isRunning) {
        await FlutterBackgroundService().startService();

        // Aspetta che il servizio sia effettivamente pronto
        int attempts = 0;
        while (attempts < 10) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (await FlutterBackgroundService().isRunning()) {
            break;
          }
          attempts++;
        }
      }

      FlutterBackgroundService().invoke('startMeasuring');

      setState(() {
        _isRecording = true;
        _maxDecibel = 0.0;
        _minDecibel = 0.0;
      });
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, 'Errore avvio: $e');
    }
  }

  void _stopRecording() {
    FlutterBackgroundService().invoke('stopService');

    setState(() {
      _isRecording = false;
      _currentDecibel = 0.0;
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _stopRecording();
    } else {
      final micResult = await PermissionHandlerUtility.requestPermission(
        Permission.microphone,
      );

      if (micResult != PermissionResult.granted) {
        _showPermissionDialog(micResult);
        return;
      }

      await PermissionHandlerUtility.requestPermission(Permission.notification);

      await _startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                getNoiseLevel(_currentDecibel),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              if (_isRecording)
                const Text(
                  'In esecuzione in background',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (!_serviceInitialized)
                const Text(
                  'Inizializzazione servizio...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const SizedBox(height: 30),
              if (_isRecording) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StatCard(
                      label: 'Minimo',
                      value: _minDecibel,
                      color: Color(0xFF388E3C),
                    ),
                    StatCard(
                      label: 'Massimo',
                      value: _maxDecibel,
                      color: Color(0xFFE64A19),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
              RecordingButton(
                isRecording: _isRecording,
                serviceInitialized: _serviceInitialized,
                onPressed: _toggleRecording,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
