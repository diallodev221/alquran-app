import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service pour gérer l'état de la connectivité
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Vérifie si l'appareil est connecté à Internet
  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final isConnected = result != ConnectivityResult.none;
      debugPrint('📡 Connection status: $isConnected');
      return isConnected;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  /// Stream pour écouter les changements de connectivité
  Stream<ConnectivityResult> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}
