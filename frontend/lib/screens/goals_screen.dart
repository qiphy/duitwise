import 'package:flutter/material.dart';
import '../supabase_service.dart';
import '../widgets/progress_bar.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  Future<Map<String, dynamic>?>? _savingsGoalFuture;

  @override
  void initState() {
    super.initState();
    _fetchActiveSavingsGoal();
  }

  void _fetchActiveSavingsGoal() {
    final String? profileId = supabaseService.currentUserId;
    if (profileId != null) {
      setState(() {
        // ✅ FIXED: Selecting current_amount to match your actual database column layout
        _savingsGoalFuture = supabaseService.client
            .from('savings_goals')
            .select('goal_name, target_amount, current_amount')
            .eq('profile_id', profileId)
            .maybeSingle();
      });
    }
  }

@override
  Widget build(BuildContext context) {
    if (_savingsGoalFuture == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _savingsGoalFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
        }

        final goalData = snapshot.data;

        if (goalData == null) {
          return RefreshIndicator(
            color: const Color(0xFF8B5CF6),
            onRefresh: () async => _fetchActiveSavingsGoal(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                ),
                child: Column(
                  children: const [
                    Text('🎯', style: TextStyle(fontSize: 44)),
                    SizedBox(height: 12),
                    Text('No Dream Goal Set Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                    SizedBox(height: 6),
                    Text(
                      'Head over to your Smart Money Plan to lock in your first savings target!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final String goalName = goalData['goal_name'] ?? 'My Savings Dream';
        final double targetAmount = (goalData['target_amount'] ?? 0.0).toDouble();
        final double currentAmount = (goalData['current_amount'] ?? 0.0).toDouble();

        return RefreshIndicator(
          color: const Color(0xFF8B5CF6),
          onRefresh: () async => _fetchActiveSavingsGoal(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text('🎯', style: TextStyle(fontSize: 28)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goalName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Target allocation: RM ${targetAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // 📊 Progress bar uses raw metrics for width limits
                    ProgressBar(
                      currentXp: currentAmount.toInt(),
                      maxXp: targetAmount.toInt(),
                      isCurrency: true,
                    ),
                    const SizedBox(height: 12),
                    
                    // 🪙 Fiat balance metrics row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Saved: RM ${currentAmount.toStringAsFixed(2)} / RM ${targetAmount.toStringAsFixed(2)} 🟡',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                        ),
                        Text(
                          '${((currentAmount / (targetAmount > 0 ? targetAmount : 1)) * 100).toStringAsFixed(0)}% Completed',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}