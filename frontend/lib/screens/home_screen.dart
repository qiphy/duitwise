import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart'; 
import '../supabase_service.dart';
import '../models.dart';
import '../widgets/balance_card.dart';
import 'quest_screen.dart';
import 'goals_screen.dart';
import 'auth_screen.dart'; 
import 'package:image_picker/image_picker.dart';
import 'onboarding_screen.dart'; 
import '../services/notification_service.dart';
import 'transaction_history_screen.dart';
import 'money_report_screen.dart';
import 'package:video_player/video_player.dart';
import '../services/summary_service.dart';

// --- Local Dashboard Data Composition Wrapper ---
class DashboardData {
  final UserModel profile;
  final WalletModel wallet;

  DashboardData({required this.profile, required this.wallet});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<DashboardData> _dashboardDataFuture;
  int _currentIndex = 0;

  // --- FPX Linkage Configuration Parameters ---
  bool _isBankLinked = false;
  String _selectedBank = 'Bank Islam';
  final TextEditingController _accountNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshData();

      WidgetsBinding.instance.addPostFrameCallback((_) async {
            await NotificationService().initializeNotificationPipeline(
              context, 
              globalNavigatorKey
            );
          });
      }

  @override
  void dispose() {
    _accountNumberController.dispose();
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _dashboardDataFuture = _fetchDashboardTelemetry();
    });
  }

