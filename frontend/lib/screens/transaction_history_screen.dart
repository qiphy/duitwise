import 'package:flutter/material.dart';
import '../supabase_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _activeFilter = 'All'; // Choices: 'All', 'Income', 'Expenses'
  Future<List<dynamic>>? _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _getLedgerStream();
  }

  void _getLedgerStream() {
    final String? profileId = supabaseService.currentUserId;
    if (profileId != null) {
      setState(() {
        // Fetch rows directly matching the active child account profile UUID
        _transactionsFuture = supabaseService.client
            .from('transactions')
            .select('id, title, amount, type, category, created_at')
            .eq('profile_id', profileId)
            .order('created_at', ascending: false);
      });
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<List<dynamic>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ledger sync failed: ${snapshot.error}'));
          }

          final List<dynamic> rawTransactions = snapshot.data ?? [];

          // 🧮 Compute Real-time Metric Aggregates directly from Supabase Data
          double totalIncome = 0.00;
          double totalExpenses = 0.00;
          int incomeCount = 0;
          int expenseCount = 0;

          for (var tx in rawTransactions) {
            final double amt = (tx['amount'] ?? 0.0).toDouble();
            if (amt >= 0) {
              totalIncome += amt;
              incomeCount++;
            } else {
              totalExpenses += amt.abs();
              expenseCount++;
            }
          }

          // Apply local filter switching parameters logic
          final filteredTransactions = rawTransactions.where((tx) {
            final double amt = (tx['amount'] ?? 0.0).toDouble();
            if (_activeFilter == 'Income') return amt >= 0;
            if (_activeFilter == 'Expenses') return amt < 0;
            return true;
          }).toList();

          return RefreshIndicator(
            color: const Color(0xFF8B5CF6),
            onRefresh: () async => _getLedgerStream(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // 💳 MATCHING OVERVIEW BANNERS: Income & Expenses Status Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: '💰 Money Coming In',
                          amount: 'RM ${totalIncome.toStringAsFixed(2)}',
                          subtitle: '$incomeCount times you earned! 🚀',
                          baseColor: const Color(0xFF10B981),
                          icon: Icons.south_west_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          title: '🛍️ Money Going Out',
                          amount: 'RM ${totalExpenses.toStringAsFixed(2)}',
                          subtitle: '$expenseCount times you spent',
                          baseColor: const Color(0xFFEC4899),
                          icon: Icons.north_east_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ✅ UNIFIED TITLE & DOWNLOAD ACTION TERM ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '📜 Your Money Story',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'See where your money comes from and where it goes! 📊',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // 📥 NATIVE COMPACT REPORT TRIGGER BTN
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 🎛️ MATCHING PILL TOGGLE BAR
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _buildFilterPill('All (${rawTransactions.length})', 'All'),
                        _buildFilterPill('Income ($incomeCount)', 'Income'),
                        _buildFilterPill('Expenses ($expenseCount)', 'Expenses'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🎯 DYNAMIC DATA LEDGER LIST
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                    ),
                    child: filteredTransactions.isEmpty
                        ? _buildEmptyStatePlaceholder()
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredTransactions.length,
                            separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                            itemBuilder: (context, index) {
                              final tx = filteredTransactions[index];
                              final double amount = (tx['amount'] ?? 0.0).toDouble();
                              final bool isIncome = amount >= 0;
                              final String title = tx['title'] ?? 'Coin Transaction';
                              final String category = tx['category'] ?? (isIncome ? 'Task' : 'Snacks');
                              
                              final String rawDate = tx['created_at'] ?? '';
                            final String displayDate = rawDate.isNotEmpty
                                ? _parseDisplayDate(rawDate) // Passed as a clean positional argument
                                : 'Recent';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFFCE7F3),
                                      child: Icon(
                                        isIncome ? Icons.trending_up_rounded : Icons.shopping_bag_outlined,
                                        color: isIncome ? const Color(0xFF16A34A) : const Color(0xFFB70E5C),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isIncome ? const Color(0xFFE8F5E9) : const Color(0xFFFCE7F3),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  category,
                                                  style: TextStyle(
                                                    color: isIncome ? const Color(0xFF2E7D32) : const Color(0xFFB70E5C),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                displayDate,
                                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${isIncome ? "+" : "-"}RM ${amount.abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 🏛️ REUSABLE UI CARD COMPONENT METHODS
  // ==========================================

  Widget _buildMetricCard({
    required String title,
    required String amount,
    required String subtitle,
    required Color baseColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: baseColor.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: Colors.white, size: 14),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String text, String targetFilter) {
    final bool isSelected = _activeFilter == targetFilter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeFilter = targetFilter),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF1E2937) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStatePlaceholder() {
    return const Padding(
      padding: EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          children: [
            Text('🔍', style: TextStyle(fontSize: 32)),
            SizedBox(height: 8),
            Text('No rows found matching this view category.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  String _parseDisplayDate(String isoString) {
    try {
      final DateTime parsed = DateTime.parse(isoString).toLocal();
      final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${months[parsed.month - 1]} ${parsed.day}";
    } catch (_) {
      return 'Recent';
    }
  }
}