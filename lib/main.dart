import 'package:flutter/material.dart';
//Import per l'uso di SystemChrome
import 'package:flutter/services.dart';

import 'core/widgets/decibel_meter_app.dart' as dma;

void main() {
  //Essendoci istruzioni prima della chiamata runApp() è necessario esplicitare ensureInitialized()
  WidgetsFlutterBinding.ensureInitialized();
  
  //Chiamata asincrona per forzare l'uso di portraitUp
  //Essendo asincrona .then(_) aspetta la fine di DeviceOrientation per lanciare l'app
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(const dma.DecibelMeterApp());
  });
}