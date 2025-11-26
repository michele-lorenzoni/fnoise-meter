import 'package:flutter/material.dart';
import 'package:fnoise_meter/core/utils/permission_handler_utility.dart';

class PermissionDialog extends StatelessWidget {
  final String message;
  final bool isPermanentlyDenied;

  const PermissionDialog({
    super.key,
    required this.message,
    required this.isPermanentlyDenied,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
    );
  }

  // Metodo statico per mostrare il dialog
  static Future<void> show(
    BuildContext context,
    String message,
    bool isPermanentlyDenied,
  ) {
    return showDialog(
      context: context,
      builder: (context) => PermissionDialog(
        message: message,
        isPermanentlyDenied: isPermanentlyDenied,
      ),
    );
  }
}
