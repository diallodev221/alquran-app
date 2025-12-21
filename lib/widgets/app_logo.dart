import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Logo personnalisé de l'application Al-Quran
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({super.key, this.size = 120, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo graphique
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.luxuryGold, AppColors.darkGold],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.25),
            boxShadow: [
              BoxShadow(
                color: AppColors.luxuryGold.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Motif de fond - Cercles concentriques
              ...List.generate(3, (index) {
                return Container(
                  width: size * (0.9 - index * 0.2),
                  height: size * (0.9 - index * 0.2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.pureWhite.withOpacity(
                        0.1 + index * 0.05,
                      ),
                      width: 1.5,
                    ),
                  ),
                );
              }),

              // Icône centrale - Livre ouvert
              Icon(
                Icons.menu_book,
                size: size * 0.5,
                color: AppColors.pureWhite,
              ),

              // Croissant décoratif en haut à droite
              Positioned(
                top: size * 0.15,
                right: size * 0.15,
                child: _buildCrescent(size * 0.15),
              ),

              // Étoile décorative
              Positioned(
                top: size * 0.2,
                right: size * 0.25,
                child: Icon(
                  Icons.star,
                  size: size * 0.08,
                  color: AppColors.pureWhite.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),

        // Texte sous le logo (optionnel)
        if (showText) ...[
          SizedBox(height: size * 0.15),
          Text(
            'القرآن الكريم',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: size * 0.25,
              fontWeight: FontWeight.bold,
              color: AppColors.luxuryGold,
            ),
          ),
          SizedBox(height: size * 0.05),
          Text(
            'Al-Quran Al-Karim',
            style: TextStyle(
              fontSize: size * 0.12,
              fontWeight: FontWeight.w300,
              color: AppColors.darkGold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  /// Construire un croissant de lune
  Widget _buildCrescent(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: CrescentPainter(color: AppColors.pureWhite)),
    );
  }
}

/// Painter pour dessiner un croissant de lune
class CrescentPainter extends CustomPainter {
  final Color color;

  CrescentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    // Dessiner le cercle principal
    final mainCircle = Offset(size.width * 0.3, size.height * 0.5);
    canvas.drawCircle(mainCircle, size.width * 0.5, paint);

    // Dessiner le cercle de découpe
    final cutoutCircle = Offset(size.width * 0.5, size.height * 0.5);
    final cutoutPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawCircle(mainCircle, size.width * 0.5, paint);
    canvas.drawCircle(cutoutCircle, size.width * 0.45, cutoutPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CrescentPainter oldDelegate) => false;
}

/// Logo simple (juste l'icône)
class AppLogoSimple extends StatelessWidget {
  final double size;

  const AppLogoSimple({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.luxuryGold, AppColors.darkGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: AppColors.luxuryGold.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.menu_book,
        size: size * 0.6,
        color: AppColors.pureWhite,
      ),
    );
  }
}
