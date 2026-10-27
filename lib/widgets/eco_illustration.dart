import 'package:flutter/material.dart';

enum EcoScene { landscape, travel, home, food, history }

class EcoIllustration extends StatelessWidget {
  const EcoIllustration({super.key, required this.scene});

  final EcoScene scene;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = constraints.biggest.shortestSide;
      final iconSize = (side * .42).clamp(20.0, 92.0).toDouble();
      final badgeSize = (side * .2).clamp(14.0, 40.0).toDouble();
      final palette = _palette;

      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.background, const Color(0xFFF7F2E8)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: -side * .13,
              bottom: -side * .3,
              child: _orb(
                side * .68,
                const Color(0xFFB7D7B3).withValues(alpha: .55),
              ),
            ),
            Positioned(
              right: -side * .09,
              top: -side * .32,
              child: _orb(
                side * .62,
                const Color(0xFFFFB8A8).withValues(alpha: .38),
              ),
            ),
            Center(
              child: Container(
                width: side * .56,
                height: side * .56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF4).withValues(alpha: .92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: palette.green.withValues(alpha: .12),
                      blurRadius: side * .08,
                      offset: Offset(0, side * .025),
                    ),
                  ],
                ),
                child: Icon(scene._icon, color: palette.green, size: iconSize),
              ),
            ),
            Positioned(
              left: side * .16,
              top: side * .2,
              child: _badge(
                Icons.eco_rounded,
                badgeSize,
                palette.green,
                const Color(0xFFE1EEDB),
              ),
            ),
            Positioned(
              right: side * .15,
              bottom: side * .17,
              child: _badge(
                scene._accentIcon,
                badgeSize,
                palette.coral,
                const Color(0xFFFFE1D9),
              ),
            ),
          ],
        ),
      );
    },
  );

  _ScenePalette get _palette => switch (scene) {
    EcoScene.landscape => const _ScenePalette(
      Color(0xFFE5F0E2),
      Color(0xFF356B48),
      Color(0xFFE67E6D),
    ),
    EcoScene.travel => const _ScenePalette(
      Color(0xFFE4F0E7),
      Color(0xFF356B48),
      Color(0xFFE67E6D),
    ),
    EcoScene.home => const _ScenePalette(
      Color(0xFFEAF0E2),
      Color(0xFF466C45),
      Color(0xFFE67E6D),
    ),
    EcoScene.food => const _ScenePalette(
      Color(0xFFF2F0DF),
      Color(0xFF4F7548),
      Color(0xFFE67E6D),
    ),
    EcoScene.history => const _ScenePalette(
      Color(0xFFE6EFE8),
      Color(0xFF356B48),
      Color(0xFFE67E6D),
    ),
  };

  Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _badge(
    IconData icon,
    double size,
    Color foreground,
    Color background,
  ) => Container(
    width: size * 1.65,
    height: size * 1.65,
    decoration: BoxDecoration(shape: BoxShape.circle, color: background),
    child: Icon(icon, size: size, color: foreground),
  );
}

extension on EcoScene {
  IconData get _icon => switch (this) {
    EcoScene.landscape => Icons.forest_rounded,
    EcoScene.travel => Icons.directions_bike_rounded,
    EcoScene.home => Icons.energy_savings_leaf_rounded,
    EcoScene.food => Icons.spa_rounded,
    EcoScene.history => Icons.insights_rounded,
  };

  IconData get _accentIcon => switch (this) {
    EcoScene.landscape => Icons.wb_sunny_rounded,
    EcoScene.travel => Icons.directions_walk_rounded,
    EcoScene.home => Icons.wb_sunny_rounded,
    EcoScene.food => Icons.restaurant_rounded,
    EcoScene.history => Icons.auto_graph_rounded,
  };
}

class _ScenePalette {
  const _ScenePalette(this.background, this.green, this.coral);

  final Color background;
  final Color green;
  final Color coral;
}
