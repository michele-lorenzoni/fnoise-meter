import 'package:flutter/material.dart';

Color getDecibelColor(double db) {
  if (db < 50) return Colors.green.shade700;
  if (db < 70) return Colors.yellow.shade700;
  if (db < 90) return Colors.orange.shade700;
  return Colors.red.shade700;
}

String getNoiseLevel(double db) {
  if (db < 30) return 'Molto silenzioso';
  if (db < 50) return 'Silenzioso';
  if (db < 70) return 'Moderato';
  if (db < 90) return 'Rumoroso';
  if (db < 110) return 'Molto rumoroso';
  return 'Estremamente rumoroso';
}
