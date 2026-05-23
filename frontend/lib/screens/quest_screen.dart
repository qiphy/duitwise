import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Added for Timer polling
import 'package:video_player/video_player.dart';

import '../supabase_service.dart';
import '../models.dart';
import 'dart:math' as math;

void showInteractiveQuestPopup(BuildContext context, {VoidCallback? onQuestCompleted}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false, 
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => InteractiveQuestWidget(onCompleted: onQuestCompleted),
  );
}

class VideoQuizModel {
  final String assetPath;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String keyLesson;

  VideoQuizModel({
    required this.assetPath,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.keyLesson,
  });
}

// 📋 Global static listing of your precise data payloads
final List<VideoQuizModel> eduVideosList = [
  VideoQuizModel(
    assetPath: 'assets/saving_video.mp4',
    question: 'What helped the tiger cub get closer to buying the toy rocket ship?',
    options: ['Wishing on a star.', 'Putting a coin into his spaceship bank every time.'],
    correctIndex: 1,
    keyLesson: 'When you save a little bit at a time, your money grows until you reach your goal!',
  ),
  VideoQuizModel(
    assetPath: 'assets/needs_video.mp4',
    question: 'Why did the fox skip buying the shiny balloon?',
    options: ['He didn\'t have enough coins.', 'He wanted to save his coins for the train ride.'],
    correctIndex: 1,
    keyLesson: 'Wants are fun to have, but it is smart to take care of our important plans first!',
  ),
  VideoQuizModel(
    assetPath: 'assets/account_video.mp4',
    question: 'What does it mean when the gold coin "sprouted" and grew into more coins inside the bank?',
    options: ['The bank added extra money called "interest" as a reward.', 'The soil in the pot was magical.'],
    correctIndex: 0,
    keyLesson: 'When you keep your money in a savings account, the bank pays you a little bit of extra money called interest!',
  ),
];

class InteractiveQuestWidget extends StatefulWidget {
  final VoidCallback? onCompleted;
  const InteractiveQuestWidget({Key? key, this.onCompleted}) : super(key: key);

  @override
  State<InteractiveQuestWidget> createState() => _InteractiveQuestWidgetState();
}

class _InteractiveQuestWidgetState extends State<InteractiveQuestWidget> {
  QuestModel? _currentQuest;
  bool _isLoading = true;
  int _currentStep = 0; // 0: Video Playback, 1: Quiz Evaluation
  
  VideoPlayerController? _videoController;
  String _loadingStatusText = "Initializing Mission Template...";
  Timer? _pollingTimer; // Tracks active status checks
  int _selectedVideoIndex = 0;

  // 🔴 REPLACE WITH YOUR SECURE SECRETS / CONFIG ENVIRONMENT
  final String _magicHourApiKey = "mhk_live_qC8ClVBf5EJXZqM76GGl6tk52ntBIRKE5FFelpfHb4EgTL0sm1Wd5J7UusxGJOXGpSCf5eFxnf4qwtWe"; 

  @override
  void initState() {
    super.initState();
    _generateDynamicQuestAndVideo();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

// 🛠️ REPLACE THE ENTIRE OLD _generateDynamicQuestAndVideo FUNCTION WITH THIS:
  Future<void> _generateDynamicQuestAndVideo() async {
try {
      setState(() {
        _isLoading = true;
        _loadingStatusText = "Preparing Your Financial Mission... 📝";
      });

      // 🛠️ CLEANED UP: The inline import is gone. This line works perfectly now!
      _selectedVideoIndex = math.Random().nextInt(eduVideosList.length);
      final activeQuizData = eduVideosList[_selectedVideoIndex];

      // 2. Map the asset data structures into your operational QuestModel
      final bool isACorrect = activeQuizData.correctIndex == 0;
      final bool isBCorrect = activeQuizData.correctIndex == 1;

      final localQuest = QuestModel(
        id: "local-asset-quest-$_selectedVideoIndex",
        story: activeQuizData.question,
        choiceA: activeQuizData.options[0],
        choiceB: activeQuizData.options[1],
        
        // 🛠️ FIX: Strip the ternary switches. Make A always pass success text, and B always pass failure text.
        outcomeA: "Awesome choice! 🐯 ${activeQuizData.keyLesson}",
        outcomeB: "Not quite! ${activeQuizData.keyLesson}",
        rewardXp: 20,
      );

      // 3. Initialize the native asset controller from the bundled path string
      final String videoPath = activeQuizData.assetPath;
      
      // Check if the app is currently compiling/running on a Web target profile
      if (identical(0, 0.0)) { 
        // Flutter Web expects paths to hit the web root folder assets folder explicitly
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse('${Uri.base.origin}/$videoPath'),
        );
      } else {
        // Mobile platform profiles read directly from the asset bundles
        _videoController = VideoPlayerController.asset(videoPath);
      }

      await _videoController!.initialize();
      await _videoController!.setVolume(1.0);
      await _videoController!.setLooping(true);
      await _videoController!.play();

      setState(() {
        _currentQuest = localQuest;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load asset video: $e')),
        );
      }
    }
  }

