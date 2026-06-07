import 'package:flutter/material.dart';
import '../supabase_service.dart';
import '../widgets/progress_bar.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  // 🔄 Changed type to List<dynamic> to fetch both active and historic items
  Future<List<dynamic>>? _savingsGoalsFuture;
  
  final TextEditingController _goalNameController = TextEditingController();
  final TextEditingController _targetAmountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchSavingsGoalsData();
  }

  @override
  void dispose() {
    _goalNameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

void _fetchSavingsGoalsData() {
    final String? profileId = supabaseService.currentUserId;
    if (profileId != null) {
      setState(() {
        _savingsGoalsFuture = () async {
          // Concurrently pull all savings goal history rows and the live total wallet balance
          final futures = await Future.wait([
            supabaseService.client
                .from('savings_goals')
                .select('id, goal_name, target_amount, status')
                .eq('profile_id', profileId)
                .order('id', ascending: false), 
            supabaseService.client
                .from('wallets')
                // 🎯 FIX: Select the exact database column holding the locked savings pool
                .select('save_balance') 
                .eq('profile_id', profileId)
                .maybeSingle(),
          ]);

          final List<dynamic> allGoals = futures[0] as List<dynamic>;
          final walletData = futures[1] as Map<String, dynamic>?;

          // 🧮 Read the explicit, true save balance pool from your database row context
          final double actualSavedProgress = walletData != null ? (walletData['save_balance'] ?? 0.00).toDouble() : 0.00;

          // Map dynamic array data payloads seamlessly with the scaled balance metric
          return allGoals.map((goal) {
            return {
              'id': goal['id'],
              'goal_name': goal['goal_name'],
              'target_amount': goal['target_amount'],
              'status': goal['status'] ?? 'active',
              'current_amount': actualSavedProgress, // 🎯 Restored tracking matching the 70% Save Rule
            };
          }).toList();
        }();
      });
    }
  }

  Future<void> _submitNewGoalRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    final String? profileId = supabaseService.currentUserId;

    try {
      await supabaseService.client.from('savings_goals').insert({
        'profile_id': profileId,
        'goal_name': _goalNameController.text.trim(),
        'target_amount': double.parse(_targetAmountController.text.trim()),
        'status': 'pending_approval', 
      });

      _goalNameController.clear();
      _targetAmountController.clear();
      _fetchSavingsGoalsData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF3B82F6),
            content: Text('🚀 Sent to Mom & Dad for approval!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_savingsGoalsFuture == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    return FutureBuilder<List<dynamic>>(
      future: _savingsGoalsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
        }

        final allGoals = snapshot.data ?? [];

        // 🔍 Separate working goals from archived targets
        final activeGoals = allGoals.where((g) => g['status'] == 'active' || g['status'] == 'pending_approval').toList();
        final historicalGoals = allGoals.where((g) => g['status'] == 'achieved' || g['status'] == 'completed').toList();

        // 📝 INTERFACE A: NO ACTIVE GOAL ROW (Show Creation Form + Greyed History underneath)
        if (activeGoals.isEmpty) {
          return RefreshIndicator(
            color: const Color(0xFF8B5CF6),
            onRefresh: () async => _fetchSavingsGoalsData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: Text('🚀', style: TextStyle(fontSize: 44))),
                          const SizedBox(height: 12),
                          const Center(
                            child: Text(
                              'Set a New Dream Goal!', 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'What are we planning to save up for next?',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _goalNameController,
                        decoration: InputDecoration(
                          labelText: 'What is your dream goal?',
                          hintText: 'e.g., Bicycle, Lego Set, Nintendo Switch',
                          prefixIcon: const Icon(Icons.stars_rounded, color: Color(0xFF8B5CF6)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please name your next dream!' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _targetAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'How much does it cost? (RM)',
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.payments_rounded, color: Color(0xFF10B981)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        validator: (v) {
                          if (v == null || double.tryParse(v) == null) return 'Please enter a valid amount';
                          if (double.parse(v) <= 0) return 'Price must be more than RM 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _submitNewGoalRequest,
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Ask Parents to Approve 🎯', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                        ],
                      ),
                    ),

                    // 🏆 GREYED OUT HISTORICAL VAULT SECTION
                    if (historicalGoals.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Achieved Dreams Trophies 🏆', 
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ),
                      ...historicalGoals.map((g) {
                        final String pastName = g['goal_name'] ?? 'Past Goal';
                        final double pastTarget = (g['target_amount'] ?? 0.00).toDouble();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9), // Subtle clean slate grey background
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              const Text('👑', style: TextStyle(fontSize: 22)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pastName,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Target reached: RM ${pastTarget.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF94A3B8), size: 20),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        // 📊 INTERFACE B: CURRENT WORKING GOAL IS VISIBLE
        final dynamic activeGoal = activeGoals.first;
        final String goalName = activeGoal['goal_name'] ?? 'My Savings Dream';
        final double targetAmount = (activeGoal['target_amount'] ?? 0.00).toDouble();
        final double currentAmount = (activeGoal['current_amount'] ?? 0.00).toDouble();
        final String status = activeGoal['status'] ?? 'active';
        final bool isPending = status == 'pending_approval';

        return RefreshIndicator(
          color: const Color(0xFF8B5CF6),
          onRefresh: () async => _fetchSavingsGoalsData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: const Radius.circular(24), bottom: Radius.circular(isPending ? 24 : 24)),
                side: BorderSide(color: isPending ? const Color(0xFFFFEDD5) : const Color(0xFFF1F5F9), width: 1.5),
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
                            color: isPending ? const Color(0xFFFFF7ED) : const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(isPending ? '⏳' : '🎯', style: const TextStyle(fontSize: 28)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPending ? '$goalName (Waiting...)' : goalName,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isPending ? const Color(0xFFC2410C) : const Color(0xFF1F2937)),
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
                    
                    ProgressBar(
                      currentXp: isPending ? 0.0 : currentAmount.toDouble(),
                      maxXp: targetAmount.toDouble(),
                      isCurrency: true,
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isPending 
                              ? 'Waiting for Parent Approval 🔒' 
                              : '${((currentAmount / (targetAmount > 0 ? targetAmount : 1)) * 100).toStringAsFixed(0)}% Completed',
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold, 
                            color: isPending ? const Color(0xFFEA580C) : const Color(0xFF8B5CF6),
                          ),
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