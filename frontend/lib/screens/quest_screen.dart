import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Added for Timer polling
import 'package:video_player/video_player.dart';

import '../supabase_service.dart';
import '../models.dart';

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

  Future<void> _generateDynamicQuestAndVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _loadingStatusText = "Drafting Financial Mission... 📝";
      });
      
      final mockQuest = QuestModel(
        id: "demo-quest-id",
        title: "Harimau's Ice Cream Dilemma! 🍦",
        story: "Harimau Wira wants a treat. A premium ice cream cone costs RM 10.00, but a simple popsicle costs only RM 2.00. He wants to save up for a new bicycle. What should he do?",
        choiceA: "Buy the premium RM 10 ice cream cone immediately.",
        choiceB: "Buy the RM 2 popsicle and save the remaining RM 8.",
        outcomeA: "Oh no! The premium ice cream tasted great, but Harimau spent almost all his wallet allowance. Saving for the bicycle will take much longer now! 😿",
        outcomeB: "Awesome choice! 🐯 Harimau satisfied his sweet tooth and successfully stashed away RM 8.00 into his savings vault. He's getting closer to that bicycle!",
        rewardXp: 20,
      );

      setState(() {
        _loadingStatusText = "Firin' up Magic Hour Engine... 🤖";
      });

      // 🎬 STEP 1: Post request to Magic Hour Text-to-Video API
      final response = await http.post(
        Uri.parse('https://api.magichour.ai/v1/text-to-video'),
        headers: {
          'Authorization': 'Bearer $_magicHourApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "name": "Harimau Ice Cream Video",
          "end_seconds": 4,  
          "aspect_ratio": "1:1", // Valid entries: "16:9", "9:16", "1:1"
          "resolution": "480p",  // Defaults to 480p on free tier/720p on paid tiers
          "style": {
            "prompt": "Cute 3D claymation style tiger character holding an ice cream cone, vibrant colors, animation loop",
          }
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Magic Hour rejected request: ${response.body}");
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final String projectId = responseData['id'] ?? responseData['project_id'];

      // 🔄 STEP 2: Poll status endpoint until completion
      setState(() {
        _loadingStatusText = "Rendering AI visual sequences... 🎬";
      });

      final String finalVideoUrl = await _pollVideoStatus(projectId);

      // 🎥 STEP 3: Handle native initialization on verified asset loop
      _videoController = VideoPlayerController.networkUrl(Uri.parse(finalVideoUrl));
      await _videoController!.initialize();
      await _videoController!.setVolume(0.0); 
      await _videoController!.setLooping(true);
      await _videoController!.play(); 

      setState(() {
        _currentQuest = mockQuest;
        _isLoading = false; 
      });

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mission rendering error: $e')),
        );
      }
    }
  }

  // Polling helper logic loops gracefully every 4 seconds to limit rate limits
Future<String> _pollVideoStatus(String projectId) async {
    final completer = Completer<String>();
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      try {
        final statusResponse = await http.get(
          Uri.parse('https://api.magichour.ai/v1/video-projects/$projectId'),
          headers: {'Authorization': 'Bearer $_magicHourApiKey'},
        );

        if (statusResponse.statusCode == 200) {
          final data = jsonDecode(statusResponse.body) as Map<String, dynamic>;
          final String status = (data['status'] ?? '').toString();

          if (status == 'complete') {
            timer.cancel();
            
            final downloads = data['downloads'];
            String? validatedUrl;

            if (downloads is List && downloads.isNotEmpty) {
              final firstItem = downloads.first;
              if (firstItem is Map) {
                // Extracts the actual direct string property inside the list object
                validatedUrl = (firstItem['url'] ?? firstItem['video'])?.toString();
              } else {
                validatedUrl = firstItem.toString();
              }
            } else if (downloads is Map) {
              // ✨ Fixed: Explicitly targets the nested link parameter string key
              validatedUrl = (downloads['url'] ?? downloads['video'] ?? data['download_url'])?.toString();
            } else {
              validatedUrl = data['download_url']?.toString();
            }

            if (validatedUrl != null && validatedUrl.isNotEmpty && validatedUrl.startsWith('http')) {
              completer.complete(validatedUrl);
            } else {
              completer.completeError("Format extraction failure. Received string content: $downloads");
            }
          } else if (status == 'error') {
            timer.cancel();
            completer.completeError("Magic Hour backend failed during video processing render.");
          } else {
            debugPrint("Magic Hour video processing progress status: $status");
          }
        } else {
          timer.cancel();
          completer.completeError("Server rejected status check (${statusResponse.statusCode}): ${statusResponse.body}");
        }
      } catch (e) {
        timer.cancel();
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  Future<void> _processQuestSelection(bool choseA) async {
    if (_currentQuest == null) return;
    
    final profileId = supabaseService.currentUserId ?? "c8e3b7a1-d4f9-4b6e-a2c5-7f3e1b8d62a4";
    final outcomeText = choseA ? _currentQuest!.outcomeA : _currentQuest!.outcomeB;

    _videoController?.pause(); 

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Mission Result! 🐯', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(outcomeText, style: const TextStyle(fontSize: 15, height: 1.4)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Awesome!', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      );
    }

    try {
      await http.post(
        Uri.parse('${supabaseService.backendBaseUrl}/wallet/$profileId/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'save_delta': choseA ? -5.00 : 5.00,
          'spend_delta': choseA ? 5.00 : 0.00,
          'share_delta': 0.00
        }),
      );
    } catch (e) {
      debugPrint('Silent balance sync failure fallback logic: $e');
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
        const Text(
          "Watch closely to help Harimau Wira select the wisest route!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
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
                    left: 24,   
                    right: 24,  
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentQuest!.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black, blurRadius: 8, offset: Offset(2, 2))]
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Help Harimau choose wisely!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFA7F3D0),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            shadows: [Shadow(color: Colors.black, blurRadius: 6, offset: Offset(1, 1))]
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.teal.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                      child: const Text('✨ Magic Hour Engine Active', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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
            _currentQuest!.story,
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
          child: InkWell(
            onTap: () => _processQuestSelection(true),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
              ),
              child: Row(
                children: [
                  const Text('🅰️', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _currentQuest!.choiceA,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        Expanded(
          child: InkWell(
            onTap: () => _processQuestSelection(false),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
              ),
              child: Row(
                children: [
                  const Text('🅱️', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _currentQuest!.choiceB,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}