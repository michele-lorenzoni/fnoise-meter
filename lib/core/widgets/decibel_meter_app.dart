import 'package:flutter/material.dart';

import 'decibel_meter_page.dart';

class DecibelMeterApp extends StatelessWidget {
  //coostruttore del Widget
  const DecibelMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Decibel Meter',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const DecibelMeterPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
