import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../supabase_service.dart';

class OnboardingWelcomeScreen extends StatefulWidget {
  final dynamic wallet;
  final VoidCallback onFinish;
  final Function(BuildContext, dynamic, VoidCallback) onShowSmartPlanSheet;

  const OnboardingWelcomeScreen({
    Key? key, 
    required this.wallet, 
    required this.onFinish, 
    required this.onShowSmartPlanSheet,
  }) : super(key: key);

  @override
  State<OnboardingWelcomeScreen> createState() => _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  VideoPlayerController? _introController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    // ✅ FIXED: Asset path string corrected to match your exact filename
    _introController = VideoPlayerController.asset('assets/Intro Video.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isVideoInitialized = true);
        }
      });

    // 🔄 ADDED STATE LISTENERS: Redraws the UI automatically when video triggers play/pause state changes
    _introController?.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _introController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.toll_rounded, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to DuitWise',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Learn to manage money, earn through tasks, and achieve your goals — one smart decision at a time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.4),
              ),
              const SizedBox(height: 24),

              // 🎞️ APP INTRODUCTION VIDEO LAYER COMPONENT
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF312E81),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isVideoInitialized)
                        Positioned.fill(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _introController!.value.size.width,
                              height: _introController!.value.size.height,
                              child: VideoPlayer(_introController!),
                            ),
                          ),
                        ),
                      
                      // Playback Action Custom Overlays
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _introController!.value.isPlaying 
                                ? _introController!.pause() 
                                : _introController!.play();
                          });
                        },
                        child: CircleAvatar(
                          radius: 28,
                          // ✅ FIXED: Substituted deprecated withOpacity with explicit withValues alpha masks
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                          child: Icon(
                            _introController != null && _introController!.value.isPlaying 
                                ? Icons.pause_rounded 
                                : Icons.play_arrow_rounded,
                            color: const Color(0xFF6366F1), 
                            size: 32
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Watch this quick video to learn how Ali transformed his money habits with DuitWise',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 28),

              // FEATURE HIGHLIGHT ROWS
              _buildFeatureRow('Track Your Money', 'See exactly where your money comes from and where it goes', const Color(0xFFEFF6FF), const Color(0xFF3B82F6), Icons.account_balance_wallet_rounded),
              const SizedBox(height: 12),
              _buildFeatureRow('Earn Through Tasks', 'Complete chores assigned by your parents to grow your balance', const Color(0xFFFAF5FF), const Color(0xFF8B5CF6), Icons.trending_up_rounded),
              const SizedBox(height: 12),
              _buildFeatureRow('Set & Achieve Goals', 'Save toward the things you want with clear progress tracking', const Color(0xFFFFF1F2), const Color(0xFFF43F5E), Icons.track_changes_rounded),
              const SizedBox(height: 12),
              _buildFeatureRow('Build Good Habits', 'Earn badges and streaks as you develop smart money habits', const Color(0xFFF0FDF4), const Color(0xFF22C55E), Icons.military_tech_rounded),
              
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF030712),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  _introController?.pause();
                  widget.onShowSmartPlanSheet(
                    context, 
                    widget.wallet, 
                    widget.onFinish,
                  );
                },
                child: const Text('Get Started', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String title, String desc, Color bg, Color tint, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.4), // ✅ FIXED: Modernized opacity allocation
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937))),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
              ],
            ),
          )
        ],
      ),
    );
  }
}