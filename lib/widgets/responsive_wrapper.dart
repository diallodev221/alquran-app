import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// Widget wrapper qui centre et limite la largeur du contenu sur grands écrans
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final bool centerOnLargeScreens;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth,
    this.centerOnLargeScreens = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = ResponsiveUtils.screenWidth(context);
    final contentMaxWidth =
        maxWidth ?? ResponsiveUtils.maxContentWidth(context);

    // Si l'écran est plus large que la largeur max, centrer le contenu
    if (centerOnLargeScreens && screenWidth > contentMaxWidth) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: child,
        ),
      );
    }

    return child;
  }
}

/// Widget pour créer des layouts adaptatifs basés sur la taille de l'écran
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);
    return builder(context, deviceType);
  }
}

/// Widget pour afficher différents widgets selon la taille
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        switch (deviceType) {
          case DeviceType.mobile:
            return mobile;
          case DeviceType.tablet:
            return tablet ?? mobile;
          case DeviceType.desktop:
            return desktop ?? tablet ?? mobile;
        }
      },
    );
  }
}
