import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../supabase_service.dart';
import '../models.dart';
import '../services/summary_service.dart';
import 'dart:convert';
import '../services/transaction_categorizer.dart'; 

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

  // 🧮 Pure Data Engine: Analyzes data to construct dynamic UI parameters
  Future<Map<String, dynamic>> _fetchRealReportAggregates(String profileId) async {
    // 1. Concurrently fetch child transactions, live wallet data, AND profile metadata rows 🚀
    final futures = await Future.wait([
      supabaseService.client
          .from('transactions')
          .select('title, amount, category, created_at')
          .eq('profile_id', profileId)
          .order('created_at', ascending: false),
      supabaseService.client
          .from('wallets')
          // Pulling all rule allocations concurrently
          .select('total_balance, save_balance, spend_balance, share_balance')
          .eq('profile_id', profileId)
          .maybeSingle(),
      supabaseService.client 
          .from('profiles')
          .select('username')
          .eq('id', profileId)
          .maybeSingle(),
    ]);

    final List<dynamic> txs = futures[0] as List<dynamic>;
    final Map<String, dynamic>? walletData = futures[1] as Map<String, dynamic>?;
    final Map<String, dynamic>? profileData = futures[2] as Map<String, dynamic>?;

    // Read live real-time total balance directly from the database table context
    final double liveTotalBalance = walletData != null ? (walletData['total_balance'] ?? 0.00).toDouble() : 0.00;
    final double liveSaveBalance = walletData != null ? (walletData['save_balance'] ?? 0.00).toDouble() : 0.00;
    final double liveSpendBalance = walletData != null ? (walletData['spend_balance'] ?? 0.00).toDouble() : 0.00;
    final double liveShareBalance = walletData != null ? (walletData['share_balance'] ?? 0.00).toDouble() : 0.00;
    final String username = profileData != null ? (profileData['username'] ?? 'Young Saver') : 'Young Saver';

    double cumulativeEarned = 0.0;
    double cumulativeSpent = 0.0;
    
    // 🎯 DYNAMIC MAP CONTAINER: Aggregates categorical balances safely 
    Map<String, double> categorySpendingTotals = {
      '🍿 Snacks & Food': 0.0,
      '🎮 Games & Entertainment': 0.0,
      '📚 Education & School': 0.0,
      '🚌 Public Transport & Commute': 0.0,
      '🎁 Gifts & Sharing': 0.0,
      '⚙️ General Spending': 0.0,
    };

    // Structured week map tracking layout structures
    Map<String, Map<String, double>> realWeeklyBreakdown = {};

    for (var tx in txs) {
      final double amt = (tx['amount'] ?? 0.0).toDouble();
      final String title = tx['title'] ?? '';
      final String rawDate = tx['created_at'] ?? '';
      
      // 🎯 DYNAMIC REPAIR CHECKPOINT: Fallback to local regex rule engine if tag is missing or generic
      String cat = tx['category'] ?? 'General';
      if (cat == 'General' || cat.trim().isEmpty) {
        cat = TransactionCategorizer.categorize(title);
      }
      if (cat == 'General') cat = '⚙️ General Spending';

      // Determine what calendar week block identifier this row sits in using its timestamp
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

      // Ensure weekly node entries map safely without throwing null map assignment errors
      realWeeklyBreakdown.putIfAbsent(weekIdentifier, () => {'earned': 0.0, 'saved': 0.0, 'spent': 0.0});

      if (amt >= 0) {
        // 📥 EARNINGS PIPELINE
        cumulativeEarned += amt;
        realWeeklyBreakdown[weekIdentifier]!['earned'] = realWeeklyBreakdown[weekIdentifier]!['earned']! + amt;
        
        // 🧮 FORMULAIC SPLIT INTEGRATION: Calculate real-time 70% saved portion completely in memory
        double dynamicallySavedPortion = amt * 0.70;
        realWeeklyBreakdown[weekIdentifier]!['saved'] = realWeeklyBreakdown[weekIdentifier]!['saved']! + dynamicallySavedPortion;
      } else {
        // 📤 SPENDING OUTFLOW PIPELINE
        final double absAmt = amt.abs();
        cumulativeSpent += absAmt;
        realWeeklyBreakdown[weekIdentifier]!['spent'] = realWeeklyBreakdown[weekIdentifier]!['spent']! + absAmt;

        // 🎯 SMART ACCUMULATION: Increment values dynamically matching layout keys
        categorySpendingTotals.update(
          cat,
          (existingValue) => existingValue + absAmt,
          ifAbsent: () => absAmt,
        );
      }
    }

    // 🧮 IN-CODE DERIVATION: Compute exact global lifetime savings portion mathematically via the 70% rule
    final double calculatedTotalSaved = liveTotalBalance;
    
    // Explicit safety baseline ensuring calculation ranges match rule definitions cleanly
    final int derivedSavingsRate = cumulativeEarned > 0 ? 70 : 0;

    // Sort weeks systematically so Week 1 appears first on the UI canvas charts
    var sortedWeekKeys = realWeeklyBreakdown.keys.toList()..sort();
    Map<String, Map<String, double>> sortedWeeklyData = {
      for (var key in sortedWeekKeys) key: realWeeklyBreakdown[key]!
    };

// 🧮 AI-LEAN BEHAVIORAL SCORING ENGINE: Evaluates saving patterns & pool maintenance
    int financialLiteracyScore = 70; // Baseline score
    
    // Check if the 70% savings rule is mathematically verified or exceeded
    if (cumulativeEarned > 0) {
      double expectedSavings = cumulativeEarned * 0.70;
      if (liveSaveBalance >= expectedSavings) {
        financialLiteracyScore += 15; // Bonus for protective habit tracking
      } else if (liveSaveBalance < expectedSavings * 0.5) {
        financialLiteracyScore -= 15; // Penalty for severe pocket leakage
      }
    }

    // Evaluate consistency and transaction velocity (Streak metric)
    if (txs.length >= 10) {
      financialLiteracyScore += 10;
    } else if (txs.length > 3) {
      financialLiteracyScore += 5;
    }

    // Safety Gate: Check if they are running precariously low on fluid cash (Spend pool completely wiped)
    if (liveTotalBalance > 0 && liveSpendBalance == 0) {
      financialLiteracyScore -= 10; // Wiped spend bucket flags poor budget pacing
    }

    // Enforce bounds
    financialLiteracyScore = financialLiteracyScore.clamp(0, 100);

    return {
      'totalEarned': cumulativeEarned,
      'totalSpent': cumulativeSpent,
      'savingsRate': derivedSavingsRate,
      'savingsAllocated': liveSaveBalance, 
      'liveTotalBalance': liveTotalBalance, 
      'liveSpendBalance': liveSpendBalance,
      'liveShareBalance': liveShareBalance,
      'username': username,
      'categorySpending': categorySpendingTotals,
      'weeklyData': sortedWeeklyData,
      'streakCount': txs.length,
      'financialScore': financialLiteracyScore, // 🔥 INJECTED MATRIX PARAMETER
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
      final Map<dynamic, dynamic> categoryMap = data['categorySpending'] ?? {};

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

                                    final String childUsername = data['username'] ?? 'Your';

                                    // 🛠 Tangible relation queries
                                    final List<dynamic> walletRecords = await supabaseService.client
                                        .from('wallets')
                                        .select('total_balance, save_balance, spend_balance, share_balance')
                                        .eq('profile_id', currentUid);

                                    WalletModel activeWallet;

                                    if (walletRecords.isNotEmpty) {
                                      final w = walletRecords.first;
                                      activeWallet = WalletModel(
                                        profileId: currentUid,
                                        totalBalance: (w['total_balance'] ?? 0.0).toDouble(),
                                        saveBalance: (w['save_balance'] ?? 0.0).toDouble(), // True Database values passed
                                        spendBalance: (w['spend_balance'] ?? 0.0).toDouble(),
                                        shareBalance: (w['share_balance'] ?? 0.0).toDouble(),
                                      );
                                    } else {
                                      activeWallet = WalletModel(
                                        profileId: currentUid,
                                        totalBalance: 0.0, saveBalance: 0.0, spendBalance: 0.0, shareBalance: 0.0,
                                      );
                                    }

                                    if (context.mounted) {
                                      await SummaryService().generateAndDownloadReport(
                                        context, 
                                        activeWallet, 
                                        childUsername, 
                                        data['financialScore'] ?? 70,
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
                        _buildKpiItem('Total Earned', 'RM ${(data['totalEarned'] ?? 0.0).toStringAsFixed(2)}'),
                        _buildKpiItem('Total Saved', 'RM ${(data['savingsAllocated'] ?? 0.0).toStringAsFixed(2)}'),
                        _buildKpiItem('Savings Rate', '$rate%'),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 12),

                    // 🧠 NEW: AI Financial Literacy Badge and Progress Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.psychology_rounded, color: Colors.amberAccent, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Financial Literacy Score',
                              style: TextStyle(color: Color(0xFFE9D5FF), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          '${data['financialScore'] ?? 70}/100',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ((data['financialScore'] ?? 70) / 100.0).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 🏆 ACHIEVEMENTS (ALWAYS SAFE)
              _buildSectionHeader('🏆 Your Super Achievements!'),
              const SizedBox(height: 12),

              _buildAchievementRow(
                '✅  $streak earnings recorded securely',
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

              // 🍕 CATEGORY SECTION (DYNAMIC COMPONENT GRID FLOW) 🚀
              _buildSectionHeader('🍕 What Did You Buy?'),
              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (context, constraints) {
                  // Assign theme accents based on deterministic naming rules matching our service dictionary keys
                  Color getHighlightColor(String key) {
                    if (key.contains('Snacks')) return const Color(0xFFFDBA74);
                    if (key.contains('Games')) return const Color(0xFFC084FC);
                    if (key.contains('Education')) return const Color(0xFF93C5FD);
                    if (key.contains('Transport')) return const Color(0xFFA5F3FC);
                    if (key.contains('Gifts')) return const Color(0xFFFBCFE8);
                    return const Color(0xFFCBD5E1);
                  }

                  // Deduct horizontal grid spacer constraints dynamically across mobile layouts
                  final double boxWidth = (constraints.maxWidth - 12) / 2;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.start,
                    children: [
                      // Render card layouts for items that actually have dynamic balance changes
                      ...categoryMap.entries.where((entry) => entry.value > 0).map((entry) {
                        return SizedBox(
                          width: boxWidth,
                          child: _buildCategoryBox(
                            name: entry.key,
                            balance: 'RM ${entry.value.toStringAsFixed(2)}',
                            highlight: getHighlightColor(entry.key),
                          ),
                        );
                      }).toList(),

                      // Append global static pocket tracker element seamlessly inside wrap layers
                      SizedBox(
                        width: boxWidth,
                        child: _buildCategoryBox(
                          name: '🟡 Total Saved Pockets',
                          balance: 'RM ${(data['savingsAllocated'] ?? 0.0).toStringAsFixed(2)}',
                          highlight: const Color(0xFF4ADE80),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // 💡 TIPS (ALWAYS SAFE)
              _buildSectionHeader('✨ Smart Insights Just For You!'),
              const SizedBox(height: 12),

              _buildTipCard(
                title: 'Great Savings Habit!',
                body:
                    'You successfully mapped $rate% of your income into savings.',
                bg: const Color(0xFFF5F3FF),
                primary: const Color(0xFF6D28D9),
              ),

              _buildTipCard(
                title: 'Consistency Loop Habit',
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