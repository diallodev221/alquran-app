import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/network_providers.dart';
import '../theme/app_colors.dart';
import '../services/network_service.dart';

/// Banner amélioré qui affiche l'état de la connexion Internet avec UX optimale
class ConnectivityBanner extends ConsumerStatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  NetworkStatus _previousStatus = NetworkStatus.unknown;
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();

    // Controller pour l'animation de slide/fade
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
    );

    // Controller pour l'animation de pulsation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _retryConnection() async {
    if (_isReconnecting) return;

    setState(() => _isReconnecting = true);
    HapticFeedback.mediumImpact();

    final networkService = ref.read(networkServiceProvider);
    await networkService.isOnline();

    if (mounted) {
      setState(() => _isReconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkStatus = ref.watch(networkStatusProvider);
    final isOffline = networkStatus.isOffline;
    final isOnline = networkStatus.isOnline;
    final isUnknown = networkStatus.isUnknown;

    // Détecter les changements de statut pour les animations
    if (_previousStatus != networkStatus) {
      if (isOffline && _previousStatus != NetworkStatus.offline) {
        _slideController.forward();
        HapticFeedback.lightImpact();
      } else if (isOnline && _previousStatus != NetworkStatus.online) {
        _slideController.reverse();
        HapticFeedback.selectionClick();
      }
      _previousStatus = networkStatus;
    }

    // Ne pas afficher si online (avec animation de sortie)
    if (isOnline && !_slideController.isAnimating) {
      return const SizedBox.shrink();
    }

    // Afficher seulement si offline
    if (!isOffline && !isUnknown) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.warning, AppColors.warning.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Icône animée avec pulsation
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.pureWhite.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: _isReconnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.pureWhite,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.wifi_off_rounded,
                            color: AppColors.pureWhite,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Contenu textuel amélioré
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isReconnecting
                                  ? 'Reconnexion en cours...'
                                  : 'Mode hors ligne',
                              style: const TextStyle(
                                color: AppColors.pureWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                                height: 1.2,
                              ),
                            ),
                          ),
                          // Indicateur de statut animé
                          if (!_isReconnecting)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _pulseAnimation.value,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.pureWhite,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.pureWhite
                                              .withOpacity(0.6),
                                          blurRadius: 6,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isReconnecting
                            ? 'Vérification de la connexion Internet...'
                            : 'Vous utilisez les données en cache',
                        style: TextStyle(
                          color: AppColors.pureWhite.withOpacity(0.95),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bouton de réessai amélioré
                if (!_isReconnecting) ...[
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _retryConnection,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pureWhite.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.pureWhite.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              color: AppColors.pureWhite,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Réessayer',
                              style: TextStyle(
                                color: AppColors.pureWhite,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