  // 🗑️ YOU CAN COMPLETELY REMOVE THE OLD _pollVideoStatus FUNCTION NOW!

Future<void> _processQuestSelection(int chosenOptionIndex) async {
    if (_currentQuest == null) return;
    
    // 💡 Fetching authenticated session context securely
    final String? profileId = supabaseService.currentUserId;
    if (profileId == null) return;

    final activeQuizData = eduVideosList[_selectedVideoIndex];
    final bool isCorrect = chosenOptionIndex == activeQuizData.correctIndex;
    final String outcomeText = isCorrect ? _currentQuest!.outcomeA : _currentQuest!.outcomeB;

    _videoController?.pause(); 

// 1. Display evaluation feedback panel modal immediately with custom bounce animation
if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isCorrect ? 'Awesome Choice! 🐯' : 'Not Quite! 🧩', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1F2937))
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // 🔥 HIGH-JUICE LIVELY MULTI-TWEEN ANIMATOR
                  if (isCorrect)
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut, // Explosive snap outwards
                      builder: (context, value, child) {
                        // 🎮 Arcade math formulas for compound motion vectors
                        final double scaleFactor = value < 0.4 
                            ? (value / 0.4) * 1.4  // Overshoots aggressively to 140% scale early on
                            : 1.4 - ((value - 0.4) / 0.6) * 0.4; // Springs back smoothly to 100%
                            
                        final double shakeFactor = math.sin(value * 4 * math.pi) * 0.15 * (1.0 - value); // Organic dampening rotational waggle
                        final double floatUpFactor = (1.0 - value) * -15; // Floats upward 15 pixels during entry

                        return Transform.translate(
                          offset: Offset(0, floatUpFactor),
                          child: Transform.scale(
                            scale: scaleFactor,
                            child: Transform.rotate(
                              angle: shakeFactor,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: _buildXpBadge(isCorrect),
                    )
                  else
                    // Muted subtle fallback animation for incorrect targets
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) => Transform.scale(scale: value, child: child),
                      child: _buildXpBadge(isCorrect),
                    ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outcomeText, 
                    style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF374151))
                  ),
                  const SizedBox(height: 16),
                  
                  FutureBuilder<bool>(
                    future: Future.delayed(const Duration(milliseconds: 400), () => true),
                    builder: (context, snapshot) {
                      final bool showBanner = snapshot.data ?? false;
                      return AnimatedOpacity(
                        opacity: showBanner ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Awesome!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        ),
      );
    }

    // 2. 💾 DIRECT SUPABASE INTEGRATION ENGINE LAYER
    if (isCorrect) {
      try {
        // Execute the server-side numeric incrementer function we spun up in Step 1
        await supabaseService.client.rpc(
          'increment_child_coins',
          params: {
            'user_id': profileId,
            'coin_delta': 0.10, // Pass a precise floating-point standard decimal fraction
          },
        );

        // Also bump up the child's XP attributes profile tracking parameters as a secondary reward multiplier
        // 🛠️ REPLACE WITH THIS:
        await supabaseService.client.rpc(
          'increment_child_xp',
          params: {
            'user_id': profileId,
            'xp_delta': 20, // Adds exactly 20 XP to the existing database value natively
          },
        );

      } catch (e) {
        debugPrint('Direct Supabase transaction failure ledger exception: $e');
      }
    }

    // 3. Close out layout context frames and fire background state balance refreshes
    if (mounted) {
      Navigator.pop(context);
      if (widget.onCompleted != null) widget.onCompleted!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double modalHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: modalHeight,
      padding: const EdgeInsets.all(24.0),
      child: _isLoading
          ? _buildGamifiedLoader()
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentStep == 0 
                  ? _buildVideoPlaybackStage() 
                  : _buildQuizAssessmentStage(),
            ),
    );
  }

  Widget _buildGamifiedLoader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 2 * 3.14159),
          duration: const Duration(seconds: 3),
          builder: (context, value, child) {
            return Transform.rotate(angle: value, child: child);
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFFF3E8FF), shape: BoxShape.circle),
            child: const Text('🎬', style: TextStyle(fontSize: 44)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _loadingStatusText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 12),
        const SizedBox(
          width: 100,
          child: LinearProgressIndicator(color: Color(0xFF8B5CF6), backgroundColor: Color(0xFFF3E8FF)),
        )
      ],
    );
  }

  Widget _buildVideoPlaybackStage() {
    return Column(
      key: const ValueKey('video_playback_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Incoming Mission Alert! 🚨',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 24),
        
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_videoController != null && _videoController!.value.isInitialized)
                    Positioned.fill(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  
                  Positioned(
                    left: 24,   
                    right: 24,  
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: () => setState(() => _currentStep = 1), 
          child: const Text(
            'I Finished Watching! Answer Quiz ➡️',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

Widget _buildQuizAssessmentStage() {
    final activeQuizData = eduVideosList[_selectedVideoIndex];

    return Column(
      key: const ValueKey('quiz_evaluation_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => setState(() => _currentStep = 0), 
            ),
            const Expanded(
              child: Text(
                'Financial Choice Time! 🤔',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            activeQuizData.question, // Pull directly from safe source mapping
            style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF374151)),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'What strategy should we pick?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        
        // 🛠️ FIX BLOCK: Dynamically map all matching options fields cleanly from your array
        Expanded(
          child: ListView.builder(
            itemCount: activeQuizData.options.length,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final String optionText = activeQuizData.options[index];
              
              // Apply themed coloring tags depending on selection states
              final bool isEven = index % 2 == 0;
              final Color backgroundAccent = isEven ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);
              final Color boundaryAccent = isEven ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0);
              final Color textAccent = isEven ? const Color(0xFF1E40AF) : const Color(0xFF065F46);
              final String indicatorEmoji = index == 0 ? '🅰️' : index == 1 ? '🅱️' : '🆃';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _processQuestSelection(index), // 🪙 Sends precise choice index (0, 1, 2)
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: backgroundAccent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: boundaryAccent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Text(indicatorEmoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            optionText,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 📐 Helper module rendering the core layout style structure of the badge frames
  Widget _buildXpBadge(bool isCorrect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFFBBF24) : Colors.grey[200],
        gradient: isCorrect ? const LinearGradient(
          colors: [Color(0xFFFFE17D), Color(0xFFF59E0B)], // Brighter high-contrast yellow gradient profiles
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isCorrect ? [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCorrect ? Icons.bolt_rounded : Icons.lock_open_rounded, 
            color: isCorrect ? Colors.white : Colors.grey[600], 
            size: 18
          ),
          const SizedBox(width: 4),
          Text(
            isCorrect ? '+20 XP' : '+0 XP',
            style: TextStyle(
              color: isCorrect ? Colors.white : const Color(0xFF4B5563), 
              fontWeight: FontWeight.bold, // Ultra bold for readability
              fontSize: 14,
              letterSpacing: 0.5,
              shadows: isCorrect ? [
                const Shadow(color: Color(0xFFB45309), offset: Offset(0, 1), blurRadius: 2)
              ] : [],
            ),
          ),
        ],
      ),
    );
  }
}