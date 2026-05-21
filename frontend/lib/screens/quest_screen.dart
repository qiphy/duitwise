import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../supabase_service.dart';
import '../models.dart';

/// Global builder function to cleanly execute the interactive demo mission 
/// overlay framework from any action trigger point inside the application.
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
  int _currentStep = 0; // 0: Video Playback Stage, 1: Q&A Evaluation Stage
  String? _generatedVideoUrl;

  // 🔑 REPLACE THIS WITH YOUR ACTUAL JSON2VIDEO API KEY FOR YOUR DEMO
  final String _json2videoApiKey = "C3rggdtbnRNUJdBW3WyGc53WBHjKOXQ5freb8Bi5";

  @override
  void initState() {
    super.initState();
    _generateDynamicQuestAndVideo();
  }

  /// 🎬 This is the core interface method that talks DIRECTLY to JSON2Video API
  Future<void> _generateDynamicQuestAndVideo() async {
    try {
      setState(() => _isLoading = true);
      
      // Step 1: Create local placeholder quest details to build your financial question module
      // In a full build, this text can be randomly generated or pulled from your DB.
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

      // Step 2: Build the exact JSON body payload that JSON2Video requires to render an on-demand video clip
      final Map<String, dynamic> json2VideoPayload = {
        "comment": "Dynamic DuitWise Financial Education Mission Overlay Video clip asset",
        "width": 1080,
        "height": 1920, // Crisp vertical video aspect ratio matching modern mobile formats
        "fps": 30,
        "scenes": [
          {
            "duration": 5, // Video will play for 5 seconds
            "elements": [
              {
                "type": "image",
                "src": "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=600",
                "width": 1080,
                "height": 1920,
                "cache": true
              },
              {
                "type": "text",
                "text": mockQuest.title, // Injects your dynamic text straight into the video overlay template!
                "style": "bold",
                "font": "Arial",
                "size": 64,
                "color": "#FFFFFF",
                "position": "center",
                "y": 400
              },
              {
                "type": "text",
                "text": "Help Harimau make a smart choice!",
                "font": "Arial",
                "size": 42,
                "color": "#FBBF24", // Warm amber color
                "position": "center",
                "y": 600
              }
            ]
          }
        ]
      };

      // --- Step 3: Trigger the official JSON2Video API rendering job post request pipeline ---
            final response = await http.post(
              Uri.parse('https://api.json2video.com/v2/movies'), // Corrected endpoint with 's'
              headers: {
                'X-API-Key': _json2videoApiKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode(json2VideoPayload),
            );
            
            if (response.statusCode == 200 || response.statusCode == 201) {
              final Map<String, dynamic> responseData = jsonDecode(response.body);
              
              // Safely capture the video url string, ignoring any integer project IDs
              String? finalVideoUrl;
              
              if (responseData['project'] != null && responseData['project'] is Map) {
                finalVideoUrl = responseData['project']['url']?.toString();
              } else {
                finalVideoUrl = responseData['url']?.toString();
              }

              setState(() {
                _currentQuest = mockQuest;
                _generatedVideoUrl = finalVideoUrl; 
                _isLoading = false;
              });
            } else {
              throw Exception('JSON2Video server rejected payload parameters: ${response.body}');
            }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context); // Cleanly closes modal popup to avoid frozen views
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Direct JSON2Video link failure: $e')),
        );
      }
    }
  }

  Future<void> _processQuestSelection(bool choseA) async {
    if (_currentQuest == null) return;
    
    final profileId = supabaseService.currentUserId ?? "c8e3b7a1-d4f9-4b6e-a2c5-7f3e1b8d62a4";
    final outcomeText = choseA ? _currentQuest!.outcomeA : _currentQuest!.outcomeB;

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
      debugPrint('Silent wallet ledger tracking update error capture: $e');
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : _currentQuest == null
              ? const Center(child: Text('No active mission asset blocks found.'))
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _currentStep == 0 
                      ? _buildVideoPlaybackStage() 
                      : _buildQuizAssessmentStage(),
                ),
    );
  }

  // --- STAGE 0: Video Simulation Frame Layout ---
  Widget _buildVideoPlaybackStage() {
    final String streamTarget = _generatedVideoUrl ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=600';

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
              color: Colors.black87,
              borderRadius: BorderRadius.circular(24),
              image: streamTarget.startsWith('http') && !streamTarget.contains('.mp4')
                  ? DecorationImage(
                      image: NetworkImage(streamTarget),
                      fit: BoxFit.cover,
                      opacity: 0.35,
                    )
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, size: 56, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _currentQuest!.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.purple.withAlpha(100), borderRadius: BorderRadius.circular(8)),
                    child: const Text('✨ JSON2Video On-Demand Render Active', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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
            'I Finished Watching! ➡️',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // --- STAGE 1: Live Interactive Q&A Evaluation Frame Layout ---
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