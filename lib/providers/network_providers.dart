import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/network_service.dart';

/// Provider singleton pour le service réseau
final networkServiceProvider = Provider<NetworkService>((ref) {
  final service = NetworkService();
  
  // Dispose le service quand le provider est disposé
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Provider stream pour écouter les changements de statut
final networkStatusStreamProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(networkServiceProvider);
  return service.onStatusChanged;
});

/// Provider pour le statut réseau actuel (utilise le stream)
final networkStatusProvider = Provider<NetworkStatus>((ref) {
  final statusAsync = ref.watch(networkStatusStreamProvider);
  return statusAsync.when(
    data: (status) => status,
    loading: () => NetworkStatus.unknown,
    error: (_, __) => NetworkStatus.offline,
  );
});

/// Provider pour savoir si on est en ligne (booléen simple)
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkStatusProvider);
  return status.isOnline;
});

/// Provider pour savoir si on est offline
final isOfflineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkStatusProvider);
  return status.isOffline;
});

