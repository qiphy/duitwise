import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../supabase_service.dart';
import 'home_screen.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Main Fade
  late AnimationController _fadeController;
  late Animation<double> _contentFade;

  // Owl Animation
  late AnimationController _owlController;
  late Animation<double> _floatY;
  late Animation<double> _scale;
  late Animation<double> _rotation;
  late Animation<double> _sideMove;

  // Sparkle Animation
  late AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _contentFade = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _owlController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _floatY = Tween<double>(
      begin: 0,
      end: -22,
    ).animate(
      CurvedAnimation(
        parent: _owlController,
        curve: Curves.easeInOut,
      ),
    );

    _scale = Tween<double>(
      begin: 1,
      end: 1.08,
    ).animate(
      CurvedAnimation(
        parent: _owlController,
        curve: Curves.easeInOutBack,
      ),
    );

    _rotation = Tween<double>(
      begin: -0.03,
      end: 0.03,
    ).animate(
      CurvedAnimation(
        parent: _owlController,
        curve: Curves.easeInOutSine,
      ),
    );

    _sideMove = Tween<double>(
      begin: -12,
      end: 12,
    ).animate(
      CurvedAnimation(
        parent: _owlController,
        curve: Curves.easeInOut,
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
      }
    });

    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _owlController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 4000));

    if (!mounted) return;

    final currentUser = supabaseService.client.auth.currentUser;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            currentUser != null
                ? const HomeScreen()
                : const AuthScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // FUN CARTOON BACKGROUND
          Positioned.fill(
            child: CustomPaint(
              painter: _KidsBackgroundPainter(),
            ),
          ),

          // SPARKLES
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _sparkleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _SparklePainter(
                    progress: _sparkleController.value,
                  ),
                );
              },
            ),
          ),

          // TITLE
          Positioned(
            top: size.height * 0.12,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _contentFade,
              child: Column(
                children: const [
                  Text(
                    'DuitWise',
                    style: TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Color(0xFFFF8A00),
                          blurRadius: 18,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Save Coins • Learn Smart • Have Fun!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // OWL AVATAR
          Positioned(
            top: size.height * 0.28,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _contentFade,
              child: AnimatedBuilder(
                animation: _owlController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _sideMove.value,
                      _floatY.value,
                    ),
                    child: Transform.rotate(
                      angle: _rotation.value,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // GLOW
                      Container(
                        width: 340,
                        height: 340,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellow.withValues(alpha: 0.45),
                              blurRadius: 70,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),

                      // AVATAR
                      Image.asset(
                        'https://tbrefzeytkflqyadayvs.supabase.co/storage/v1/object/public/app-assets/avatar.png',
                        width: 340,
                        height: 340,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // FLOATING COINS
          Positioned(
            top: size.height * 0.48,
            left: 30,
            child: _coinBubble('💰'),
          ),

          Positioned(
            top: size.height * 0.38,
            right: 40,
            child: _coinBubble('⭐'),
          ),

          Positioned(
            top: size.height * 0.56,
            right: 70,
            child: _coinBubble('✨'),
          ),

          // LOADING
          Positioned(
            bottom: 70,
            left: 40,
            right: 40,
            child: FadeTransition(
              opacity: _contentFade,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: const LinearProgressIndicator(
                      minHeight: 12,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation(
                        Color(0xFFFFD54F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading your fun adventure...',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coinBubble(String emoji) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }
}

class _KidsBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // SKY GRADIENT
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF6DD5FA),
          Color(0xFFFFF59D),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);

    // SUN
    final sunPaint = Paint()
      ..color = const Color(0xFFFFEB3B);

    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.16),
      55,
      sunPaint,
    );

    // CLOUDS
    _drawCloud(canvas, Offset(size.width * 0.2, size.height * 0.18));
    _drawCloud(canvas, Offset(size.width * 0.9, size.height * 0.26));

    // HILLS
    final hillPaint = Paint()
      ..color = const Color(0xFF66BB6A);

    final hill = Path();

    hill.moveTo(0, size.height * 0.75);

    hill.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.62,
      size.width * 0.5,
      size.height * 0.76,
    );

    hill.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.9,
      size.width,
      size.height * 0.72,
    );

    hill.lineTo(size.width, size.height);
    hill.lineTo(0, size.height);
    hill.close();

    canvas.drawPath(hill, hillPaint);

    // FRONT HILL
    final frontHillPaint = Paint()
      ..color = const Color(0xFF43A047);

    final front = Path();

    front.moveTo(0, size.height * 0.88);

    front.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.75,
      size.width * 0.6,
      size.height * 0.9,
    );

    front.quadraticBezierTo(
      size.width * 0.9,
      size.height * 1.0,
      size.width,
      size.height * 0.84,
    );

    front.lineTo(size.width, size.height);
    front.lineTo(0, size.height);
    front.close();

    canvas.drawPath(front, frontHillPaint);
  }

  void _drawCloud(Canvas canvas, Offset offset) {
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85);

    canvas.drawCircle(offset, 24, cloudPaint);
    canvas.drawCircle(offset + const Offset(25, -10), 30, cloudPaint);
    canvas.drawCircle(offset + const Offset(55, 0), 22, cloudPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SparklePainter extends CustomPainter {
  final double progress;

  _SparklePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final sparklePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7);

    final stars = [
      Offset(size.width * 0.18, size.height * 0.22),
      Offset(size.width * 0.84, size.height * 0.32),
      Offset(size.width * 0.74, size.height * 0.52),
      Offset(size.width * 0.30, size.height * 0.60),
    ];

    for (int i = 0; i < stars.length; i++) {
      final pulse =
          2 + math.sin((progress * 2 * math.pi) + i) * 2;

      canvas.drawCircle(
        stars[i],
        pulse,
        sparklePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}