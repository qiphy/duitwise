import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  final int currentXp;
  final int maxXp;

  const ProgressBar({Key? key, required this.currentXp, required this.maxXp}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double progress = (currentXp / maxXp).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$currentXp / $maxXp XP', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const Text('Next Level: Savings Star ⭐', style: TextStyle(fontSize: 12, color: Color(0xFF8B5CF6))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
          ),
        ),
      ],
    );
  }
}