import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Service robuste pour gérer la connectivité réseau et l'accès Internet
/// Utilise les meilleures pratiques pour détecter réellement l'accès Internet
class NetworkService {
  final Connectivity _connectivity = Connectivity();

  // Stream controller pour l'état réseau
  final _networkStatusController = StreamController<NetworkStatus>.broadcast();

  // Cache de l'état actuel
  NetworkStatus _currentStatus = NetworkStatus.unknown;

  // Timer pour les vérifications périodiques
  Timer? _periodicCheckTimer;

  // Flag pour éviter les vérifications multiples simultanées
  bool _isChecking = false;

  NetworkService() {
    _init();
  }

  /// Initialise le service
  void _init() {
    // Initialiser avec unknown
    _currentStatus = NetworkStatus.unknown;

    // Vérifier l'état initial
    _checkInitialStatus();

    // Écouter les changements de connectivité
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      debugPrint('📡 Connectivity changed: $result');
      _handleConnectivityChange(result);
    });

    // Vérification périodique pour détecter les faux positifs
    _periodicCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _verifyInternetAccess(),
    );
  }

  /// Vérifie l'état initial
  Future<void> _checkInitialStatus() async {
    try {
      final result = await _connectivity.checkConnectivity();
      await _handleConnectivityChange(result);
    } catch (e) {
      debugPrint('❌ Error checking initial connectivity: $e');
      _updateStatus(NetworkStatus.offline);
    }
  }

  /// Gère les changements de connectivité
  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      _updateStatus(NetworkStatus.offline);
      return;
    }

    // Si on a une connexion, vérifier l'accès Internet réel
    await _verifyInternetAccess();
  }

  /// Vérifie réellement l'accès Internet (pas seulement la connexion réseau)
  Future<void> _verifyInternetAccess() async {
    if (_isChecking) return;

    _isChecking = true;

    try {
      // Utiliser un serveur fiable (Google DNS ou un serveur de l'API)
      final result = await InternetAddress.lookup(
        'api.alquran.cloud',
      ).timeout(const Duration(seconds: 5));

      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      if (isConnected) {
        // Double vérification avec un ping HTTP léger
        try {
          final dio = Dio(
            BaseOptions(
              baseUrl: 'https://api.alquran.cloud/v1',
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );

          // Faire une requête HEAD légère pour vérifier l'accès
          await dio.head('/surah').timeout(const Duration(seconds: 5));

          _updateStatus(NetworkStatus.online);
        } on DioException catch (e) {
          // Si c'est une erreur réseau, on est offline
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError) {
            debugPrint('⚠️ HTTP check failed (offline): ${e.message}');
            _updateStatus(NetworkStatus.offline);
          } else {
            // Autres erreurs (404, 500, etc.) signifient qu'on est connecté
            _updateStatus(NetworkStatus.online);
          }
        } catch (e) {
          debugPrint('⚠️ HTTP check failed: $e');
          _updateStatus(NetworkStatus.offline);
        }
      } else {
        _updateStatus(NetworkStatus.offline);
      }
    } on SocketException catch (_) {
      _updateStatus(NetworkStatus.offline);
    } on TimeoutException catch (_) {
      _updateStatus(NetworkStatus.offline);
    } catch (e) {
      debugPrint('❌ Error verifying internet access: $e');
      // En cas d'erreur, on assume offline pour sécurité
      _updateStatus(NetworkStatus.offline);
    } finally {
      _isChecking = false;
    }
  }

  /// Met à jour le statut et notifie les listeners
  void _updateStatus(NetworkStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _networkStatusController.add(status);
      debugPrint('🌐 Network status updated: $status');
    }
  }

  /// Stream des changements d'état réseau
  Stream<NetworkStatus> get onStatusChanged => _networkStatusController.stream;

  /// Obtient l'état actuel (synchrone)
  NetworkStatus get currentStatus => _currentStatus;

  /// Vérifie si on est en ligne (asynchrone, vérifie réellement)
  Future<bool> isOnline() async {
    await _verifyInternetAccess();
    return _currentStatus == NetworkStatus.online;
  }

  /// Vérifie rapidement si on a une connexion réseau (sans vérifier Internet)
  Future<bool> hasNetworkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Dispose les ressources
  void dispose() {
    _periodicCheckTimer?.cancel();
    _networkStatusController.close();
  }
}

/// Statut de la connexion réseau
enum NetworkStatus {
  /// État inconnu (en cours de vérification)
  unknown,

  /// En ligne avec accès Internet
  online,

  /// Hors ligne (pas de connexion ou pas d'accès Internet)
  offline,
}

/// Extension pour convertir NetworkStatus en booléen
extension NetworkStatusExtension on NetworkStatus {
  bool get isOnline => this == NetworkStatus.online;
  bool get isOffline => this == NetworkStatus.offline;
  bool get isUnknown => this == NetworkStatus.unknown;
}
