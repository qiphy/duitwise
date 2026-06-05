import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Added for Timer polling
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';

import '../supabase_service.dart';
import '../models.dart';
import 'dart:math' as math;

// 🎯 STATE TRACKER: A tracking variable that persists across successive bottom sheet openings
int? _globalLastServedVideoIndex;

void showInteractiveQuestPopup(BuildContext context, {VoidCallback? onQuestCompleted}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false, 
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 📦 SWIPE INDICATOR DISMISS HANDLE
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1), 
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Expanded(
            child: InteractiveQuestWidget(
              onCompleted: onQuestCompleted,
              // 🎯 PASS INDEX: Feeds the previous runtime sequence index down into state lifecycle
              lastVideoIndex: _globalLastServedVideoIndex,
              onVideoSelected: (index) {
                _globalLastServedVideoIndex = index; // Lock in the new choice globally
              },
            ),
          ),
        ],
      ),
    ),
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
    assetPath: 'https://tbrefzeytkflqyadayvs.supabase.co/storage/v1/object/public/quest-videos/saving_video.mp4', 
    question: 'What helped the tiger cub get closer to buying the toy rocket ship?',
    options: [
      'Wishing on a star.', 
      'Putting a coin into his spaceship bank every time.', // Correct
      'Buying candy every day.'
    ],
    correctIndex: 1,
    keyLesson: 'When you save a little bit at a time, your money grows until you reach your goal!',
  ),
  VideoQuizModel(
    assetPath: 'https://tbrefzeytkflqyadayvs.supabase.co/storage/v1/object/public/quest-videos/needs_video.mp4',
    question: 'Why did the fox skip buying the shiny balloon?',
    options: [
      'He didn\'t have enough coins.', 
      'He was scared of balloons.',
      'He wanted to save his coins for the train ride.', // Correct
    ],
    correctIndex: 2,
    keyLesson: 'Wants are fun to have, but it is smart to take care of our important plans first!',
  ),
  VideoQuizModel(
    assetPath: 'https://tbrefzeytkflqyadayvs.supabase.co/storage/v1/object/public/quest-videos/account_video.mp4',
    question: 'What does it mean when the gold coin "sprouted" and grew into more coins inside the bank?',
    options: [
      'The bank added extra money called "interest" as a reward.', // Correct
      'The soil in the pot was magical.',
      'Someone dropped extra coins by accident.'
    ],
    correctIndex: 0,
    keyLesson: 'When you keep your money in a savings account, the bank pays you a little bit of extra money called interest!',
  ),
];

class InteractiveQuestWidget extends StatefulWidget {
  final VoidCallback? onCompleted;
  final int? lastVideoIndex; // 📥 Accept previous tracking index
  final ValueChanged<int>? onVideoSelected; // 📤 Callback notification hook

  const InteractiveQuestWidget({
    Key? key, 
    this.onCompleted,
    this.lastVideoIndex,
    this.onVideoSelected,
  }) : super(key: key);

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

  // 🛡️ DYNAMIC INCENTIVE TARGET TUNERS:
  int _calibratedXpAmount = 100;
  double _calibratedCoinAmount = 10.00;

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

