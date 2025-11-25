import 'package:permission_handler/permission_handler.dart';

/// Utility class per gestire i permessi del microfono
class PermissionHandlerUtility {
  /// Richiede il permesso del microfono
  /// Restituisce true se il permesso è stato concesso, false altrimenti
  static Future<PermissionResult> requestMicrophonePermission(Permission permissionType) async {
    final status = await permissionType.request();
    
    if (status.isGranted) {
      return PermissionResult.granted;
    } else if (status.isDenied) {
      return PermissionResult.denied;
    } else if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }
    
    return PermissionResult.denied;
  }

  /// Controlla se il permesso del microfono è già stato concesso
  static Future<bool> isMicrophonePermissionGranted(Permission permissionType) async {
    final status = await permissionType.status;
    return status.isGranted;
  }
  
  /// Apre le impostazioni dell'app
  static Future<void> openSettings() async {
    await openAppSettings();
  }
  
  /// Ottiene il messaggio da mostrare all'utente in base allo stato del permesso
  static String getPermissionMessage(PermissionResult result) {
    switch (result) {
      case PermissionResult.granted:
        return 'Permesso concesso';
      case PermissionResult.denied:
        return 'Permesso negato';
      case PermissionResult.permanentlyDenied:
        return 'Permesso negato permanentemente. Vai nelle impostazioni per abilitarlo.';
    }
  }
}

/// Enum per rappresentare il risultato della richiesta di permesso
enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
}