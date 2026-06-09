import 'package:flutter/material.dart';
import '../supabase_service.dart';
import '../models.dart';
import '../services/summary_service.dart';

class ParentTaskManagerSheet extends StatefulWidget {
  final String childName;
  final String childId;

  const ParentTaskManagerSheet({
    Key? key,
    required this.childName,
    required this.childId,
  }) : super(key: key);

  @override
  State<ParentTaskManagerSheet> createState() => _ParentTaskManagerSheetState();
}

class _ParentTaskManagerSheetState extends State<ParentTaskManagerSheet> {
  int _selectedTabIdx = 0;
  bool _isLoadingConfig = true;
  bool _isAccountFrozen = false;
  bool _restrictVisibility = false;
  bool _showSettings = false;

  int _currentVideoXp = 100;
  double _currentVideoCoins = 10.00;

  final TextEditingController _xpController = TextEditingController();
  final TextEditingController _coinsController = TextEditingController();
  final GlobalKey<FormState> _settingsFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadChildGuardrailSettings();
  }

  @override
  void dispose() {
    _xpController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  Future<void> _loadChildGuardrailSettings() async {
    try {
      final snapshot = await supabaseService.client
          .from('profiles')
          .select('is_frozen, parental_content_restriction, video_xp_reward, video_coin_reward')
          .eq('id', widget.childId)
          .maybeSingle();

      if (snapshot != null && mounted) {
        setState(() {
          _isAccountFrozen = snapshot['is_frozen'] ?? false;
          _restrictVisibility = snapshot['parental_content_restriction'] ?? false;
          _currentVideoXp = (snapshot['video_xp_reward'] as num?)?.toInt() ?? 100;
          _currentVideoCoins = (snapshot['video_coin_reward'] as num?)?.toDouble() ?? 10.00;

          _xpController.text = _currentVideoXp.toString();
          _coinsController.text = _currentVideoCoins.toStringAsFixed(2);
          _isLoadingConfig = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading child settings parameters: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          _buildHeaderControlPad(),
          const SizedBox(height: 20),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: (_showSettings && !_isLoadingConfig)
                  ? _buildSettingsFormView()
                  : _buildFeedsDashboardView(),
            ),
          ),
          const SizedBox(height: 16),
          _buildBottomActionRow(),
        ],
      ),
    );
  }

  // --- SUB-WIDGETS DIRECT COMPOSITION ---