Future<DashboardData> _fetchDashboardTelemetry() async {
    final String? loggedInUserId = supabaseService.currentUserId;

    if (loggedInUserId == null) {
      throw Exception('No active authenticated user session detected.');
    }

    try {
      // 1. Fetch the logged-in user's profile metadata row from Postgres
      final profileDbResponse = await supabaseService.client
          .from('profiles')
          .select()
          .eq('id', loggedInUserId)
          .maybeSingle();

      if (profileDbResponse == null) {
        throw Exception('User profile metadata row not found.');
      }

      final profileMetrics = UserModel.fromJson(profileDbResponse as Map<String, dynamic>);
      String targetWalletUserId = loggedInUserId;

      // 🦉 ROLE CHECK: If a Parent is viewing the dashboard, check for their linked child
      if (profileMetrics.role == 'parent') {
        final List<dynamic> linkedKids = await supabaseService.client
            .from('profiles')
            .select('id')
            .eq('parent_id', loggedInUserId)
            .eq('role', 'child')
            .limit(1);

        if (linkedKids.isNotEmpty) {
          // Point the target pointer context to pull the child's wallet row instead!
          targetWalletUserId = linkedKids.first['id'];
        }
      }

      // 2. FETCH the wallet data row DIRECTLY from your 'wallets' database table
      final List<dynamic> walletRecords = await supabaseService.client
          .from('wallets')
          .select('save_balance, spend_balance, share_balance')
          .eq('profile_id', targetWalletUserId);

      // Map backend values seamlessly into your frontend WalletModel structure
      WalletModel walletMetrics;
      if (walletRecords.isNotEmpty) {
        final currentWalletData = walletRecords.first;
        walletMetrics = WalletModel(
          profileId: targetWalletUserId,
          saveBalance: (currentWalletData['save_balance'] ?? 0.0).toDouble(),
          spendBalance: (currentWalletData['spend_balance'] ?? 0.0).toDouble(),
          shareBalance: (currentWalletData['share_balance'] ?? 0.0).toDouble(),
        );
      } else {
        // Fallback default if a wallet record row doesn't exist yet in PostgreSQL
        walletMetrics = WalletModel(
          profileId: targetWalletUserId,
          saveBalance: 0.00,
          spendBalance: 0.00,
          shareBalance: 0.00,
        );
      }

      // 💡 AUTOMATION LINK: Parse bank metadata attributes straight into active state fields for parents
      final String? dbBank = profileDbResponse['linked_bank_name'];
      final String? dbAccount = profileDbResponse['bank_account_number'];
      
      if (dbBank != null && dbAccount != null) {
        _isBankLinked = true;
        _selectedBank = dbBank;
        _accountNumberController.text = dbAccount;
      } else {
        _isBankLinked = false;
      }

      return DashboardData(profile: profileMetrics, wallet: walletMetrics);
    } catch (e) {
      throw Exception('Failed to synchronize dashboard telemetry: $e');
    }
  }

  void _showAddTaskBottomSheet(String childName, String childId) {
    final TextEditingController taskTitleController = TextEditingController();
    final TextEditingController taskRewardController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign Task to $childName 📋', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: taskTitleController,
                decoration: InputDecoration(
                  labelText: 'Task Title (e.g., Clean Bedroom)',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a task title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: taskRewardController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Chore Reward (RM)',
                  prefixText: 'RM ',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || double.tryParse(val) == null ? 'Please enter a valid reward amount' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    
                    try {
                      await supabaseService.client.from('tasks').insert({
                        'profile_id': childId,
                        'title': taskTitleController.text.trim(),
                        'reward_amount': double.parse(taskRewardController.text.trim()),
                        'status': 'assigned',
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        _refreshData(); // Triggers a reload if parents want dynamic feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Chore assigned to $childName successfully!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to assign task: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Send Mission to Child', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- Enhanced Parent Control Sheet: Task Validation & Household Disconnection ---
  Future<void> _showParentTaskManagerBottomSheet(String childName, String childId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder( 
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- UPDATED HEADER BLOCK: Live Balance Tracker, Rectangle Download Button, & Inline Transfer Action ---
                  FutureBuilder<List<dynamic>>(
                    future: supabaseService.client
                        .from('wallets')
                        .select('total_balance, save_balance, spend_balance, share_balance')
                        .eq('profile_id', childId), // Uses the specific childId of the tapped card
                    builder: (context, walletSnapshot) {
                      final walletData = walletSnapshot.data ?? [];
                      
                      double currentTotal = 0.00;
                      if (walletData.isNotEmpty) {
                        if (walletData.first['total_balance'] != null) {
                          currentTotal = double.parse(walletData.first['total_balance'].toString());
                        } else {
                          // Structural fallback calculation if total_balance field is null
                          final double s = double.parse((walletData.first['save_balance'] ?? 0.0).toString());
                          final double sp = double.parse((walletData.first['spend_balance'] ?? 0.0).toString());
                          final double sh = double.parse((walletData.first['share_balance'] ?? 0.0).toString());
                          currentTotal = s + sp + sh;
                        }
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$childName\'s Missions 🎯', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  'Balance: RM ${currentTotal.toStringAsFixed(2)} 🟡',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 📥 INJECTED ACTION: Rectangle Monthly Financial Statement Downloader Button
ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6), // Purple color accent for structural separation
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                                label: const Text('Download Monthly Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () async {
                                  Navigator.pop(context); // Dismiss current sheet framework layer
                                  
                                  // 1. Trigger the processing feedback snackbar immediately
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const SizedBox(
                                            width: 16, height: 16,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          ),
                                          const SizedBox(width: 16),
                                          Text('Generating monthly report statement for $childName...'),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );

                                  // 2. Package current metrics into the required WalletModel structure 
                                  final WalletModel childWalletContext = WalletModel(
                                    profileId: childId,
                                    saveBalance: currentTotal * 0.70,
                                    spendBalance: currentTotal * 0.20,
                                    shareBalance: currentTotal * 0.10,
                                  );

                                  // 3. Fire the SummaryService pipeline passing the childName string vector context
                                  try {
                                    await SummaryService().generateAndDownloadReport(
                                      context, 
                                      childWalletContext,
                                      childName, // ✅ FIXED: Passed childName parameter safely
                                    );
                                    
                                    // Clear generation status loader once printing system takes over
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).clearSnackBars();
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).clearSnackBars();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Colors.redAccent,
                                          content: Text('Failed to compile document: $e'),
                                        ),
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
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showTransferMoneyBottomSheet(childName, childId);
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Active Task Tracker Stream
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: supabaseService.client
                          .from('tasks')
                          .select('id, title, reward_amount, status, proof_url, assigned_at')
                          .eq('profile_id', childId) 
                          .order('id', ascending: false),
                      builder: (context, taskSnapshot) {
                        if (taskSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                        }
                        
                        final tasks = taskSnapshot.data ?? [];
                        if (tasks.isEmpty) {
                          return const Center(
                            child: Text(
                              'No missions assigned yet.\nTap "Add Task" below to start!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, height: 1.4, fontWeight: FontWeight.w500),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: tasks.length,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, idx) {
                            final t = tasks[idx];
                            final String taskId = t['id'].toString();
                            final String title = t['title'] ?? 'Secret Mission';
                            final double reward = (t['reward_amount'] ?? 0.0).toDouble();
                            final String status = t['status'] ?? 'assigned';
                            final String? proofUrl = t['proof_url'];
                            final String rawDate = t['assigned_at'] ?? '';
                            final String assignedDate = rawDate.isNotEmpty 
                                ? DateTime.parse(rawDate).toLocal().toString().split(' ')[0] 
                                : 'Recent';

                            final bool isPending = status == 'pending';

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
                                  // Top Row: Title, Reward Info, and the Delete Trash Icon
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title, 
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  'Reward: RM ${reward.toStringAsFixed(2)} 🟡', 
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 13)
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey[400]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  assignedDate,
                                                  style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400], size: 22),
                                        tooltip: 'Delete this task entirely',
                                        onPressed: () async {
                                          await _handleDeleteTask(taskId, title);
                                          setModalState(() {}); 
                                          _refreshData();       
                                        },
                                      ),
                                    ],
                                  ),
                                  
                                  // 📷 PHOTO PROOF ELEMENT: Injected directly for validation visibility
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
                                              errorBuilder: (c, e, s) => Container(
                                                height: 60,
                                                color: const Color(0xFFF3F4F6),
                                                child: const Center(child: Text('⚠️ Image display failure')),
                                              ),
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

                                  const SizedBox(height: 12),

                                  // Bottom Action Row: Status Chip and Dynamic Parent Decision Buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Chip(
                                        label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                        backgroundColor: isPending ? Colors.orange[100] : (status == 'completed' ? Colors.green[100] : Colors.blue[100]),
                                        side: BorderSide.none,
                                      ),
                                      if (isPending)
                                        Row(
                                          children: [
                                            // ❌ REJECT TEXT ACTUATOR ACTION BUTTON
                                            TextButton.icon(
                                              style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
                                              icon: const Icon(Icons.cancel_outlined, size: 16),
                                              label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              onPressed: () async {
                                                await _rejectTaskProof(taskId, title);
                                                setModalState(() {});
                                                _refreshData();
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            // ✅ APPROVE & DISBURSE DISPATCH BUTTON
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF16A34A),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                elevation: 0,
                                              ),
                                              icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                                              label: const Text('Approve & Pay', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                              onPressed: () async {
                                                await _approveTaskAndDisburseFunds(taskId, childId, reward, title);
                                                setModalState(() {}); 
                                                _refreshData();       
                                              },
                                            ),
                                          ],
                                        ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // BOTTOM ACTION ROW: Household controllers
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 18),
                          label: const Text('Remove Child', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final bool removed = await _handleRemoveChildFromHousehold(childId, childName);
                            if (removed && context.mounted) {
                              Navigator.pop(context); 
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          label: const Text('Add Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(context); 
                            _showAddTaskBottomSheet(childName, childId); 
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTransferMoneyBottomSheet(String childName, String childId) {
  final TextEditingController amountController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transfer to $childName 💸', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Funds will be instantly split using the Smart Money Rule (70% Save, 20% Spend, 10% Share).',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount (RM)',
                prefixText: 'RM ',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (val) {
                if (val == null || double.tryParse(val) == null) return 'Enter a valid amount';
                if (double.parse(val) <= 0) return 'Amount must be greater than zero';
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // Green accents for instant transfers
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final double transferAmount = double.parse(amountController.text.trim());
                  
                  try {
                    // Fetch current wallet structural profile matrices
                    final List<dynamic> walletRecords = await supabaseService.client
                        .from('wallets')
                        .select('total_balance, save_balance, spend_balance, share_balance')
                        .eq('profile_id', childId);

                    final double saveIncrement = transferAmount * 0.70;
                    final double spendIncrement = transferAmount * 0.20;
                    final double shareIncrement = transferAmount * 0.10;

                    if (walletRecords.isNotEmpty) {
                      final currentWallet = walletRecords.first;
                      final double currentTotal = (currentWallet['total_balance'] ?? 0.0).toDouble();
                      final double currentSave = (currentWallet['save_balance'] ?? 0.0).toDouble();
                      final double currentSpend = (currentWallet['spend_balance'] ?? 0.0).toDouble();
                      final double currentShare = (currentWallet['share_balance'] ?? 0.0).toDouble();

                      await supabaseService.client.from('wallets').update({
                        'total_balance': currentTotal + transferAmount,
                        'save_balance': currentSave + saveIncrement,
                        'spend_balance': currentSpend + spendIncrement,
                        'share_balance': currentShare + shareIncrement,
                      }).eq('profile_id', childId);
                    } else {
                      await supabaseService.client.from('wallets').insert({
                        'profile_id': childId,
                        'total_balance': transferAmount,
                        'save_balance': saveIncrement,
                        'spend_balance': spendIncrement,
                        'share_balance': shareIncrement,
                      });
                    }

                    // Create transaction audit log item row entry
                    await supabaseService.client.from('transactions').insert({
                      'profile_id': childId,
                      'title': 'Direct Parent Transfer',
                      'amount': transferAmount,
                      'category': 'Transfer',
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      _refreshData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Successfully transferred RM ${transferAmount.toStringAsFixed(2)} to $childName!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Transfer failed: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
                child: const Text('Confirm Instant Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

  // --- Image Lightbox Overlay Modal Dialogue ---
  void _showFullImagePreview(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer( // Enables native scale-to-zoom pinch gestures natively
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(backgroundColor: Colors.black45, child: Icon(Icons.close, color: Colors.white)),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      ),
    );
  }

  // ❌ Reverts a pending task back to uncompleted assigned state, clearing out the bad file reference URL
  Future<void> _rejectTaskProof(String taskId, String taskTitle) async {
    try {
      await supabaseService.client
          .from('tasks')
          .update({
            'status': 'assigned',
            'proof_url': null, // Completely flushes out the file URL path
          })
          .eq('id', taskId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proof rejected for "$taskTitle". Reset to assigned.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejection failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- Core Wallet Balance Settler Transaction Logic ---
Future<void> _approveTaskAndDisburseFunds(String taskId, String childId, double amount, String taskTitle) async {
    try {
      // 1. Mark task as completed in Postgres
      await supabaseService.client
          .from('tasks')
          .update({'status': 'completed'})
          .eq('id', taskId);

      // 2. Increment the completed task metrics counter row 
      await supabaseService.client.rpc(
        'increment_completed_tasks', 
        params: {'user_id': childId}
      );

      // 3. FETCH current wallet values directly from your table
      final List<dynamic> walletRecords = await supabaseService.client
          .from('wallets')
          .select('total_balance, save_balance, spend_balance, share_balance')
          .eq('profile_id', childId);

      // 🧮 FORMULAIC SPLIT ENGINE (70 / 20 / 10)
      final double saveIncrement = amount * 0.70;
      final double spendIncrement = amount * 0.20;
      final double shareIncrement = amount * 0.10;

      if (walletRecords.isNotEmpty) {
        // --- CASE A: WALLET EXISTS -> UPDATE BALANCES ---
        final currentWallet = walletRecords.first;
        
        final double currentTotal = currentWallet['total_balance'] != null 
            ? double.parse(currentWallet['total_balance'].toString()) 
            : 0.0;
        final double currentSave = currentWallet['save_balance'] != null 
            ? double.parse(currentWallet['save_balance'].toString()) 
            : 0.0;
        final double currentSpend = currentWallet['spend_balance'] != null 
            ? double.parse(currentWallet['spend_balance'].toString()) 
            : 0.0;
        final double currentShare = currentWallet['share_balance'] != null 
            ? double.parse(currentWallet['share_balance'].toString()) 
            : 0.0;

        await supabaseService.client
            .from('wallets')
            .update({
              'total_balance': currentTotal + amount,
              'save_balance': currentSave + saveIncrement,
              'spend_balance': currentSpend + spendIncrement,
              'share_balance': currentShare + shareIncrement,
            })
            .eq('profile_id', childId);
      } else {
        // --- CASE B: FIRST TIME WALLET USER -> INSERT FRESH RECORD ---
        await supabaseService.client
            .from('wallets')
            .insert({
              'profile_id': childId,
              'total_balance': amount,
              'save_balance': saveIncrement,
              'spend_balance': spendIncrement,
              'share_balance': shareIncrement,
            });
      }

      // 4. Log transaction audit trail history
      await supabaseService.client.from('transactions').insert({
        'profile_id': childId,
        'title': taskTitle,
        'amount': amount, 
        'category': 'Task',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payout disbursed! RM ${amount.toStringAsFixed(2)} split across child buckets.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Transaction Fault: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleDeleteTask(String taskId, String taskTitle) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Mission? 🗑️', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to completely delete "$taskTitle"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabaseService.client
          .from('tasks')
          .delete()
          .eq('id', taskId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$taskTitle" has been deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showChangeUsernameDialog(String currentUsername) {
    final TextEditingController usernameController = TextEditingController(text: currentUsername);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Username 🐯', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: usernameController,
            autofocus: true,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Enter fresh username...',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.face_rounded, color: Color(0xFF8B5CF6)),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Name cannot be blank!' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final newName = usernameController.text.trim();
              final String? profileId = supabaseService.currentUserId;

              if (profileId != null) {
                try {
                  await supabaseService.client
                      .from('profiles')
                      .update({'username': newName})
                      .eq('id', profileId);

                  if (context.mounted) {
                    Navigator.pop(context);
                    _refreshData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save configuration: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleProfileMenuAction(String value, String currentUsername) {
      switch (value) {
        case 'settings':
          // 🛠️ FIX: Call your existing username dialog directly here
          _showChangeUsernameDialog(currentUsername);
          break;
          
        case 'logout':
          supabaseService.client.auth.signOut();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logged out successfully!')),
          );
          break;
      }
    }

@override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F6FA),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
          );
        }

        final bool isParent = snapshot.hasData && snapshot.data!.profile.role == 'parent';

        if (snapshot.hasData) {
          final profile = snapshot.data!.profile;
          final wallet = snapshot.data!.wallet;

          if (!profile.hasCompletedOnboarding && profile.role == 'child') {
            return OnboardingWelcomeScreen(
              wallet: wallet,
              onFinish: () => _refreshData(),
              onShowSmartPlanSheet: (ctx, wal, finish) => showSmartMoneyPlanBottomSheet(ctx, wal, finish),
            );
          }

          // 🗂️ TAB CONFIGURATION: Content screens only (Headers have been cleanly abstracted out)
          final List<Widget> screens = [
            _buildHomeDashboard(snapshot),          // Screen 1: Home Dashboard Panel
            const GoalsScreen(),          
            const MoneyReportScreen(),             // Screen 2: Missions
            const TransactionHistoryScreen(),  
           // Screen 3: History Reports
          ];

          return Scaffold(
            backgroundColor: const Color(0xFFF5F6FA),
            appBar: null, // Left explicitly null to prevent double-header glitches
            body: SafeArea(
              child: RefreshIndicator(
                color: const Color(0xFF8B5CF6),
                onRefresh: () async => _refreshData(),
                child: isParent 
                    ? screens[0] // Parent view retains custom internal single-scroll view rules
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 🌟 STICKY GLOBAL HEADER CARD: Persists across ALL page tracking routes
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                bool isNarrow = constraints.maxWidth < 700;

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Hi, ${profile.username}! 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                                const SizedBox(height: 4),
                                                const Text('Ready to master your financial goals today?', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                                              ],
                                            ),
                                          ),
                                          _buildActionButtons(isParent, profile),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _buildResponsiveCoinPlan(isNarrowScreen: true, wallet: wallet),
                                    ],
                                  );
                                } else {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Hi, ${profile.username}! 👋', 
                                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text('Ready to master your financial goals today?', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          _buildResponsiveCoinPlan(isNarrowScreen: false, wallet: wallet),
                                          const SizedBox(width: 24),
                                          _buildActionButtons(isParent, profile),
                                        ],
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ),
                          
                          // Divider line separating the permanent header row from the sub-pages
                          const SizedBox(height: 16),
                          
                          // 📑 SUB-PAGE VIEWPORT HOUSING
                          Expanded(
                            child: IndexedStack(
                              index: _currentIndex, 
                              children: screens,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            bottomNavigationBar: isParent
                ? null 
                : BottomNavigationBar(
                    currentIndex: _currentIndex,
                    selectedItemColor: const Color(0xFF8B5CF6),
                    unselectedItemColor: Colors.grey,
                    type: BottomNavigationBarType.fixed,
                    onTap: (index) => setState(() => _currentIndex = index),
                    items: const [
                      BottomNavigationBarItem(icon: Icon(Icons.home_max_rounded), label: 'Dashboard'),
                      BottomNavigationBarItem(icon: Icon(Icons.star_border_rounded), label: 'Missions'),
                      BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Report'), 
                      BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'History'),
                    ],
                  ),
          );
        }

        return const Scaffold(body: Center(child: Text('Ecosystem disrupted.')));
      },
    );
  }

// 🛠️ RETAINED: Restored the signature parameter to accept your original AsyncSnapshot layout
Widget _buildHomeDashboard(AsyncSnapshot<DashboardData> snapshot) {
    final profile = snapshot.data!.profile;
    final bool isParent = profile.role == 'parent';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- PARENT SPECIFIC ROOT HEADER VIEWS ---
          if (isParent) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hi, ${profile.username}! 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    const SizedBox(height: 4),
                    const Text('Parent Control Terminal Dashboard', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                _buildActionButtons(isParent, profile),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Linked Funding Accounts (FPX System Platform)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            _buildMockBankLinkCard(),
            const SizedBox(height: 24),
            _buildLinkedChildrenSection(),
          ],

          // --- CHILD SPECIFIC CONTENT PANEL CONTENT ONLY ---
          if (!isParent) ...[
            const SizedBox(height: 24),
            // ✅ REDUNDANCIES WIPED: Header components stripped out cleanly 
            // since they now sit inside the persistent parent column layer!
            const SizedBox(height: 12),
            _buildLevelProgressCard(profile),
            const SizedBox(height: 24),
            _buildChildTasksSection(profile.id),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
}

// 🛡️ HELPER STRUCTURAL WRAPPER METHOD
Widget _buildConditionalWrapper({required bool isFlexed, required Widget child}) {
  // If in Row view, wrap components with Expanded to force them to consume exactly 50% width dimensions
  return isFlexed ? Expanded(child: child) : child;
}


  // 👤 Sub-component: Username Greeting Text
  Widget _buildUserGreeting(dynamic profile, bool isParent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hey ${profile.username}! 👋',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isParent ? 'Family Controller Panel' : 'Ready to be money smart today?',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // 📊 Sub-component: Responsive Money Plan Layout (With Legend Below Title) 
Widget _buildResponsiveCoinPlan({required bool isNarrowScreen, required dynamic wallet}) {
    // 1. Get the raw unallocated balance (or combined total)
    final double totalBalance = (wallet.spendBalance ?? 0.0) + 
                                (wallet.saveBalance ?? 0.0) + 
                                (wallet.shareBalance ?? 0.0);

    // 2. Calculate the 70/20/10 split dynamically so it matches the bottom sheet
    final double saveAllocated = totalBalance * 0.70;
    final double spendAllocated = totalBalance * 0.20;
    final double shareAllocated = totalBalance * 0.10;

    // 🏷️ Combined Header: Places Total Balance and legends cleanly below the main title
    final Widget planHeader = Column(
      mainAxisSize: MainAxisSize.min, // ✅ CRITICAL: Constrains vertical expansion rules
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Money Plan 🎯',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          'RM ${totalBalance.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min, // ✅ Constrains horizontal row expansion bounds
          children: [
            _buildTinyLegendDot(const Color(0xFF4ADE80), 'Save'),
            const SizedBox(width: 6),
            _buildTinyLegendDot(const Color(0xFF60A5FA), 'Spend'),
            const SizedBox(width: 6),
            _buildTinyLegendDot(const Color(0xFFF472B6), 'Share'),
          ],
        ),
      ],
    );

    // 🪙 The Clickable Coin Segment Capsules Row
    final Widget coinBar = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showSmartMoneyPlanBottomSheet(context, wallet, () {
        _refreshData(); 
      }),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, 
          children: [
            // 3. Pass the freshly calculated splits instead of raw model properties
            _buildCapsuleSegment('${saveAllocated.toStringAsFixed(2)} 🟡', const Color(0xFF4ADE80), isLeft: true),
            _buildCapsuleSegment('${spendAllocated.toStringAsFixed(2)} 🟡', const Color(0xFF60A5FA)),
            _buildCapsuleSegment('${shareAllocated.toStringAsFixed(2)} 🟡', const Color(0xFFF472B6), isRight: true),
          ],
        ),
      ),
    );

    // ➕ New Transaction Action Button for the Child
final Widget addTransactionButton = ElevatedButton.icon(
      onPressed: () {
        // ✅ Replaced with a concrete, inline native stub until you build your custom layout sheet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Center(child: Text("Coming Soon! 🇲🇾")),
          ),
        ).then((_) => _refreshData()); // Triggers your state lifecycle sync upon close
      },
      icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
      label: const Text(
        'Pay Using QR',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    // 📱 DYNAMIC LAYOUT ENGINE RETURN CHANNELS
    if (isNarrowScreen) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ Fixed enum property from 'between' to 'spaceBetween'
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              planHeader,
              addTransactionButton,
            ],
          ),
          const SizedBox(height: 12),
          coinBar,
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min, // ✅ Enforces strict layout width boundaries on desktop web viewports
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          planHeader,
          const SizedBox(width: 24), 
          coinBar,
          const SizedBox(width: 16),
          addTransactionButton, // appends cleanly to the end of the alignment layout line on desktop displays
        ],
      );
    }
  }

// 🛠️ FIX: Added 'VoidCallback onFinish' signature to match the dashboard call route parameters
void showSmartMoneyPlanBottomSheet(BuildContext context, WalletModel wallet, VoidCallback onFinish) {
  // 🧮 Calculate portions dynamically from total_balance metric
  final double totalCoins = wallet.totalBalance ?? 
      ((wallet.saveBalance ?? 0.0) + (wallet.spendBalance ?? 0.0) + (wallet.shareBalance ?? 0.0));

  VideoPlayerController? modalVideoController;
  bool isModalVideoInitialized = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false, // Prevents them closing it early by tapping outside
    enableDrag: false,
    backgroundColor: Colors.transparent, 
    builder: (context) {
      // 🛠️ WRAPPER: Wrapped the core container inside a StatefulBuilder to refresh the video viewport natively
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          // Lazy-init the video controller instance on first build pipeline
          if (modalVideoController == null) {
            modalVideoController = VideoPlayerController.networkUrl(
                Uri.parse('https://tbrefzeytkflqyadayvs.supabase.co/storage/v1/object/public/quest-videos/finance_video.mp4'),
            )
              ..setVolume(0.0)
              ..initialize().then((_) {
                setModalState(() => isModalVideoInitialized = true);
              });

            modalVideoController!.addListener(() {
              setModalState(() {});
            });
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header Drag Notch
                  Center(
                    child: Container(
                      width: 40, height: 5,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sticky Non-Scrolling Header Block Component
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Text('✨', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 8),
                            Text(
                              'Learn the Smart Money Plan! 🎯',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                        onPressed: () {
                          modalVideoController?.dispose();
                          Navigator.pop(context);
                        },
                      )
                    ],
                  ),
                  const Text(
                    'Watch this quick video to become a money master! 🚀',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),

                  // 📜 SCROLLABLE BODY VIEWPORT
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(), 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 🎞️ LIVE VIDEO PLAYER CONTAINER (Replaced static gradient placeholder)
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFF312E81),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: isModalVideoInitialized
                                  ? AspectRatio(
                                      aspectRatio: modalVideoController!.value.aspectRatio,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          VideoPlayer(modalVideoController!),
                                          GestureDetector(
                                            onTap: () {
                                              setModalState(() {
                                                modalVideoController!.value.isPlaying 
                                                    ? modalVideoController!.pause() 
                                                    : modalVideoController!.play();
                                              });
                                            },
                                            child: CircleAvatar(
                                              radius: 28,
                                              backgroundColor: Colors.white.withValues(alpha: 0.9),
                                              child: Icon(
                                                modalVideoController!.value.isPlaying 
                                                    ? Icons.pause_rounded 
                                                    : Icons.play_arrow_rounded,
                                                color: const Color(0xFF6366F1), 
                                                size: 32,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🎓', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 6),
                              Text(
                                'The Smart Money Rule',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 🟢 SAVE TARGET SEGMENT ROW (Formulaic Split calculation)
                          _buildAllocationCard(
                            liveValue: (totalCoins * 0.70).toStringAsFixed(2),
                            title: '💚 Save 70% - Be Smart!',
                            subtitle: 'Put 70% of your money into savings for your big dreams like that gaming console or bicycle! This helps you reach your goals faster! 🎯',
                            icon: '🐷',
                            themeColor: const Color(0xFFDCFCE7),
                            textColor: const Color(0xFF15803D),
                            borderColor: const Color(0xFFBBF7D0),
                          ),
                          const SizedBox(height: 12),

                          // 🔵 SPEND TARGET SEGMENT ROW (Formulaic Split calculation)
                          _buildAllocationCard(
                            liveValue: (totalCoins * 0.20).toStringAsFixed(2),
                            title: '💙 Spend 20% - Have Fun!',
                            subtitle: 'Use 20% for fun stuff you want right now! Snacks, games, or treats - enjoy the rewards of your hard work! 🎉',
                            icon: '🛍️',
                            themeColor: const Color(0xFFDBEAFE),
                            textColor: const Color(0xFF1D4ED8),
                            borderColor: const Color(0xFFBFDBFE),
                          ),
                          const SizedBox(height: 12),

                          // 💗 SHARE TARGET SEGMENT ROW (Formulaic Split calculation)
                          _buildAllocationCard(
                            liveValue: (totalCoins * 0.10).toStringAsFixed(2),
                            title: '💖 Share 10% - Be Kind!',
                            subtitle: 'Give 10% to help others! Buy gifts for family, donate to charity, or help a friend. Sharing makes the world better! ✨',
                            icon: '💝',
                            themeColor: const Color(0xFFFCE7F3),
                            textColor: const Color(0xFFB70E5C),
                            borderColor: const Color(0xFFFBCFE8),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Sticky Bottom Confirmation CTA Execution Button Frame
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      modalVideoController?.pause();
                      modalVideoController?.dispose(); // Clean up memory threads

                      final String? profileId = supabaseService.currentUserId;
                      if (profileId != null) {
                        try {
                          // Save compliance metric permanently to Supabase
                          await supabaseService.client
                              .from('profiles')
                              .update({'has_completed_onboarding': true})
                              .eq('id', profileId);
                        } catch (e) {
                          debugPrint('Onboarding sync error: $e');
                        }
                      }

                      // Close bottom sheet and signal main view state profile reload refresh
                      if (context.mounted) {
                        Navigator.pop(context); 
                        onFinish();             
                      }
                    },
                    child: const Text(
                      "Got it! Let's Start! 🚀", 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// 📦 Reusable component helper function to keep build layout footprint clean
Widget _buildAllocationCard({
  required String liveValue,
  required String title,
  required String subtitle,
  required String icon,
  required Color themeColor,
  required Color textColor,
  required Color borderColor,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: themeColor.withOpacity(0.3),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor.withOpacity(0.7), width: 1.5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: themeColor,
          child: Text(icon, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$liveValue 🟡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor.withOpacity(0.8))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 45), // Prevents text colliding with percentage numbers
                child: Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // 💊 Sub-component: Segment Builder for the capsule bars
  Widget _buildCapsuleSegment(String text, Color color, {bool isLeft = false, bool isRight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: isLeft ? const Radius.circular(8) : Radius.zero,
          bottomLeft: isLeft ? const Radius.circular(8) : Radius.zero,
          topRight: isRight ? const Radius.circular(8) : Radius.zero,
          bottomRight: isRight ? const Radius.circular(8) : Radius.zero,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 🕹️ Sub-component: Right-aligned Interactive Action Buttons
// 🕹️ Sub-component: Interactive Action Buttons
  Widget _buildActionButtons(bool isParent, dynamic profile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Only children can launch video quest events
        if (!isParent) ...[
          IconButton(
            tooltip: 'Launch Demo Mission Event',
            icon: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), // Green matching target style profile
                    shape: BoxShape.circle,
                  ),
                ),
                const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 24),
              ],
            ),
            onPressed: () {
              showInteractiveQuestPopup(
                context,
                onQuestCompleted: () => _refreshData(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        
        // ✅ AVAILABLE TO BOTH: Universal Profile Menu Terminal Block
        PopupMenuButton<String>(
          onSelected: (value) => _handleProfileMenuAction(value, profile.username),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: isParent ? const Color(0xFFDBEAFE) : const Color(0xFFFEF3C7),
            child: Text(isParent ? '🦉' : '🐯', style: const TextStyle(fontSize: 18)),
          ),
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 12),
                  const Text('Change Username', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: const [
                  Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                  SizedBox(width: 12),
                  Text('Logout', style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

Widget _buildLevelProgressCard(dynamic profile) {
    // 1. Calculate leveling metrics from total accumulated XP
    final int totalXp = profile.xp ?? 0;
    final int streak = profile.streak ?? 1;
    
    // 📊 EXTRACTION: Pull real cumulative aggregates from your Supabase profile record
    final int tasksDone = profile.completedTasksCount ?? 0;
    final int badgesEarned = profile.earnedBadgesCount ?? 0;
    
    const int xpPerLevel = 500;
    final int currentLevel = (totalXp ~/ xpPerLevel) + 1;
    final int currentXpInLevel = totalXp % xpPerLevel;

    // 2. Determine dynamic titles based on current milestone brackets
    String levelTitle = 'Coin Collector';
    String nextLevelTitle = 'Savings Star 💎';
    
    if (currentLevel >= 3) {
      levelTitle = 'Goal Getter 🎯';
      nextLevelTitle = 'Savings Star 💎';
    } else if (currentLevel >= 5) {
      levelTitle = 'Savings Star 💎';
      nextLevelTitle = 'Wealth Wizard 👑';
    }

    final double progressPercent = (currentXpInLevel / xpPerLevel).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3E8FF), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row: Title and XP Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        levelTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Level $currentLevel',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$currentXpInLevel XP',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Gradient Progress Bar
          Stack(
            children: [
              Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    height: 14,
                    width: constraints.maxWidth * progressPercent,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA78BFA), Color(0xFFEC4899), Color(0xFF3B82F6)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Progress Metrics and Next Target indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$currentXpInLevel / $xpPerLevel XP',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                const Icon(Icons.star_border_rounded, size: 14, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 4),
                Text(
                  'Next: $nextLevelTitle',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 🛠️ FIX: Injected the live model counts down here
        Row(
          children: [
            _buildStatBox('$tasksDone', 'Tasks Done', const Color(0xFF2563EB)),
            const SizedBox(width: 12),
            _buildStatBox('$streak', 'Day Streak', const Color(0xFF16A34A)),
            const SizedBox(width: 12),
            _buildStatBox('$badgesEarned', 'Badges', const Color(0xFF7C3AED)),
          ],
        ),
      ],
    ),
  );
}

Widget _buildStatBox(String metric, String label, Color metricColor) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            metric,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: metricColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ),
  );
}

  // --- Child Component: Live Tasks Display Panel ---
// --- Enhanced Child Component: Live Tasks Display Panel with Photo Proof ---
// --- Child Component: Live Tasks Display Panel ---
  Widget _buildChildTasksSection(String childId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Current Tasks 🚀',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<dynamic>>(
          future: supabaseService.client
              .from('tasks')
              .select('id, title, reward_amount, status, proof_url, assigned_at')
              .eq('profile_id', childId)
              .order('id', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
            }

            final tasksList = snapshot.data ?? [];

            // 🛑 RETAINED FALLBACK: If there are no tasks, show the custom placeholder layout card cleanly
            if (tasksList.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: const [
                    Text('🎉', style: TextStyle(fontSize: 36)),
                    SizedBox(height: 8),
                    Text('All cleaned up!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                    SizedBox(height: 4),
                    Text('No tasks assigned right now. Go play outside!', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasksList.length,
              itemBuilder: (context, index) {
                final task = tasksList[index];
                
                // 🛠️ TYPE FIX: Safely parse id parameters regardless of whether your schema uses int or uuid types
                final String taskId = task['id'] is num 
                    ? (task['id'] as num).toString() 
                    : task['id'].toString();
                    
                final String title = task['title'] ?? 'Secret Mission';
                final double reward = (task['reward_amount'] ?? 0.0).toDouble();
                final String status = task['status'] ?? 'assigned';
                final String rawDate = task['assigned_at'] ?? '';
                final String assignedDate = rawDate.isNotEmpty 
                    ? DateTime.parse(rawDate).toLocal().toString().split(' ')[0] 
                    : 'Recent';

                bool isPendingOrDone = status == 'pending' || status == 'completed';

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF8B5CF6)),
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937))),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Reward: ${reward.toInt()} Coins 🟡',
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              'Assigned: $assignedDate',
                              style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: isPendingOrDone
                        ? Chip(
                            backgroundColor: status == 'pending' ? Colors.orange[50] : Colors.green[50],
                            label: Text(
                              status == 'pending' ? 'PENDING APPROVAL' : 'COMPLETED',
                              style: TextStyle(
                                fontSize: 11, 
                                fontWeight: FontWeight.bold, 
                                color: status == 'pending' ? Colors.orange[700] : Colors.green[700]
                              ),
                            ),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            label: const Text('Complete', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _submitTaskProof(taskId, title),
                          ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // --- Photo Proof Handler Execution Logic ---
  Future<void> _submitTaskProof(String taskId, String taskTitle) async {
    final ImagePicker picker = ImagePicker();
    
    // 1. Capture the photo using the device camera
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70, // Compresses image slightly for lighter network payloads
    );

    if (image == null) return; // Child canceled camera action

    // Show loading indicators
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Row(
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(width: 16),
          Text("Uploading proof image to Mom & Dad..."),
        ],
      ), duration: Duration(days: 1)), // Long duration kept alive manually
    );

    try {
      // 2. Read file bits and upload to Supabase Storage Bucket
      final bytes = await image.readAsBytes();
      final String fileExtension = image.path.split('.').last;
      final String fileName = '${supabaseService.currentUserId}_${taskId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final String filePath = 'proofs/$fileName';

      await supabaseService.client.storage
          .from('task-proofs')
          .uploadBinary(filePath, bytes);

      // 3. Resolve the public asset path URL
      final String publicUrl = supabaseService.client.storage
          .from('task-proofs')
          .getPublicUrl(filePath);

      // 4. Update Database Row state with URL link
      await supabaseService.client
          .from('tasks')
          .update({
            'status': 'pending', // Marks it for parent approval verification loop
            'proof_url': publicUrl,
          })
          .eq('id', taskId);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        _refreshData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent proof for "$taskTitle" successfully! Waiting for approval. 🌟')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to transmit photo validation: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- Parent Component: Localized FPX Direct Debit Link Card (Layout Bounded) ---
  Widget _buildMockBankLinkCard() {
    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isBankLinked 
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFFE5E7EB), const Color(0xFFF3F4F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isBankLinked ? Colors.transparent : const Color(0xFFD1D5DB),
          width: 1.5,
        ),
      ),
      child: _isBankLinked ? _buildLinkedFPXView() : _buildUnlinkedFPXForm(),
    );
  }

  Widget _buildLinkedFPXView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  'FPX DIRECT DEBIT ACTIVE',
                  style: TextStyle(color: Colors.tealAccent[400], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
            const Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 22),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _selectedBank,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Account No: ${_accountNumberController.text}',
          style: TextStyle(color: Colors.grey[400], fontSize: 14, fontFamily: 'Courier', letterSpacing: 0.5),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Limit: RM 500.00 / month', style: TextStyle(color: Colors.white70, fontSize: 13)),
          TextButton(
              onPressed: () async {
                final String? parentId = supabaseService.currentUserId;
                if (parentId == null) return;

                try {
                  // 🗑️ WIPE FROM DATABASE: Clear configuration settings row variables
                  await supabaseService.client
                      .from('profiles')
                      .update({
                        'linked_bank_name': null,
                        'bank_account_number': null,
                      })
                      .eq('id', parentId);

                  setState(() {
                    _isBankLinked = false;
                    _accountNumberController.clear();
                  });
                  
                  _refreshData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to sever bank connection: $e')),
                    );
                  }
                }
              },
              child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildUnlinkedFPXForm() {
    final List<String> malaysianBanks = ['Bank Islam', 'Maybank', 'CIMB Bank', 'Public Bank', 'RHB Bank', 'Hong Leong Bank'];
    
    return Column(
      mainAxisSize: MainAxisSize.min, 
      crossAxisAlignment: CrossAxisAlignment.stretch, 
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Link Funding Account via FPX',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
              decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(6)), 
              child: const Text('FPX', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold))
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedBank,
          decoration: InputDecoration(
            labelText: 'Select Bank Name', 
            filled: true, 
            fillColor: Colors.white, 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: malaysianBanks.map((bank) => DropdownMenuItem(value: bank, child: Text(bank))).toList(),
          onChanged: (val) => setState(() => _selectedBank = val!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _accountNumberController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Bank Account Number', 
            hintText: 'e.g. 164283948291', 
            filled: true, 
            fillColor: Colors.white, 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6), 
            padding: const EdgeInsets.symmetric(vertical: 16), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
onPressed: () async {
            final String accountNo = _accountNumberController.text.trim();
            if (accountNo.length < 8) return;
            
            final String? parentId = supabaseService.currentUserId;
            if (parentId == null) return;

            try {
              // 💾 WRITE TO DATABASE: Store bank linkage properties securely
              await supabaseService.client
                  .from('profiles')
                  .update({
                    'linked_bank_name': _selectedBank,
                    'bank_account_number': accountNo,
                  })
                  .eq('id', parentId);

              setState(() {
                _isBankLinked = true;
              });
              
              _refreshData(); // Refresh payload
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('FPX Authorization Failure: $e'), backgroundColor: Colors.redAccent),
                );
              }
            }
          },
          child: const Text('Authorize & Link Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

Widget _buildLinkedChildrenSection() {
    final String? parentId = supabaseService.currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Managed Households 🧑‍🧑‍🧒',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Active Panel',
                style: TextStyle(color: Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (!_isBankLinked) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: const [
                Text('🔒', style: TextStyle(fontSize: 44)),
                SizedBox(height: 12),
                Text('Household Pairings Suspended', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                SizedBox(height: 8),
                Text(
                  'Your paired child accounts are safely stored but temporarily locked. Reconnect your bank account via FPX above to instantly restore allowance distribution profiles and task management panels.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4), 
                ),
              ],
            ),
          ),
        ] else ... [
          FutureBuilder<List<dynamic>>(
            // 🛠️ FIXED: Joined 'wallets' relation inside the select filter context statement
            future: supabaseService.client
                .from('profiles')
                .select('id, username, email, is_approved, tasks(id, status), wallets(total_balance, save_balance, spend_balance, share_balance)')
                .eq('parent_id', parentId ?? '')
                .eq('role', 'child'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: Color(0xFF8B5CF6))));
              }

              final kidsList = snapshot.data ?? [];

              if (kidsList.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text('📡', style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 12),
                      const Text('Awaiting Child Connection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      Text(
                        'Give your registered email address to your kid:\n"${supabaseService.client.auth.currentUser?.email ?? ''}"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                      ),
                    ],
                  ),
                );
              }

              // 🌟 RESPONSIVE GRID GRID LAYOUT BLOCK
         return LayoutBuilder(
                builder: (context, constraints) {
                  // If screen width is wider than 600px, use a two-column responsive split grid natively
                  final int crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
                  
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: kidsList.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 100, // Explicit bounded height layout profile
                    ),
                    itemBuilder: (context, index) {
                      final kid = kidsList[index];
                      final String kidName = kid['username'] ?? 'Young Saver';
                      final String kidId = kid['id'];
                      final bool isApproved = kid['is_approved'] ?? false;
                      
                      final List<dynamic> tasks = kid['tasks'] ?? [];
                      final int pendingCount = tasks.where((t) => t['status'] == 'pending').length;

                      // 🧮 FIXED: Parsed nested relation object as a Map instead of a List to avoid type crash
                      final dynamic walletMap = kid['wallets'];
                      double childBalance = 0.00;
                      
                      if (walletMap != null && walletMap is Map) {
                        if (walletMap['total_balance'] != null) {
                          childBalance = double.parse(walletMap['total_balance'].toString());
                        } else {
                          final double s = double.parse((walletMap['save_balance'] ?? 0.0).toString());
                          final double sp = double.parse((walletMap['spend_balance'] ?? 0.0).toString());
                          final double sh = double.parse((walletMap['share_balance'] ?? 0.0).toString());
                          childBalance = s + sp + sh;
                        }
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          // Subtle border tracking to pop cards off clean white layouts
                          border: Border.all(
                            color: isApproved 
                                ? (pendingCount > 0 ? const Color(0xFFFDBA74) : const Color(0xFFE2E8F0))
                                : const Color(0xFFFED7AA),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            // ✅ UPDATED REACTIVE LAYOUT CALL ROUTE:
                            onTap: () async { // 👈 Ensure 'async' is here
                              if (isApproved) {
                                // 🌟 THE JEDI MOVEMENT: Await the bottom sheet lifespan closure directly
                                await _showParentTaskManagerBottomSheet(kidName, kidId);
                                
                                // 🚀 Triggers immediately to pull fresh values from the DB right when the sheet is closed!
                                _refreshData();
                              } else {
                                _handleInstantApproval(kidId, kidName);
                              }
                            },
                            child: Center(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                leading: Badge(
                                  isLabelVisible: pendingCount > 0,
                                  label: Text('$pendingCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  backgroundColor: const Color(0xFFEA580C),
                                  child: CircleAvatar(
                                    backgroundColor: isApproved ? const Color(0xFFF3E8FF) : const Color(0xFFFFEDD5),
                                    radius: 22,
                                    child: Text(isApproved ? '🐯' : '🔓', style: const TextStyle(fontSize: 20)),
                                  ),
                                ),
                                title: Text(
                                  kidName, 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    !isApproved 
                                        ? 'Status: Pending Approval Gates'
                                        : pendingCount > 0 
                                            ? '⚠️ Has tasks awaiting proof check' 
                                            : 'Balance: RM ${childBalance.toStringAsFixed(2)} 🟡', // 🛠️ FIXED: Output formatted currency explicitly 
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: !isApproved 
                                          ? const Color(0xFFEA580C) 
                                          : (pendingCount > 0 ? const Color(0xFFC2410C) : const Color(0xFF16A34A)), 
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                trailing: Icon(
                                  isApproved ? Icons.chevron_right_rounded : Icons.lock_open_rounded, 
                                  color: isApproved ? Colors.grey[400] : const Color(0xFFEA580C),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _handleInstantApproval(String childId, String childName) async {
    try {
      await supabaseService.client
          .from('profiles')
          .update({'is_approved': true})
          .eq('id', childId);
      
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$childName has been approved and linked!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approval failed: $e')));
      }
    }
  }

Future<bool> _handleRemoveChildFromHousehold(String childId, String childName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove $childName? ⚠️', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove $childName from your managed household?\n\n'
          'This will sever their connection parameters and place their profile back into pending approval status.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Child', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return false;

    try {
      await supabaseService.client
          .from('profiles')
          .update({
            'parent_id': null,
            'is_approved': false,
          })
          .eq('id', childId);
      
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$childName has been unlinked successfully.')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unlinking failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
      return false;
    }
  }

  Widget _buildTinyLegendDot(Color color, String text) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 3),
      Text(
        text,
        style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500),
      ),
    ],
  );
}
}