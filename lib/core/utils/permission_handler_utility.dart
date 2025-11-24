import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHandlerUtility {
  // Metodo statico per richiedere il permesso.
  // Ritorna true se il permesso è concesso, false altrimenti.
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    final status = await Permission.microphone.request();

    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      _showPermissionDialog(context, 'Permesso negato');
      return false;
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog(
          context, 'Permesso negato permanentemente. Vai nelle impostazioni per abilitarlo.');
      return false;
    }
    return false;
  }

  // Metodo per mostrare il dialogo di permesso (richiede il BuildContext).
  static void _showPermissionDialog(BuildContext context, String message) {
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
                // openAppSettings() è un metodo della libreria permission_handler
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Impostazioni'),
            ),
        ],
      ),
    );
  }
}