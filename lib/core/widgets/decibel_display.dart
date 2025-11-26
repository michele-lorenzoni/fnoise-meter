import 'package:flutter/material.dart';
import 'package:fnoise_meter/core/utils/decibel_colors.dart' as db_colors;

class DecibelDisplay extends StatelessWidget {
  // 1. Definisci i campi che riceveranno i dati esterni
  final double currentDecibel;
  final bool isRecording;

  // 2. Definisci il costruttore per richiedere i dati
  const DecibelDisplay({
    super.key,
    required this.currentDecibel,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(125),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // ... Altre proprietà di BoxDecoration
          color: db_colors.getDecibelColor(currentDecibel).withOpacity(0.2),
          border: Border.all(
            color: db_colors.getDecibelColor(currentDecibel),
            width: 4,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ... Contenuto interno
            Text(
              isRecording ? currentDecibel.toStringAsFixed(1) : '0.0',
              style: TextStyle(
                fontSize: 60,
                //color: db_colors.getDecibelColor(currentDecibel),
              ),
            ),
            const Text('dB', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}
