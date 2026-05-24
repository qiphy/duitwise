import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  final double currentXp;
  final double maxXp;
  final bool isCurrency; // ✅ Added flag to distinguish between XP tracking and Currency tracking

  const ProgressBar({
    Key? key, 
    required this.currentXp, 
    required this.maxXp,
    this.isCurrency = false, // Defaults to false so your Home Screen code remains completely unbroken!
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Prevent Division-by-Zero runtime faults cleanly
    double progress = maxXp > 0 ? (currentXp / maxXp).clamp(0.0, 1.0) : 0.0;
    
    // 🪙 Dynamic String Formatting Check
    final String displayMetricsText = isCurrency 
        ? 'RM ${currentXp.toString()} / RM ${maxXp.toString()}' // Used by Goals Screen
        : '$currentXp / $maxXp XP';                            // Used by Home Screen

    final String statusSubtitleText = isCurrency
        ? 'Goal Progress 🎯'
        : 'Next Level: Savings Star ⭐';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayMetricsText, 
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.bold),
            ),
            Text(
              statusSubtitleText, 
              style: TextStyle(
                fontSize: 12, 
                color: isCurrency ? const Color(0xFF16A34A) : const Color(0xFF8B5CF6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isCurrency ? const Color(0xFF10B981) : const Color(0xFF8B5CF6), // Green for money, Purple for XP
            ),
          ),
        ),
      ],
    );
  }
}