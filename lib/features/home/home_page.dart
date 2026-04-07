import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safepath_campus/screens/emergency_screen.dart';
import 'package:safepath_campus/services/firebase_service.dart';
import 'package:safepath_campus/services/voice_activation_page.dart';
import 'package:safepath_campus/services/emergency_alarm_service.dart';
import '../deadman_switch/deadman_setup_screen.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with TickerProviderStateMixin {
  static const double _featureTileHeight = 132;
  static const double _sectionSpacing = 32;
  static const double _rowGap = 12;
  static const double _cardRadius = 12;

  late final AnimationController _entranceController;
  late final Animation<double> _sosOpacity;
  late final Animation<Offset> _sosSlide;
  late final Animation<double> _sosScale;
  late final Animation<double> _row1Opacity;
  late final Animation<Offset> _row1Slide;
  late final Animation<double> _row1Scale;
  late final Animation<double> _row2Opacity;
  late final Animation<Offset> _row2Slide;
  late final Animation<double> _row2Scale;

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

    final sosAnim = interval(0.12, 0.52);
    _sosOpacity = Tween<double>(begin: 0, end: 1).animate(sosAnim);
    _sosSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(sosAnim);
    _sosScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(0.12, 0.6, curve: Curves.elasticOut),
      ),
    );

    final r1 = interval(0.28, 0.72);
    _row1Opacity = Tween<double>(begin: 0, end: 1).animate(r1);
    _row1Slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(r1);
    _row1Scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(0.28, 0.8, curve: Curves.elasticOut),
      ),
    );

    final r2 = interval(0.42, 0.88);
    _row2Opacity = Tween<double>(begin: 0, end: 1).animate(r2);
    _row2Slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(r2);
    _row2Scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(0.42, 0.96, curve: Curves.elasticOut),
      ),
    );

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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SafePath Campus',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 2,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
        surfaceTintColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
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
          // Decorative elements
          Positioned(
            top: 120,
            right: 40,
            child: _DecorCircle(
              diameter: 24,
              color: colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          Positioned(
            top: 280,
            left: 30,
            child: _DecorCircle(
              diameter: 18,
              color: colorScheme.secondary.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: 200,
            right: 60,
            child: _DecorCircle(
              diameter: 32,
              color: colorScheme.tertiary.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // ── SOS button ───────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _sosOpacity,
                    child: SlideTransition(
                      position: _sosSlide,
                      child: ScaleTransition(
                        scale: _sosScale,
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
                                    blurRadius: 30,
                                    spreadRadius: 4,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFE63946)
                                        .withAlpha((0.2 * 255).round()),
                                    blurRadius: 60,
                                    spreadRadius: 8,
                                    offset: const Offset(0, 12),
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
                ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: _sectionSpacing)),

                // ── Section divider ──────────────────────────────────────────
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

                // ── Row 1: Emergency Alert + Campus Map ──────────────────────
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _row1Opacity,
                    child: SlideTransition(
                      position: _row1Slide,
                      child: ScaleTransition(
                        scale: _row1Scale,
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
                                  label: 'Map',
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context)
                                        .pushNamed('/campus_map');
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: _rowGap)),

                // ── Row 2: Voice Activation + Companion ──────────────────────
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _row2Opacity,
                    child: SlideTransition(
                      position: _row2Slide,
                      child: ScaleTransition(
                        scale: _row2Scale,
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
                                    Navigator.of(context)
                                        .pushNamed('/companion');
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: _rowGap)),

                // ── Deadman's Switch (centered single tile) ──────────────────
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _row2Opacity,
                    child: SlideTransition(
                      position: _row2Slide,
                      child: ScaleTransition(
                        scale: _row2Scale,
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            child: SizedBox(
                              height: _featureTileHeight,
                              child: _FeatureCard(
                                cardRadius: _cardRadius,
                                icon: Icons.shield_rounded,
                                label: "Deadman's Switch",
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const DeadmanSetupScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
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

// ── Background painters ──────────────────────────────────────────────────────

class _HomeBackdropPainter extends CustomPainter {
  _HomeBackdropPainter({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    // Primary gradient wash
    final wash = Paint()
      ..shader = RadialGradient(
        colors: [
          colorScheme.primary.withValues(alpha: 0.08),
          colorScheme.primary.withValues(alpha: 0.02),
          colorScheme.primary.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.85, size.height * 0.08),
        radius: size.shortestSide * 0.6,
      ));
    canvas.drawRect(Offset.zero & size, wash);

    // Secondary gradient wash
    final wash2 = Paint()
      ..shader = RadialGradient(
        colors: [
          colorScheme.outline.withValues(alpha: 0.1),
          colorScheme.outline.withValues(alpha: 0.03),
          colorScheme.outline.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.1, size.height * 0.72),
        radius: size.shortestSide * 0.5,
      ));
    canvas.drawRect(Offset.zero & size, wash2);

    // Tertiary subtle accent
    final wash3 = Paint()
      ..shader = RadialGradient(
        colors: [
          colorScheme.secondary.withValues(alpha: 0.04),
          colorScheme.secondary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.5, size.height * 0.4),
        radius: size.shortestSide * 0.3,
      ));
    canvas.drawRect(Offset.zero & size, wash3);

    // Enhanced dot pattern
    final dot = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    const step = 28.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        final opacity = 0.04 + (x / size.width) * 0.06; // Vary opacity based on position
        dot.color = colorScheme.outline.withValues(alpha: opacity);
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HomeBackdropPainter oldDelegate) =>
      oldDelegate.colorScheme.primary != colorScheme.primary ||
      oldDelegate.colorScheme.outline != colorScheme.outline;
}

// ── Helper widgets ───────────────────────────────────────────────────────────

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
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.4),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
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
        elevation: 8,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
        color: cardBg,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: cardText),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
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
