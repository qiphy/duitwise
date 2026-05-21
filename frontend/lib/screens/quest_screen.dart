import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../supabase_service.dart';
import '../models.dart';
import '../widgets/quest_card.dart';

class QuestScreen extends StatefulWidget {
  const QuestScreen({Key? key}) : super(key: key);
  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  QuestModel? _currentQuest;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNewQuest();
  }

  Future<void> _fetchNewQuest() async {
    setState(() => _isLoading = true);
    final response = await http.get(Uri.parse('${supabaseService.backendBaseUrl}/quests/generate?level=1'));
    
    if (response.statusCode == 200) {
      setState(() {
        _currentQuest = QuestModel.fromJson(jsonDecode(response.body));
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load new narrative quest context.')),
      );
    }
  }

  Future<void> _processQuestSelection(bool choseA) async {
    if (_currentQuest == null) return;
    
    final profileId = supabaseService.currentUserId ?? "c8e3b7a1-d4f9-4b6e-a2c5-7f3e1b8d62a4";
    final outcomeText = choseA ? _currentQuest!.outcomeA : _currentQuest!.outcomeB;

    // Show explicit outcome dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mission Result! 🐯'),
        content: Text(outcomeText),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _fetchNewQuest(); // Cycle configuration to next quest sequence
            },
            child: const Text('Awesome!'),
          )
        ],
      ),
    );

    // Update wallet balances via backend routes asynchronously
    await http.post(
      Uri.parse('${supabaseService.backendBaseUrl}/wallet/$profileId/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'save_delta': choseA ? -5.00 : 5.00,
        'spend_delta': choseA ? 5.00 : 0.00,
        'share_delta': 0.00
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Missions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Make wise decisions to save Harimau Wira\'s coins!', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _currentQuest != null 
                ? Center(child: QuestCard(quest: _currentQuest!, onChoiceSelected: _processQuestSelection))
                : const Center(child: Text('No missions active.')),
          )
        ],
      ),
    );
  }
}