Widget _buildHeaderControlPad() {
  return FutureBuilder<List<dynamic>>(
    future: supabaseService.client
        .from('wallets')
        .select('total_balance, save_balance, spend_balance, share_balance')
        .eq('profile_id', widget.childId),
    builder: (context, walletSnapshot) {
      final walletData = walletSnapshot.data ?? [];
      double currentTotal = 0.00;
      double currentSave = 0.00;
      double currentSpend = 0.00;
      double currentShare = 0.00;
      
      if (walletData.isNotEmpty) {
        final firstWallet = walletData.first;
        
        // ✨ FIX 1: Correctly extract and store sub-allocation pocket values
        currentSave = double.parse((firstWallet['save_balance'] ?? 0.0).toString());
        currentSpend = double.parse((firstWallet['spend_balance'] ?? 0.0).toString());
        currentShare = double.parse((firstWallet['share_balance'] ?? 0.0).toString());
        
        if (firstWallet['total_balance'] != null) {
          currentTotal = double.parse(firstWallet['total_balance'].toString());
        } else {
          currentTotal = currentSave + currentSpend + currentShare;
        }
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 600;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isNarrow ? constraints.maxWidth : constraints.maxWidth * 0.45,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _showSettings ? 'Settings: ${widget.childName} ⚙️' : '${widget.childName}\'s Hub 🚀',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            _showSettings ? Icons.close_rounded : Icons.settings_outlined,
                            color: const Color(0xFF8B5CF6),
                            size: 22,
                          ),
                          onPressed: () => setState(() => _showSettings = !_showSettings),
                          tooltip: 'Toggle Parental Control Restrictions Settings',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Balance: RM ${currentTotal.toStringAsFixed(2)} 🟡',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                    ),
                  ],
                ),
              ),
              Container(
                width: isNarrow ? constraints.maxWidth : constraints.maxWidth * 0.50,
                alignment: isNarrow ? Alignment.centerLeft : Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                      label: const Text('Download Monthly Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () async {
                        // ✨ FIX 2: Pass fully hydrated wallet parameters down the pipeline
                        final WalletModel childWalletContext = WalletModel(
                          profileId: widget.childId,
                          totalBalance: currentTotal, 
                          saveBalance: currentSave,   
                          spendBalance: currentSpend, 
                          shareBalance: currentShare, 
                        );

                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Generating monthly report statement for ${widget.childName}...')),
                          );

                          // 🧠 DYNAMIC SYNC: Fetch history ledger to run our unified math calculation
                          final List<dynamic> liveTxData = await supabaseService.client
                              .from('transactions')
                              .select('title, category, amount')
                              .eq('profile_id', widget.childId)
                              .order('created_at', ascending: false);

                          // ✨ FIX 3: Calculate the definitive score on demand using the shared scoring rules
                          final int alignedScore = SummaryService.calculateFinancialScore(
                            transactions: liveTxData,
                            saveBalance: currentSave,
                            spendBalance: currentSpend,
                            totalBalance: currentTotal,
                          );

                          // Execute rendering with the correct positional parameters intact
                          await SummaryService().generateAndDownloadReport(
                            context, 
                            childWalletContext, 
                            widget.childName,
                          );
                          
                          if (context.mounted) ScaffoldMessenger.of(context).clearSnackBars();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: Colors.redAccent, content: Text('Failed to compile document: $e')),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      label: const Text('Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => Navigator.pop(context, 'transfer'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

  Widget _buildSettingsFormView() {
    return Form(
      key: _settingsFormKey,
      child: ListView(
        key: const ValueKey('parent_settings_view'),
        physics: const BouncingScrollPhysics(),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Text('Safety Guardrails 🔐', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            title: const Text('Freeze Wallet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
            subtitle: const Text('Instantly blocks outbound merchant payments and dynamic fun-budget disbursements.', style: TextStyle(fontSize: 11)),
            value: _isAccountFrozen,
            activeColor: const Color(0xFF8B5CF6),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            onChanged: (val) async {
              setState(() => _isAccountFrozen = val ?? false);
              await supabaseService.client.from('profiles').update({'is_frozen': _isAccountFrozen}).eq('id', widget.childId);
            },
          ),
          const Divider(color: Color(0xFFF1F5F9)),
          CheckboxListTile(
            title: const Text('Restrict Feed Content', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
            subtitle: const Text('Simplifies application layout parameters; hides experimental transaction models.', style: TextStyle(fontSize: 11)),
            value: _restrictVisibility,
            activeColor: const Color(0xFF8B5CF6),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            onChanged: (val) async {
              setState(() => _restrictVisibility = val ?? false);
              await supabaseService.client.from('profiles').update({'parental_content_restriction': _restrictVisibility}).eq('id', widget.childId);
            },
          ),
          const Divider(color: Color(0xFFF1F5F9)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Text('Quest Incentive Calibration 🎞️', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _xpController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Video Quest XP Payout',
              suffixText: 'XP',
              prefixIcon: const Icon(Icons.bolt_rounded, color: Color(0xFF8B5CF6), size: 20),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) async {
              final parsedXp = int.tryParse(val.trim());
              if (parsedXp != null && parsedXp >= 0) {
                _currentVideoXp = parsedXp;
                await supabaseService.client.from('profiles').update({'video_xp_reward': _currentVideoXp}).eq('id', widget.childId);
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _coinsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Allowance Coin Reward',
              prefixText: 'RM ',
              prefixIcon: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 20),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) async {
              final parsedCoins = double.tryParse(val.trim());
              if (parsedCoins != null && parsedCoins >= 0.0) {
                _currentVideoCoins = parsedCoins;
                await supabaseService.client.from('profiles').update({'video_coin_reward': _currentVideoCoins}).eq('id', widget.childId);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeedsDashboardView() {
    return Column(
      key: const ValueKey('feeds_dashboard_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildSegmentTab(label: 'Tasks 🎯', index: 0),
              _buildSegmentTab(label: 'Saving Goals 💎', index: 1),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selectedTabIdx == 0 ? _buildTasksTabFeed() : _buildGoalsTabFeed(),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentTab({required String label, required int index}) {
    final bool isSelected = _selectedTabIdx == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIdx = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

Widget _buildTasksTabFeed() {
  return FutureBuilder<List<dynamic>>(
        // 🎯 FIX: Changed from a static string to a dynamic childId key to flush the cache
        key: ValueKey('tasks_tab_stream_${widget.childId}'),
        future: supabaseService.client
            .from('tasks')
            .select('id, title, description, reward_amount, status, proof_url, recurring_interval')
            .eq('profile_id', widget.childId)
            .order('id', ascending: false),
        builder: (context, taskSnapshot) {
        if (taskSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
        }
        final tasks = taskSnapshot.data ?? [];
        if (tasks.isEmpty) {
          return const Center(child: Text('No tasks assigned yet.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)));
        }

        return ListView.builder(
          itemCount: tasks.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, idx) {
            final t = tasks[idx];
            final String taskId = t['id'].toString();
            final String title = t['title'] ?? 'Secret Mission';
            final String? description = t['description'];
            final double reward = (t['reward_amount'] ?? 0.0).toDouble();
            final String status = t['status'] ?? 'assigned';
            final String? proofUrl = t['proof_url'];
            final String recurringInterval = t['recurring_interval'] ?? 'none';

            final bool isPending = status == 'pending';
            final bool isCompleted = status == 'completed';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPending ? const Color(0xFFFFF7ED) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isPending ? const Color(0xFFFFEDD5) : Colors.transparent, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title row bundled alongside dynamic interval visual layout tags
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (recurringInterval != 'none') ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.cached_rounded, size: 10, color: Color(0xFF0369A1)),
                                        const SizedBox(width: 2),
                                        Text(
                                          recurringInterval.toUpperCase(),
                                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Injected text layout descriptor block
                            if (description != null && description.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text('Reward: RM ${reward.toStringAsFixed(2)} 🟡', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (!isCompleted)
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400]),
                          onPressed: () async {
                            final bool? confirm = await _showDeleteConfirmationDialog(title);
                            if (confirm == true) {
                              await supabaseService.client.from('tasks').delete().eq('id', taskId);
                              setState(() {});
                            }
                          },
                        )
                      else
                        Icon(Icons.lock_outline_rounded, color: Colors.grey[400]),
                    ],
                  ),
                  if (proofUrl != null && proofUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Task Completion Proof:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () => _showFullImagePreview(proofUrl),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Image.network(
                              proofUrl,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(height: 60, color: const Color(0xFFF3F4F6), child: const Center(child: Text('⚠️ Image display failure'))),
                            ),
                            Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fullscreen_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 2),
                                  Text('Zoom', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            await supabaseService.client.from('tasks').update({'status': 'assigned', 'proof_url': null}).eq('id', taskId);
                            setState(() {});
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                          label: const Text('Approve & Pay', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            // Passing down interval argument logic payload string references directly
                            await _approveTaskTransaction(taskId, reward, title, recurringInterval);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGoalsTabFeed() {
    return FutureBuilder<List<dynamic>>(
      // 🎯 FIX: Changed from a static string to a dynamic childId key to flush the cache
      key: ValueKey('goals_tab_stream_${widget.childId}'),
      future: supabaseService.client
          .from('savings_goals')
          .select('id, goal_name, target_amount, status')
          .eq('profile_id', widget.childId)
          .order('id', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
        }
        final allGoals = snapshot.data ?? [];
        if (allGoals.isEmpty) {
          return const Center(child: Text('No saving goals set up yet.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)));
        }

        final activeGoals = allGoals.where((g) => g['status'] == 'active' || g['status'] == 'pending_approval').toList();
        final historicGoals = allGoals.where((g) => g['status'] == 'achieved' || g['status'] == 'completed').toList();

        return ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            if (activeGoals.isNotEmpty) ...[
              const Text('Current Active Target 🎯', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
              const SizedBox(height: 8),
              ...activeGoals.map((g) {
                final String goalId = g['id'].toString();
                final String goalName = g['goal_name'] ?? 'Savings Goal';
                final double targetPrice = (g['target_amount'] ?? 0.0).toDouble();
                final bool isPending = g['status'] == 'pending_approval';

                return FutureBuilder<Map<String, dynamic>?>(
                  future: supabaseService.client.from('wallets').select('save_balance').eq('profile_id', widget.childId).maybeSingle(),
                  builder: (context, walletSnapshot) {
                    final walletData = walletSnapshot.data;
                    final double currentSaved = walletData != null ? (walletData['save_balance'] ?? 0.00).toDouble() : 0.00;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isPending ? const Color(0xFFFFF7ED) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isPending ? const Color(0xFFFFEDD5) : const Color(0xFFE5E7EB), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  isPending ? '✨ Proposed: $goalName' : goalName,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPending ? const Color(0xFFC2410C) : const Color(0xFF1F2937)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('RM ${targetPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Progress: RM ${currentSaved.toStringAsFixed(2)} saved', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 6),
                              Text('•', style: TextStyle(color: Colors.grey[400])),
                              const SizedBox(width: 6),
                              Text('${targetPrice > 0 ? ((currentSaved / targetPrice) * 100).toStringAsFixed(0) : 0}% Completed', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (!isPending) ...[
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: g['status'] == 'achieved' ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              icon: Icon(g['status'] == 'achieved' ? Icons.check_circle_outline_rounded : Icons.stars_rounded, size: 16),
                              label: Text(g['status'] == 'achieved' ? 'Achieved' : 'Mark as Achieved! 🏆', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              onPressed: g['status'] == 'achieved'
                                  ? null
                                  : () async {
                                      await supabaseService.client.from('savings_goals').update({'status': 'achieved'}).eq('id', goalId);
                                      setState(() {});
                                    },
                            ),
                          ],
                          if (isPending) ...[
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                                    foregroundColor: const Color(0xFFEF4444),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.close_rounded, size: 14),
                                  label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    await supabaseService.client.from('savings_goals').delete().eq('id', goalId);
                                    setState(() {});
                                  },
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.check_rounded, size: 14),
                                  label: const Text('Approve New Goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    await supabaseService.client.from('savings_goals').update({'status': 'active'}).eq('id', goalId);
                                    await supabaseService.client.from('wallets').update({'save_balance': 0.00}).eq('profile_id', widget.childId);
                                    setState(() {});
                                  },
                                ),
                              ],
                            )
                          ]
                        ],
                      )
                    );
                  },
                );
              }).toList(),
            ] else ...[
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No active target right now.', style: TextStyle(color: Colors.grey, fontSize: 13)))),
            ],
            if (historicGoals.isNotEmpty) ...[
              const Divider(height: 32, color: Color(0xFFE5E7EB)),
              const Text('Achieved Dreams Vault 🏆', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              const SizedBox(height: 8),
              ...historicGoals.map((g) {
                final String goalName = g['goal_name'] ?? 'Past Goal';
                final double targetPrice = (g['target_amount'] ?? 0.0).toDouble();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xD1A7F3D0), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('👑', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(goalName, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF065F46), fontSize: 14)),
                        ],
                      ),
                      Text('RM ${targetPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857), fontSize: 14)),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBottomActionRow() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_task_rounded, color: Colors.white, size: 18),
            label: const Text('Assign Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(context, 'assign'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 18),
            label: const Text('Remove Child', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(context, 'remove'),
          ),
        ),
      ],
    );
  }

  // --- CORE ENGINE BALANCING SETTLER TRANSACTION LOGIC ---

  Future<void> _approveTaskTransaction(String taskId, double amount, String taskTitle, String recurringInterval) async {
    try {
      final taskQuery = await supabaseService.client
                .from('tasks')
                .select('due_date')
                .eq('id', taskId)
                .maybeSingle();

            final String? dueDateStr = taskQuery?['due_date'];
            final DateTime? dueDate = dueDateStr != null ? DateTime.parse(dueDateStr) : null;
            final bool isPastDueDate = dueDate != null && DateTime.now().isAfter(dueDate);

            // 👈 ADD THIS: If it's a one-time task OR the lifespan has expired, mark as completed permanently
            if (recurringInterval == 'none' || isPastDueDate) {
              await supabaseService.client.from('tasks').update({'status': 'completed'}).eq('id', taskId);
            } else {
              // Reset dynamic payload parameters for the next period run instead of completing entirely
              await supabaseService.client.from('tasks').update({
                'status': 'assigned',
                'proof_url': null,
              }).eq('id', taskId);
            }
      await supabaseService.client.rpc('increment_completed_tasks', params: {'user_id': widget.childId});

      final List<dynamic> walletRecords = await supabaseService.client
          .from('wallets')
          .select('total_balance, save_balance, spend_balance, share_balance')
          .eq('profile_id', widget.childId);

      final double saveIncrement = amount * 0.70;
      final double spendIncrement = amount * 0.20;
      final double shareIncrement = amount * 0.10;

      if (walletRecords.isNotEmpty) {
        final currentWallet = walletRecords.first;
        final double currentTotal = currentWallet['total_balance'] != null ? double.parse(currentWallet['total_balance'].toString()) : 0.0;
        final double currentSave = currentWallet['save_balance'] != null ? double.parse(currentWallet['save_balance'].toString()) : 0.0;
        final double currentSpend = currentWallet['spend_balance'] != null ? double.parse(currentWallet['spend_balance'].toString()) : 0.0;
        final double currentShare = currentWallet['share_balance'] != null ? double.parse(currentWallet['share_balance'].toString()) : 0.0;

        await supabaseService.client.from('wallets').update({
          'total_balance': currentTotal + amount,
          'save_balance': currentSave + saveIncrement,
          'spend_balance': currentSpend + spendIncrement,
          'share_balance': currentShare + shareIncrement,
        }).eq('profile_id', widget.childId);
      } else {
        await supabaseService.client.from('wallets').insert({
          'profile_id': widget.childId,
          'total_balance': amount,
          'save_balance': saveIncrement,
          'spend_balance': spendIncrement,
          'share_balance': shareIncrement,
        });
      }

      await supabaseService.client.from('transactions').insert({
        'profile_id': widget.childId,
        'title': taskTitle,
        'amount': amount,
        'category': 'Task',
      });
    } catch (e) {
      debugPrint('Database Transaction Fault: $e');
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(String taskTitle) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Mission? 🗑️', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to completely delete "$taskTitle"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFullImagePreview(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(url, fit: BoxFit.contain))),
            IconButton(icon: const CircleAvatar(backgroundColor: Colors.black45, child: Icon(Icons.close, color: Colors.white)), onPressed: () => Navigator.pop(context))
          ],
        ),
      ),
    );
  }
}