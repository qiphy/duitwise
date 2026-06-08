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
    
    // 🌐 CHANGED: Swapped .asset for .networkUrl to stream directly from Supabase
    final videoUri = Uri.parse(
      'https://tbrefzeytkflqyadayvs.supabase.co/storage/v1/object/public/quest-videos/intro_video.mp4'
    );

    _introController = VideoPlayerController.networkUrl(videoUri)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isVideoInitialized = true);
        }
      }).catchError((error) {
        // Handle any network loading/CORS errors gracefully here
        debugPrint("Video initialization failed: $error");
      });

    // 🔄 STATE LISTENERS: Redraws the UI automatically when video triggers play/pause state changes
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
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double optimizedWidth = constraints.maxWidth > 600 
                        ? constraints.maxWidth * 0.40 
                        : constraints.maxWidth * 0.90;

                    return SizedBox(
                      width: optimizedWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF312E81),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _isVideoInitialized
                                ? AspectRatio(
                                    aspectRatio: _introController!.value.aspectRatio,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        VideoPlayer(_introController!),
                                        
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
                                            radius: 24, 
                                            backgroundColor: Colors.white.withValues(alpha: 0.9),
                                            child: Icon(
                                              _introController!.value.isPlaying 
                                                  ? Icons.pause_rounded 
                                                  : Icons.play_arrow_rounded,
                                              color: const Color(0xFF6366F1), 
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : SizedBox(
                                    height: optimizedWidth * (9 / 16), 
                                    child: const Center(
                                      child: CircularProgressIndicator(color: Colors.white),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
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
        color: bg.withValues(alpha: 0.4), 
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