  Future<void> _generateDynamicQuestAndVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _loadingStatusText = "Preparing Your Financial Mission... 📝";
      });

      // 📡 LIVE PARAMETER CALIBRATION: Read target incentives set up by the parent account
      final String? profileId = supabaseService.currentUserId;
      if (profileId != null) {
        final profileMeta = await supabaseService.client
            .from('profiles')
            .select('video_xp_reward, video_coin_reward')
            .eq('id', profileId)
            .maybeSingle();

        if (profileMeta != null) {
          _calibratedXpAmount = (profileMeta['video_xp_reward'] as num?)?.toInt() ?? 100;
          _calibratedCoinAmount = (profileMeta['video_coin_reward'] as num?)?.toDouble() ?? 10.00;
        }
      }

      final randomEngine = math.Random();
      int newSelectionIndex = randomEngine.nextInt(eduVideosList.length);

      if (eduVideosList.length > 1 && widget.lastVideoIndex != null) {
        while (newSelectionIndex == widget.lastVideoIndex) {
          newSelectionIndex = randomEngine.nextInt(eduVideosList.length);
        }
      }

      if (widget.onVideoSelected != null) {
        widget.onVideoSelected!(newSelectionIndex);
      }

      _selectedVideoIndex = newSelectionIndex;
      final activeQuizData = eduVideosList[_selectedVideoIndex];

      final localQuest = QuestModel(
        id: "local-asset-quest-$_selectedVideoIndex",
        story: activeQuizData.question,
        choiceA: activeQuizData.options[0],
        choiceB: activeQuizData.options[1],
        outcomeA: "Awesome choice! 🐯 ${activeQuizData.keyLesson}",
        outcomeB: "Not quite! ${activeQuizData.keyLesson}",
        rewardXp: _calibratedXpAmount, // Injected user config
      );

      final String videoUrlPath = activeQuizData.assetPath;
      
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrlPath),
      );

      await _videoController!.initialize();
      await _videoController!.setVolume(1.0);
      await _videoController!.setLooping(true);
      await _videoController!.play();

      setState(() {
        _currentQuest = localQuest;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error loading video path: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load asset video: $e')),
        );
      }
    }
  }

  Future<void> _processQuestSelection(int chosenOptionIndex) async {
    final activeQuizData = eduVideosList[_selectedVideoIndex];
    final String? profileId = supabaseService.currentUserId;
    if (profileId == null) return;

    final bool isCorrect = chosenOptionIndex == activeQuizData.correctIndex;
    
    final String outcomeText = isCorrect 
        ? "Awesome choice! 🐯 ${activeQuizData.keyLesson}" 
        : "Not quite! ${activeQuizData.keyLesson}";

    _videoController?.pause(); 

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
                  
                  if (isCorrect)
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        final double scaleFactor = value < 0.4 
                            ? (value / 0.4) * 1.4  
                            : 1.4 - ((value - 0.4) / 0.6) * 0.4; 
                            
                        final double shakeFactor = math.sin(value * 4 * math.pi) * 0.15 * (1.0 - value); 
                        final double floatUpFactor = (1.0 - value) * -15; 

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
                  child: Text(
                    isCorrect ? 'Collect rewards! 🪙' : 'Got it! 👍', 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            );
          },
        ),
      );
    }

    // 2. 💾 SUPABASE REWARD INTEGRATION: Commits parent settings to data ledger
    if (isCorrect) {
      try {
        await Future.wait([
          supabaseService.client.rpc('increment_child_coins', params: {
            'user_id': profileId, 
            'coin_delta': _calibratedCoinAmount
          }),
          
          supabaseService.client.rpc('increment_child_xp', params: {
            'user_id': profileId, 
            'xp_delta': _calibratedXpAmount
          }),
          
          supabaseService.client.from('transactions').insert({
            'title': 'Video Question Milestone',
            'profile_id': profileId,
            'amount': _calibratedCoinAmount, 
            'category': 'Video Reward', 
            'created_at': DateTime.now().toIso8601String(),
          }),
        ]);
      } catch (e) {
        debugPrint('Direct Supabase transaction failure ledger exception: $e');
      }
    }

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
          : Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _currentStep == 0 
                      ? _buildVideoPlaybackStage() 
                      : _buildQuizAssessmentStage(),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: Color(0xFF9CA3AF), size: 28),
                    tooltip: 'Quit Mission',
                    onPressed: _showExitConfirmationDialog,
                  ),
                ),
              ],
            ),
    );
  }

  void _showExitConfirmationDialog() {
    _videoController?.pause();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Quit Mission? 🛑', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to close this mission? You won\'t get your shiny coins or XP points if you leave now!',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            onPressed: () {
              Navigator.pop(context); 
              _videoController?.play(); 
            },
            child: const Text('No, Keep Saving!', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(this.context); 
              
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.black,
                  content: Text('Too bad! You lost points! Skip missions means slower level ups!'),
                ),
              );
            },
            child: const Text('Yes, Quit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
            activeQuizData.question,
            style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF374151)),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'What strategy should we pick?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        
        Expanded(
          child: ListView.builder(
            itemCount: activeQuizData.options.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final String optionText = activeQuizData.options[index];
              
              const Color backgroundAccent = Color(0xFFEFF6FF); 
              const Color boundaryAccent = Color(0xFFBFDBFE);   
              const Color textAccent = Color(0xFF1E40AF);       
              const Color badgeBgColor = Color(0xFF3B82F6);     
              
              final String letterLabel = String.fromCharCode(65 + index); 

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _processQuestSelection(index),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: backgroundAccent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: boundaryAccent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            letterLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            optionText,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textAccent),
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

  Widget _buildXpBadge(bool isCorrect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFFBBF24) : Colors.grey[200],
        gradient: isCorrect ? const LinearGradient(
          colors: [Color(0xFFFFE17D), Color(0xFFF59E0B)], 
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
            isCorrect ? '+$_calibratedXpAmount XP' : '+0 XP', // Dynamically calibrated badge text
            style: TextStyle(
              color: isCorrect ? Colors.white : const Color(0xFF4B5563), 
              fontWeight: FontWeight.bold, 
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