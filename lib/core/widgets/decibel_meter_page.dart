import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';

import 'package:fnoise_meter/core/utils/decibel_colors.dart' as db_colors;
import 'package:fnoise_meter/core/utils/permission_handler_utility.dart';
import 'package:fnoise_meter/core/widgets/status_card.dart';
import 'package:fnoise_meter/core/widgets/decibel_display.dart';
import 'package:fnoise_meter/core/widgets/recording_button.dart';
import 'package:fnoise_meter/core/widgets/dialogs/error_dialog.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:noise_meter/noise_meter.dart';
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

  NoiseMeter? noiseMeter;
  StreamSubscription<NoiseReading>? noiseSubscription;
  Timer? keepAliveTimer;

  double currentDecibel = 0.0;
  double maxDecibel = 0.0;
  double minDecibel = 0.0;

  // Ascolta il comando di stop
  service.on('stopService').listen((event) {
    noiseSubscription?.cancel();
    noiseSubscription = null;

    keepAliveTimer?.cancel();
    keepAliveTimer = null;

    noiseMeter = null;
    service.stopSelf();
  });

  // Ascolta il comando di start
  service.on('startMeasuring').listen((event) async {
    try {
      noiseMeter = NoiseMeter();

      noiseSubscription = noiseMeter?.noise.listen(
        (NoiseReading reading) {
          currentDecibel = reading.meanDecibel;

          if (maxDecibel == 0.0 || currentDecibel > maxDecibel) {
            maxDecibel = currentDecibel;
          }

          if (minDecibel == 0.0 || currentDecibel < minDecibel) {
            minDecibel = currentDecibel;
          }

          // Aggiorna la notifica foreground
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "Misuratore Decibel",
              content: "${currentDecibel.toStringAsFixed(1)} dB",
            );
          }

          // Invia dati all'UI
          service.invoke('update', {
            'current': currentDecibel,
            'max': maxDecibel,
            'min': minDecibel,
          });
        },
        onError: (error) {
          service.invoke('error', {'message': error.toString()});
        },
      );
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
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, ('Errore inizializzazione: $e'));
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
        await Future.delayed(const Duration(milliseconds: 500));
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
                db_colors.getNoiseLevel(_currentDecibel),
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
                    buildStatCard('Minimo', _minDecibel, Color(0xFF388E3C)),
                    buildStatCard('Massimo', _maxDecibel, Color(0xFFE64A19)),
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
