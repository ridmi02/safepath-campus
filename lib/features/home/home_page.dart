import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safepath_campus/screens/emergency_screen.dart';
import 'package:safepath_campus/services/firebase_service.dart';
import 'package:safepath_campus/services/voice_activation_page.dart';
import 'package:safepath_campus/services/emergency_alarm_service.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  static const double _featureTileHeight = 132;
  static const double _sectionSpacing = 32;
  static const double _rowGap = 12;
  static const double _cardRadius = 12;

  late final AnimationController _entranceController;
  late final Animation<double> _heroOpacity;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _sosOpacity;
  late final Animation<Offset> _sosSlide;
  late final Animation<double> _row1Opacity;
  late final Animation<Offset> _row1Slide;
  late final Animation<double> _row2Opacity;
  late final Animation<Offset> _row2Slide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    Animation<double> interval(double begin, double end) {
      return CurvedAnimation(
        parent: _entranceController,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );
    }

    final heroAnim = interval(0.0, 0.38);
    _heroOpacity = Tween<double>(begin: 0, end: 1).animate(heroAnim);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(heroAnim);

    final sosAnim = interval(0.12, 0.52);
    _sosOpacity = Tween<double>(begin: 0, end: 1).animate(sosAnim);
    _sosSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(sosAnim);

    final r1 = interval(0.28, 0.72);
    _row1Opacity = Tween<double>(begin: 0, end: 1).animate(r1);
    _row1Slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(r1);

    final r2 = interval(0.42, 0.88);
    _row2Opacity = Tween<double>(begin: 0, end: 1).animate(r2);
    _row2Slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(r2);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _triggerSOS(BuildContext context) async {
    HapticFeedback.mediumImpact();
    await EmergencyAlertService().activateEmergency();
    const FirebaseService().logSosActivated();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Emergency Alert Sent!'),
        backgroundColor: Color(0xFFE63946),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color heroTint =
        Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.06);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SafePath Campus'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _HomeBackdropPainter(colorScheme: colorScheme),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _heroOpacity,
                    child: SlideTransition(
                      position: _heroSlide,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_cardRadius),
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: heroTint,
                                borderRadius:
                                    BorderRadius.circular(_cardRadius),
                                border: Border.all(
                                  color: colorScheme.outline
                                      .withValues(alpha: 0.12),
                                ),
                              ),
                            ),
                            Positioned(
                              right: -36,
                              top: -28,
                              child: _DecorCircle(
                                diameter: 112,
                                color: colorScheme.primary
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                            Positioned(
                              left: -24,
                              bottom: -20,
                              child: _DecorCircle(
                                diameter: 88,
                                color: colorScheme.outline
                                    .withValues(alpha: 0.1),
                              ),
                            ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _HeroStripesPainter(
                                  color: colorScheme.outline
                                      .withValues(alpha: 0.06),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 120,
                              child: Center(
                                child: Text(
                                  'SafePath',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                    letterSpacing: -0.5,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: _sectionSpacing)),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _sosOpacity,
                    child: SlideTransition(
                      position: _sosSlide,
                      child: Center(
                        child: Semantics(
                          button: true,
                          label: 'SOS Emergency',
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFE63946),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE63946)
                                      .withAlpha((0.4 * 255).round()),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _triggerSOS(context),
                                customBorder: const CircleBorder(),
                                child: const Center(
                                  child: Text(
                                    'SOS',
                                    style: TextStyle(
                                      fontSize: 52,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFFFFFF),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: _sectionSpacing)),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _row1Opacity,
                    child: SlideTransition(
                      position: _row1Slide,
                      child: _SectionDivider(colorScheme: colorScheme),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _row1Opacity,
                    child: SlideTransition(
                      position: _row1Slide,
                      child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: _featureTileHeight,
                          child: _FeatureCard(
                            cardRadius: _cardRadius,
                            icon: Icons.emergency_share,
                            label: 'Emergency Alert System',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EmergencyScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: _rowGap),
                      Expanded(
                        child: SizedBox(
                          height: _featureTileHeight,
                          child: _FeatureCard(
                            cardRadius: _cardRadius,
                            icon: Icons.map,
                            label: 'Campus Map',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pushNamed('/campus_map');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _rowGap)),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _row2Opacity,
                child: SlideTransition(
                  position: _row2Slide,
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: _featureTileHeight,
                          child: _FeatureCard(
                            cardRadius: _cardRadius,
                            icon: Icons.record_voice_over,
                            label: 'Voice Activation',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const VoiceActivationPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: _rowGap),
                      Expanded(
                        child: SizedBox(
                          height: _featureTileHeight,
                          child: _FeatureCard(
                            cardRadius: _cardRadius,
                            icon: Icons.groups_2,
                            label: 'Companion',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pushNamed('/companion');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft page texture: dots + large washes using only [ColorScheme] tints.
class _HomeBackdropPainter extends CustomPainter {
  _HomeBackdropPainter({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..shader = RadialGradient(
        colors: [
          colorScheme.primary.withValues(alpha: 0.06),
          colorScheme.primary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.85, size.height * 0.08),
        radius: size.shortestSide * 0.55,
      ));
    canvas.drawRect(Offset.zero & size, wash);

    final wash2 = Paint()
      ..shader = RadialGradient(
        colors: [
          colorScheme.outline.withValues(alpha: 0.08),
          colorScheme.outline.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.1, size.height * 0.72),
        radius: size.shortestSide * 0.45,
      ));
    canvas.drawRect(Offset.zero & size, wash2);

    final dot = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.11)
      ..style = PaintingStyle.fill;
    const step = 26.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        canvas.drawCircle(Offset(x, y), 0.9, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HomeBackdropPainter oldDelegate) =>
      oldDelegate.colorScheme.primary != colorScheme.primary ||
      oldDelegate.colorScheme.outline != colorScheme.outline;
}

class _HeroStripesPainter extends CustomPainter {
  _HeroStripesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const spacing = 18.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeroStripesPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DecorCircle extends StatelessWidget {
  const _DecorCircle({
    required this.diameter,
    required this.color,
  });

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            thickness: 1,
            height: 1,
            color: colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.35),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
        Expanded(
          child: Divider(
            thickness: 1,
            height: 1,
            color: colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final double cardRadius;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.cardRadius,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardBg = colorScheme.primaryContainer;
    final cardText = colorScheme.onPrimaryContainer;
    return Semantics(
      button: true,
      label: label,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        elevation: 4,
        color: cardBg,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 42, color: cardText),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: cardText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
