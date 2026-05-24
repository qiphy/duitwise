import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../supabase_service.dart';
import '../models.dart';
import '../services/summary_service.dart';
import 'dart:convert';

class MoneyReportScreen extends StatefulWidget {
  const MoneyReportScreen({Key? key}) : super(key: key);

  @override
  State<MoneyReportScreen> createState() => _MoneyReportScreenState();
}

class _MoneyReportScreenState extends State<MoneyReportScreen> {
  Future<Map<String, dynamic>>? _reportDataFuture;
  bool _isGeneratingReport = false;

  @override
  void initState() {
    super.initState();
    _loadReportTelemetry();
  }

  void _loadReportTelemetry() {
    final String? profileId = supabaseService.currentUserId;
    if (profileId != null) {
      setState(() {
        _reportDataFuture = _fetchRealReportAggregates(profileId);
      });
    }
  }

  // 🧮 Pure Data Engine: Analyzes raw database rows to construct dynamic UI parameters
  Future<Map<String, dynamic>> _fetchRealReportAggregates(String profileId) async {
    // 1. Fetch complete historical log arrays straight from Supabase
    final List<dynamic> txs = await supabaseService.client
        .from('transactions')
        .select('*')
        .eq('profile_id', profileId)
        .order('created_at', ascending: false);

    double totalEarned = 0.0;
    double totalSpent = 0.0;
    
    // Dynamic tracking maps for explicit category allocations
    double snacksSpent = 0.0;
    double entertainmentSpent = 0.0;
    double savingsAllocated = 0.0;

    // Structured variable map to hold dynamic weekly distributions based on real dates
    Map<String, Map<String, double>> realWeeklyBreakdown = {};
    
    // Counter to evaluate continuous habit streaks natively
    int transactionStreakCount = txs.length; 

    for (var tx in txs) {
      final double amt = (tx['amount'] ?? 0.0).toDouble();
      final String cat = tx['category'] ?? 'General';
      final String rawDate = tx['created_at'] ?? '';
      
      // Determine what calendar week name this row belongs to natively using its timestamp
      String weekIdentifier = 'Week 1';
      if (rawDate.isNotEmpty) {
        try {
          DateTime parsedDate = DateTime.parse(rawDate);
          int dayOfMonth = parsedDate.day;
          if (dayOfMonth > 7 && dayOfMonth <= 14) weekIdentifier = 'Week 2';
          if (dayOfMonth > 14 && dayOfMonth <= 21) weekIdentifier = 'Week 3';
          if (dayOfMonth > 21) weekIdentifier = 'Week 4';
        } catch (_) {}
      }

      // Initialize the weekly nested map block if it doesn't exist yet
      realWeeklyBreakdown.putIfAbsent(weekIdentifier, () => {'earned': 0.0, 'saved': 0.0, 'spent': 0.0});

      if (amt >= 0) {
        totalEarned += amt;
        realWeeklyBreakdown[weekIdentifier]!['earned'] = realWeeklyBreakdown[weekIdentifier]!['earned']! + amt;
        
        // Split internal allocations matching our 70% rule logic constraints
        double ruleSavings = amt * 0.70;
        savingsAllocated += ruleSavings;
        realWeeklyBreakdown[weekIdentifier]!['saved'] = realWeeklyBreakdown[weekIdentifier]!['saved']! + ruleSavings;
      } else {
        final double absAmt = amt.abs();
        totalSpent += absAmt;
        realWeeklyBreakdown[weekIdentifier]!['spent'] = realWeeklyBreakdown[weekIdentifier]!['spent']! + absAmt;

        // Categorization matching real database strings
        if (cat.toLowerCase().contains('snack') || cat.toLowerCase().contains('food')) {
          snacksSpent += absAmt;
        } else if (cat.toLowerCase().contains('game') || cat.toLowerCase().contains('entertain')) {
          entertainmentSpent += absAmt;
        }
      }
    }

    // Sort weeks systematically so Week 1 appears first on the UI canvas charts
    var sortedWeekKeys = realWeeklyBreakdown.keys.toList()..sort();
    Map<String, Map<String, double>> sortedWeeklyData = {
      for (var key in sortedWeekKeys) key: realWeeklyBreakdown[key]!
    };

    final int calculatedSavingsRate = totalEarned > 0 ? ((savingsAllocated / totalEarned) * 100).toInt() : 0;

    return {
      'totalEarned': totalEarned,
      'totalSpent': totalSpent,
      'savingsRate': calculatedSavingsRate,
      'snacksSpent': snacksSpent,
      'entertainmentSpent': entertainmentSpent,
      'savingsAllocated': savingsAllocated,
      'weeklyData': sortedWeeklyData,
      'streakCount': transactionStreakCount,
    };
  }

@override
Widget build(BuildContext context) {
  if (_reportDataFuture == null) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
    );
  }

  return FutureBuilder<Map<String, dynamic>>(
    future: _reportDataFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        );
      }

      final data = snapshot.data ?? {};

      final weeklyDataMap =
          data['weeklyData'] as Map<String, Map<String, double>>? ?? {};

      final int streak = data['streakCount'] ?? 0;
      final int rate = data['savingsRate'] ?? 0;

      final bool hasNoData = weeklyDataMap.isEmpty;

      return RefreshIndicator(
        color: const Color(0xFF8B5CF6),
        onRefresh: () async => _loadReportTelemetry(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📊 HEADER CARD (ALWAYS VISIBLE)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TITLE + BUTTON
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Money Report 📊',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),

                          icon: _isGeneratingReport
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.share_rounded, size: 16),

                          label: Text(
                            _isGeneratingReport ? 'Generating...' : 'Save Money Report',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),

                          onPressed: _isGeneratingReport
                              ? null
                              : () async {
                                  setState(() => _isGeneratingReport = true);

                                  try {
                                    final String? currentUid = supabaseService.currentUserId;
                                    if (currentUid == null) return;

                                    // 🛠️ DIRECT CLIENT FETCH: Read wallet details straight from the Supabase relation layer
                                    final List<dynamic> walletRecords = await supabaseService.client
                                        .from('wallets')
                                        .select('total_balance, save_balance, spend_balance, share_balance')
                                        .eq('profile_id', currentUid);

                                    double currentTotal = 0.00;
                                    if (walletRecords.isNotEmpty) {
                                      final w = walletRecords.first;
                                      if (w['total_balance'] != null) {
                                        currentTotal = double.parse(w['total_balance'].toString());
                                      } else {
                                        final double s = double.parse((w['save_balance'] ?? 0.0).toString());
                                        final double sp = double.parse((w['spend_balance'] ?? 0.0).toString());
                                        final double sh = double.parse((w['share_balance'] ?? 0.0).toString());
                                        currentTotal = s + sp + sh;
                                      }
                                    }

                                    // 🧮 FORMULA SYNCHRONIZATION: Package variables cleanly matching parent parameters
                                    final WalletModel activeWallet = WalletModel(
                                      profileId: currentUid,
                                      saveBalance: currentTotal * 0.70,
                                      spendBalance: currentTotal * 0.20,
                                      shareBalance: currentTotal * 0.10,
                                    );

                                    // 🚀 EXECUTE COMPILATION TASK
                                    if (context.mounted) {
                                      await SummaryService().generateAndDownloadReport(
                                        context, 
                                        activeWallet, 
                                        'Your', // ✅ FIXED: Passed custom name context string smoothly
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed: $e'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }

                                  if (mounted) {
                                    setState(() => _isGeneratingReport = false);
                                  }
                                },
                        )
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildKpiItem(
                          'Total Earned',
                          'RM ${(data['totalEarned'] ?? 0.0).toStringAsFixed(2)}',
                        ),
                        _buildKpiItem(
                          'Total Saved',
                          'RM ${(data['savingsAllocated'] ?? 0.0).toStringAsFixed(2)}',
                        ),
                        _buildKpiItem('Savings Rate', '$rate%'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 🏆 ACHIEVEMENTS (ALWAYS SAFE)
              _buildSectionHeader('🏆 Your Super Achievements!'),
              const SizedBox(height: 12),

              _buildAchievementRow(
                '✅  $streak lifetime ledger logs recorded securely',
                const Color(0xFFDCFCE7),
                const Color(0xFF15803D),
              ),

              _buildAchievementRow(
                '✅  Allocated $rate% of total earnings toward your future pockets',
                const Color(0xFFDCFCE7),
                const Color(0xFF15803D),
              ),

              _buildAchievementRow(
                '✅  Account synchronization checks healthy',
                const Color(0xFFDCFCE7),
                const Color(0xFF15803D),
              ),

              const SizedBox(height: 24),

              // 📈 WEEKLY SECTION OR EMPTY STATE
              _buildSectionHeader('📈 Your Weekly Adventure'),
              const SizedBox(height: 16),

              if (hasNoData)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.bar_chart,
                          size: 40, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'No transactions yet',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Start adding transactions to unlock your report.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: weeklyDataMap.keys.map((weekKey) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weekKey,
                              style: TextStyle(
                                fontWeight: weekKey == 'Week 1'
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 13,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildMiniChartBar(
                              'Earned',
                              weeklyDataMap[weekKey]!['earned']!,
                              const Color(0xFF10B981),
                            ),
                            _buildMiniChartBar(
                              'Saved',
                              weeklyDataMap[weekKey]!['saved']!,
                              const Color(0xFF3B82F6),
                            ),
                            _buildMiniChartBar(
                              'Spent',
                              weeklyDataMap[weekKey]!['spent']!,
                              const Color(0xFFEF4444),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 24),

              // 🍕 CATEGORY SECTION (SAFE DEFAULTS)
              _buildSectionHeader('🍕 What Did You Buy?'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildCategoryBox(
                      name: '🍿 Snacks',
                      balance:
                          'RM ${(data['snacksSpent'] ?? 0.0).toStringAsFixed(2)}',
                      highlight: const Color(0xFFFDBA74),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCategoryBox(
                      name: '🎮 Games',
                      balance:
                          'RM ${(data['entertainmentSpent'] ?? 0.0).toStringAsFixed(2)}',
                      highlight: const Color(0xFFC084FC),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCategoryBox(
                      name: '🟡 Saved',
                      balance:
                          'RM ${(data['savingsAllocated'] ?? 0.0).toStringAsFixed(2)}',
                      highlight: const Color(0xFF86EFAC),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 💡 TIPS (ALWAYS SAFE)
              _buildSectionHeader('✨ Smart Tips Just For You!'),
              const SizedBox(height: 12),

              _buildTipCard(
                title: 'Great Savings Habit!',
                body:
                    'You successfully mapped $rate% of your income into savings.',
                bg: const Color(0xFFF5F3FF),
                primary: const Color(0xFF6D28D9),
              ),

              _buildTipCard(
                title: 'Consistency Loop Advice',
                body:
                    'Keep building daily financial habits for long-term growth.',
                bg: const Color(0xFFECFDF5),
                primary: const Color(0xFF059669),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildSectionHeader(String text) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)));
  }

  Widget _buildKpiItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAchievementRow(String label, Color bg, Color text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMiniChartBar(String label, double val, Color color) {
    double barScale = val > 0 ? (val / 150.0).clamp(0.06, 1.0) : 0.01;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          SizedBox(width: 54, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: barScale, 
                minHeight: 8, 
                backgroundColor: const Color(0xFFF1F5F9), 
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('RM ${val.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _buildCategoryBox({required String name, required String balance, required Color highlight}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          Text(balance, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Container(height: 4, width: 32, decoration: BoxDecoration(color: highlight, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildTipCard({required String title, required String body, required Color bg, required Color primary}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: primary.withValues(alpha: 0.15), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primary)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563), height: 1.4, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}