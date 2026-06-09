import 'package:flutter/material.dart';
import '../main.dart'; 
import '../supabase_service.dart';
import '../models.dart';
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
import 'package:flutter/foundation.dart' show kIsWeb; // 💡 Required for kIsWeb and defaultTargetPlatform
import 'package:mobile_scanner/mobile_scanner.dart';
import '../widgets/parent_task_manager_sheet.dart';
import '../services/transaction_categorizer.dart'; 
import 'package:camera/camera.dart';

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
  double _monthlyTransferLimit = 500.00; // State variable inside _HomeScreenState

  // --- FPX Linkage Configuration Parameters ---
  bool _isBankLinked = false;
  String _selectedBank = 'Bank Islam';
  final TextEditingController _accountNumberController = TextEditingController();

  // 💡 ADD THESE THREE LINES HERE:
  String? _activeCameraTaskId; 
  CameraController? _cameraController;
  bool _isCameraInitializing = false;

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
    _cameraController?.dispose();
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
      // 1. Fetch the logged-in user's profile metadata row
      final profileDbResponse = await supabaseService.client
          .from('profiles')
          .select('''
            *,
            is_frozen,
            parental_content_restriction,
            monthly_transfer_limit,
            parent_name:parent_id(username)
          ''')
          .eq('id', loggedInUserId)
          .maybeSingle();

      if (profileDbResponse == null) {
        throw Exception('User profile metadata row not found.');
      }

      final profileMetrics = UserModel.fromJson(profileDbResponse as Map<String, dynamic>);
      String targetWalletUserId = loggedInUserId;

      // 🦉 ROLE CHECK: If a Parent is viewing, pivot target context to the linked child
      if (profileMetrics.role == 'parent') {
        final List<dynamic> linkedKids = await supabaseService.client
            .from('profiles')
            .select('id')
            .eq('parent_id', loggedInUserId)
            .eq('role', 'child')
            .limit(1);

        if (linkedKids.isNotEmpty) {
          targetWalletUserId = linkedKids.first['id'];
        }
      }

      // 2. Fetch the wallet data row from the 'wallets' table
      List<dynamic> walletRecords = await supabaseService.client
          .from('wallets')
          .select('total_balance, save_balance, spend_balance, share_balance') // 🎯 FIXED
          .eq('profile_id', targetWalletUserId);

      // ⚡ AUTO-PROVISION ENGINE: If no wallet exists, write a default row immediately
      if (walletRecords.isEmpty) {
        final Map<String, dynamic> defaultWalletRow = {
          'profile_id': targetWalletUserId,
          'total_balance': 0.00,
          'save_balance': 0.00,
          'spend_balance': 0.00,
          'share_balance': 0.00,
        };

        // Persist default placeholder row structurally straight to PostgreSQL
        await supabaseService.client.from('wallets').insert(defaultWalletRow);

        // Re-read or simulate the newly minted records array context layout
        walletRecords = [defaultWalletRow];
      }

      // Map backend values seamlessly into your frontend WalletModel structure
      final currentWalletData = walletRecords.first;
      final walletMetrics = WalletModel(
        profileId: targetWalletUserId,
        totalBalance: (currentWalletData['total_balance'] ?? 0.0).toDouble(), // 🎯 FIXED
        saveBalance: (currentWalletData['save_balance'] ?? 0.0).toDouble(),
        spendBalance: (currentWalletData['spend_balance'] ?? 0.0).toDouble(),
        shareBalance: (currentWalletData['share_balance'] ?? 0.0).toDouble(),
      );

      // AUTOMATION LINK: Parse bank metadata attributes straight into active state fields for parents
      final String? dbBank = profileDbResponse['linked_bank_name'];
      final String? dbAccount = profileDbResponse['bank_account_number'];
      final double dbLimit = (profileDbResponse['monthly_transfer_limit'] as num?)?.toDouble() ?? 500.00;

      if (profileMetrics.role == 'parent') {
        final double dbLimit = (profileDbResponse['monthly_transfer_limit'] as num?)?.toDouble() ?? 500.00;
        _monthlyTransferLimit = dbLimit;
      } else {
        _monthlyTransferLimit = 0.00; // 👈 Hard-lock children visibility to exactly zero
      }
      
      if (dbBank != null && dbAccount != null) {
        _isBankLinked = true;
        _selectedBank = dbBank;
        _accountNumberController.text = dbAccount;
        _monthlyTransferLimit = dbLimit;
      } else {
        _isBankLinked = false;
      }

      return DashboardData(profile: profileMetrics, wallet: walletMetrics);
    } catch (e) {
      throw Exception('Failed to synchronize dashboard telemetry: $e');
    }
  }

Future<void> _startInlineCardCamera(String taskId) async {
    if (appSystemCameras.isEmpty) {
      try {
        appSystemCameras = await availableCameras();
      } catch (e) {
        debugPrint('Live camera array query failed: $e');
      }
    }

    if (appSystemCameras.isEmpty) {
      debugPrint('⚠️ Hardware list empty. Creating a default browser stream fallback proxy.');
      appSystemCameras = [
        const CameraDescription(
          name: '0', 
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 0,
        )
      ];
    }

    setState(() {
      _isCameraInitializing = true;
      _activeCameraTaskId = taskId;
    });

    // 💡 STEP 1: Fully break down the old reference first
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null; // Forces memory pointer dereference
    }

    CameraDescription selectedLens;

    if (kIsWeb) {
      selectedLens = appSystemCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => appSystemCameras.first,
      );
    } else {
      selectedLens = appSystemCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => appSystemCameras.first,
      );
    }

    try {
      _cameraController = CameraController(
        selectedLens,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
    } catch (e) {
      debugPrint('First camera track initialization failed: $e');
      
      // 💡 STEP 2: Instantly clear out the broken controller instance pointer 
      // before attempting the direct fallback initialization
      try {
        await _cameraController?.dispose();
      } catch (_) {}
      _cameraController = null; 

      debugPrint('🎯 Triggering clean absolute fallback on Index-0 Camera Asset Track.');
      
      try {
        _cameraController = CameraController(
          appSystemCameras.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
      } catch (fallbackError) {
        debugPrint('Absolute fallback failed: $fallbackError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Camera lock failed: Please ensure no other app or widget is using the webcam.'),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCameraInitializing = false);
      }
    }
  }

  Future<void> _snapAndUploadProof(String taskId, String taskTitle) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      // 1. Instantly snap photo file
      final XFile imageFile = await _cameraController!.takePicture();

      // 2. Shut down viewfinder block layouts immediately
      await _cameraController?.dispose();
      _cameraController = null;
      
      setState(() {
        _activeCameraTaskId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading photo validation payload to parents...')),
      );

      // 3. Prepare transmission vectors
      final bytes = await imageFile.readAsBytes();
      final String fileExtension = imageFile.path.split('.').last;
      final String fileName = '${supabaseService.currentUserId}_${taskId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final String filePath = 'proofs/$fileName';

      // 4. Fire directly to Supabase Storage
      await supabaseService.client.storage
          .from('task-proofs')
          .uploadBinary(filePath, bytes);

      final String publicUrl = supabaseService.client.storage
          .from('task-proofs')
          .getPublicUrl(filePath);

      // 5. Commit status update to PostgreSQL database
      await supabaseService.client
          .from('tasks')
          .update({
            'status': 'pending',
            'proof_url': publicUrl,
          })
          .eq('id', taskId);

      _refreshData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent proof for "$taskTitle" successfully! Awaiting verification. 🌟')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showAddTaskBottomSheet(String childName, String childId) {
    final TextEditingController taskTitleController = TextEditingController();
    final TextEditingController taskRewardController = TextEditingController();
    final TextEditingController taskDescController = TextEditingController(); 
    String selectedInterval = 'none'; 
    DateTime? selectedDueDate;
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
              const SizedBox(height: 12),
              TextFormField(
                controller: taskDescController,
                decoration: InputDecoration(
                  labelText: 'Task Description (Optional)',
                  hintText: 'e.g., Wipe down the shelves and vacuum under the bed',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              StatefulBuilder(
                builder: (context, setModalState) {
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Repeat Interval',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('One-time Task')),
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        selectedInterval = val ?? 'none';
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setModalState) {
                  return InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDueDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDueDate == null 
                                ? 'Set End Date (Optional)' 
                                : 'End Date: ${selectedDueDate!.toLocal().toString().split(' ')[0]}',
                            style: TextStyle(
                              color: selectedDueDate == null ? Colors.grey[600] : Colors.black,
                              fontSize: 14,
                            ),
                          ),
                          Icon(Icons.calendar_month_rounded, color: Colors.grey[600], size: 20),
                        ],
                      ),
                    ),
                  );
                },
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
                        'description': taskDescController.text.trim(),
                        'reward_amount': double.parse(taskRewardController.text.trim()),
                        'status': 'assigned',
                        'recurring_interval': selectedInterval,
                        'due_date': selectedDueDate?.toIso8601String(),
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

  void _showAdjustLimitDialog() {
  final TextEditingController limitController = TextEditingController(text: _monthlyTransferLimit.toStringAsFixed(2));
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Adjust Transfer Limit ⚙️', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: limitController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Monthly Spending Ceiling (RM)',
            prefixText: 'RM ',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (value) {
            if (value == null || double.tryParse(value) == null) return 'Please enter a valid number';
            if (double.parse(value) < 0) return 'Limit cannot be negative!';
            return null;
          },
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
            final double newLimit = double.parse(limitController.text.trim());
            final String? parentId = supabaseService.currentUserId;

            if (parentId != null) {
              try {
                await supabaseService.client
                    .from('profiles')
                    .update({'monthly_transfer_limit': newLimit})
                    .eq('id', parentId);

                setState(() {
                  _monthlyTransferLimit = newLimit;
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  _refreshData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Monthly transfer limit updated to RM ${newLimit.toStringAsFixed(2)}!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update ceiling settings: $e')),
                  );
                }
              }
            }
          },
          child: const Text('Save Limit', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

Future<void> _showParentTaskManagerBottomSheet(String childName, String childId) async {
  // 🧠 Await the explicit action code returned upon closing the context frame channel
  final String? forwardAction = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: true, 
    enableDrag: true,    
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => ParentTaskManagerSheet(childName: childName, childId: childId),
  );

  if (forwardAction == null) {
    debugPrint('🤫 Swiped down/dismissed without explicit action: Absolute silent refresh checks.');
    _refreshData(); // Always align local dashboard matrices just in case toggles were flipped
    return;
  }

  // Handle downstream structural route redirections cleanly
  switch (forwardAction) {
    case 'transfer':
      _showTransferMoneyBottomSheet(childName, childId);
      break;
    case 'assign':
      _showAddTaskBottomSheet(childName, childId);
      break;
    case 'remove':
      final bool removed = await _handleRemoveChildFromHousehold(childId, childName);
      if (removed) _refreshData();
      break;
    default:
      _refreshData();
  }
}

  // ⚡ MUTATION: Flips target milestone status context to achieved
  Future<void> _handleMarkGoalAsAchieved(String goalId, String goalName) async {
    try {
      await supabaseService.client
          .from('savings_goals')
          .update({'status': 'achieved'})
          .eq('id', goalId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('🎉 Awesome! Saved "$goalName" to the Achieved Vault!'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error archiving completed milestone: $e');
    }
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
            // 🎯 VISUAL TWEAK: Clarified that the split matches the parent's current rule configuration
            const Text(
              'Funds will be instantly distributed across pockets based on your configured matrix split rules.',
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
                  backgroundColor: const Color(0xFF10B981), 
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final double transferAmount = double.parse(amountController.text.trim());
                  
                  try {
                    // 🎯 FIX 1: Fetch the customized pocket parameters for this child live on execution
                    final profileSnapshot = await supabaseService.client
                        .from('profiles')
                        .select('save_reward_percentage, spend_reward_percentage, share_reward_percentage')
                        .eq('id', childId)
                        .maybeSingle();

                    // Fallback securely back to 70-20-10 if rows are missing or unassigned
                    final double savePct = (profileSnapshot?['save_reward_percentage'] as num?)?.toDouble() ?? 70.0;
                    final double spendPct = (profileSnapshot?['spend_reward_percentage'] as num?)?.toDouble() ?? 20.0;
                    final double sharePct = (profileSnapshot?['share_reward_percentage'] as num?)?.toDouble() ?? 10.0;

                    // Fetch current wallet structural profile matrices
                    final List<dynamic> walletRecords = await supabaseService.client
                        .from('wallets')
                        .select('total_balance, save_balance, spend_balance, share_balance')
                        .eq('profile_id', childId);

                    // 🎯 FIX 2: Apply dynamic percentages to the calculations
                    final double saveIncrement = transferAmount * (savePct / 100.0);
                    final double spendIncrement = transferAmount * (spendPct / 100.0);
                    final double shareIncrement = transferAmount * (sharePct / 100.0);

                    if (walletRecords.isNotEmpty) {
                      final currentWallet = walletRecords.first;
                      
                      final double currentTotal = (currentWallet['total_balance'] ?? 0.0).toDouble();
                      final double currentSave = (currentWallet['save_balance'] ?? 0.0).toDouble();
                      final double currentSpend = (currentWallet['spend_balance'] ?? 0.0).toDouble();
                      final double currentShare = (currentWallet['share_balance'] ?? 0.0).toDouble();

                      await supabaseService.client
                          .from('wallets')
                          .update({
                            'total_balance': currentTotal + transferAmount,
                            'save_balance': currentSave + saveIncrement,
                            'spend_balance': currentSpend + spendIncrement,
                            'share_balance': currentShare + shareIncrement,
                          })
                          .eq('profile_id', childId);
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

      // 🎯 FIX 1: Fetch the custom bucket ratio percentages set by the parent for this child
      final profileSnapshot = await supabaseService.client
          .from('profiles')
          .select('save_reward_percentage, spend_reward_percentage, share_reward_percentage')
          .eq('id', childId)
          .maybeSingle();

      // Guard values with clean fallback defaults back to 70-20-10 if unassigned in database rows
      final double savePct = (profileSnapshot?['save_reward_percentage'] as num?)?.toDouble() ?? 70.0;
      final double spendPct = (profileSnapshot?['spend_reward_percentage'] as num?)?.toDouble() ?? 20.0;
      final double sharePct = (profileSnapshot?['share_reward_percentage'] as num?)?.toDouble() ?? 10.0;

      // 3. FETCH current wallet values directly from your table
      final List<dynamic> walletRecords = await supabaseService.client
          .from('wallets')
          .select('total_balance, save_balance, spend_balance, share_balance')
          .eq('profile_id', childId);

      // 🎯 FIX 2: Dynamic Split Engine using the retrieved custom percentage parameters
      final double saveIncrement = amount * (savePct / 100.0);
      final double spendIncrement = amount * (spendPct / 100.0);
      final double shareIncrement = amount * (sharePct / 100.0);

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

          // 🛡️ Evaluate parental content lock gates dynamically from profile state mapping parameters
          final bool isContentRestricted = profile.parentalContentRestriction ?? false;

          // 🗂️ TAB CONFIGURATION: Intercepts and blocks specific analytical routes conditionally using an inline check
          final List<Widget> screens = [
            _buildHomeDashboard(snapshot),          // Screen 1: Home Dashboard Panel
            const GoalsScreen(),                    // Screen 2: Missions & Saving Targets Target Line
            
            // 📊 Screen 3: Money Report Screen (Conditionally Restricted)
            isContentRestricted 
                ? const RestrictedPagePlaceholder(pageTitle: 'Financial Performance Report')
                : const MoneyReportScreen(),
                
            // 📜 Screen 4: Transaction History Screen (Conditionally Restricted)
            isContentRestricted 
                ? const RestrictedPagePlaceholder(pageTitle: 'Transaction History')
                : const TransactionHistoryScreen(),  
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
                                                // 🧑‍🧑‍🧒 PARENT LOGICAL INDICATOR:
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Linked to: ${profile.parentName ?? "Parent Account"} ', 
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6)),
                                                    ),
                                                    const Icon(Icons.supervisor_account_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                                    const SizedBox(width: 4),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
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
                                          // 🧑‍🧑‍🧒 PARENT LOGICAL INDICATOR:
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Linked to: ${profile.parentName ?? "Parent Account"} ', 
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6)),
                                              ),
                                              const Icon(Icons.supervisor_account_rounded, size: 18, color: Color(0xFF8B5CF6)),
                                              const SizedBox(width: 4),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
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
    final wallet = snapshot.data!.wallet;

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
            _buildLinkedChildrenSection(wallet),
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
    // 🎯 FIXED: Pull totalBalance directly from your model property if available
    final double totalBalance = wallet.totalBalance ?? 
        ((wallet.spendBalance ?? 0.0) + (wallet.saveBalance ?? 0.0) + (wallet.shareBalance ?? 0.0));

    // 2. Calculate the 70/20/10 split dynamically so it matches the bottom sheet
    final double saveAllocated = (wallet.saveBalance ?? 0.0).toDouble();
    final double spendAllocated = (wallet.spendBalance ?? 0.0).toDouble();
    final double shareAllocated = (wallet.shareBalance ?? 0.0).toDouble();

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

    final Widget addTransactionButton = ElevatedButton.icon(
      onPressed: () {
        // Invoke a customized local simulation workflow overlay sheet natively
        _showChildPaymentSimulationBottomSheet(context, wallet);
      },
      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
      label: const Text(
        'Pay',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

void _showChildPaymentSimulationBottomSheet(BuildContext context, dynamic wallet) {
  final TextEditingController accountController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController referenceController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isProcessing = false;
  bool isWalletFrozen = false; 
  bool isLoadingConfig = true;
  
  String activeMode = 'pay'; 
  bool isScannerActive = true; 

  // --- NEW STATE TRACKERS ---
  bool keywordDetected = false;
  bool useShareBucket = false;

  final List<String> shareKeywords = ['gift', 'present', 'donation', 'charity', 'birthday'];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setLocalState) {
        final String? currentProfileId = supabaseService.currentUserId;

        if (isLoadingConfig && currentProfileId != null) {
          supabaseService.client
              .from('profiles')
              .select('is_frozen')
              .eq('id', currentProfileId)
              .maybeSingle()
              .then((snapshot) {
                if (snapshot != null && context.mounted) {
                  setLocalState(() {
                    isWalletFrozen = snapshot['is_frozen'] ?? false;
                    isLoadingConfig = false;
                  });
                }
              });

          return Container(
            height: 250,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
          );
        }

        final bool isPayTab = activeMode == 'pay';

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
              ),
              
              if (isWalletFrozen) ...[
                const SizedBox(height: 12),
                const Center(child: Text('🔒', style: TextStyle(fontSize: 48))),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Uh-oh! Pay & Transfer Locked',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Oh no! Your account has been frozen by your parent. You are not able to pay or transfer for now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Disburse Funds',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setLocalState(() {
                              activeMode = 'pay';
                              isScannerActive = accountController.text.isEmpty; 
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isPayTab ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isPayTab ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ] : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🛒', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 8), 
                                Text(
                                  'Pay',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isPayTab ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 6), 

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setLocalState(() {
                              activeMode = 'transfer';
                              isScannerActive = false; 
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: !isPayTab ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !isPayTab ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ] : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('💸', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Text(
                                  'Transfer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: !isPayTab ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isPayTab && isScannerActive) ...[
                        const Text(
                          'Align Merchant QR Code within the frame:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                        ),
                        const SizedBox(height: 8),
                        EmbeddedQRScanner(
                          onCodeScanned: (scannedCode) {
                            setLocalState(() {
                              accountController.text = scannedCode;
                              isScannerActive = false; 
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        TextFormField(
                          controller: accountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isPayTab ? 'Merchant / Counter Code' : 'Recipient Account Number',
                            hintText: isPayTab ? 'Captured QR Payload Code' : 'e.g., 164283948291 or Phone Number',
                            prefixIcon: Icon(
                              isPayTab ? Icons.storefront_rounded : Icons.account_balance_wallet_rounded, 
                              color: const Color(0xFF8B5CF6), 
                              size: 20,
                            ),
                            suffixIcon: isPayTab ? IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6D28D9)),
                              onPressed: () => setLocalState(() => isScannerActive = true),
                              tooltip: 'Rescan QR',
                            ) : null,
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) 
                              ? (isPayTab ? 'Please type or capture a valid merchant code' : 'Please enter a target account') 
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // --- REASON REFERENCE (Moved up so the Bucket option fields dynamically follow it) ---
                      TextFormField(
                        controller: referenceController,
                        decoration: InputDecoration(
                          labelText: isPayTab ? 'Payment Description' : 'Transfer Note / Reference',
                          hintText: isPayTab ? 'e.g., School canteen lunch, Stationary' : 'What is this money transfer for?',
                          prefixIcon: const Icon(Icons.description_rounded, color: Colors.grey, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) {
                          // Real-time evaluation of the typed description against keywords
                          final text = val.toLowerCase();
                          final dynamicMatch = shareKeywords.any((keyword) => text.contains(keyword));
                          setLocalState(() {
                            keywordDetected = dynamicMatch;
                            if (!keywordDetected) useShareBucket = false; // Reset if text changed away
                          });
                        },
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please add a small reason description' : null,
                      ),
                      const SizedBox(height: 12),

                  // --- NEW DYNAMIC SHARE BUCKET OPT-IN TILE ---
                  if (keywordDetected) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Adjusted padding for Row layout
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7), // Warm Amber hint color
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFBBF24), width: 1),
                      ),
                      // 🎯 FIX: Using a simple Row prevents ListTile ink-splash layer conflicts entirely
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '💝 Use Share Bucket funds?',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Available Share balance: RM ${(wallet.shareBalance ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch.adaptive(
                            activeColor: const Color(0xFFD97706),
                            value: useShareBucket,
                            onChanged: (bool value) {
                              setLocalState(() => useShareBucket = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                      // --- AMOUNT ---
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: useShareBucket ? 'Amount from Share Bucket (RM)' : 'Amount to Disburse (RM)',
                          hintText: '0.00',
                          prefixIcon: Icon(
                            Icons.payments_rounded, 
                            color: useShareBucket ? const Color(0xFFD97706) : const Color(0xFF10B981), 
                            size: 20
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: (val) {
                          if (val == null || double.tryParse(val) == null) return 'Please input a valid number metric';
                          final double parsedAmount = double.parse(val);
                          if (parsedAmount <= 0) return 'Transaction must be greater than RM 0.00';
                          
                          // Dynamic conditional validation step
                          if (useShareBucket) {
                            if (parsedAmount > (wallet.shareBalance ?? 0.0)) {
                              return 'Insufficient balance in your Share Bucket!';
                            }
                          } else {
                            if (parsedAmount > (wallet.spendBalance ?? 0.0)) {
                              return 'Insufficient balance in your Spend Bucket!';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // --- OUTBOUND SUBMIT BUTTON ---
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: useShareBucket ? const Color(0xFFD97706) : const Color(0xFF1F2937),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: isProcessing ? null : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          setLocalState(() => isProcessing = true);
                          final String targetReceiverId = accountController.text.trim();
                          final double debitValue = double.parse(amountController.text.trim());
                          final String logTitle = referenceController.text.trim();

                          if (currentProfileId == null) {
                            setLocalState(() => isProcessing = false);
                            return;
                          }

                          try {
                            final walletSnapshot = await supabaseService.client
                                .from('wallets')
                                .select('total_balance, spend_balance, share_balance')
                                .eq('profile_id', currentProfileId)
                                .maybeSingle();

                            if (walletSnapshot != null) {
                              final double backendTotal = (walletSnapshot['total_balance'] ?? 0.0).toDouble();
                              final double backendSpend = (walletSnapshot['spend_balance'] ?? 0.0).toDouble();
                              final double backendShare = (walletSnapshot['share_balance'] ?? 0.0).toDouble();

                              final String calculatedCategory = isPayTab 
                                  ? TransactionCategorizer.categorize(logTitle)
                                  : 'Peer Transfer';

                              // Prep targeted balances update dictionary dynamically
                              final Map<String, dynamic> walletUpdateData = {
                                'total_balance': backendTotal - debitValue,
                              };

                              if (useShareBucket) {
                                walletUpdateData['share_balance'] = backendShare - debitValue;
                              } else {
                                walletUpdateData['spend_balance'] = backendSpend - debitValue;
                              }

                              await Future.wait([
                                supabaseService.client
                                    .from('wallets')
                                    .update(walletUpdateData)
                                    .eq('profile_id', currentProfileId),
                                
                                supabaseService.client.from('transactions').insert({
                                  'profile_id': currentProfileId,
                                  'title': '$logTitle (${isPayTab ? 'Paid to' : 'Sent to'} $targetReceiverId)',
                                  'amount': -debitValue, 
                                  'category': useShareBucket ? 'Gifts & Charity' : calculatedCategory, 
                                  'created_at': DateTime.now().toIso8601String(),
                                }),
                              ]);

                              if (context.mounted) {
                                Navigator.pop(context); 
                                _refreshData(); 
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF16A34A),
                                    content: Text('🎉 Successfully processed RM ${debitValue.toStringAsFixed(2)} from your ${useShareBucket ? 'Share' : 'Spend'} Bucket!'),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(backgroundColor: Colors.redAccent, content: Text('Transaction aborted: $e')),
                              );
                            }
                          } finally {
                            setLocalState(() => isProcessing = false);
                          }
                        },
                        child: isProcessing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                isPayTab ? (useShareBucket ? 'Pay with Share' : 'Pay') : (useShareBucket ? 'Transfer Share' : 'Transfer'), 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

// 🛠️ FIX: Added 'VoidCallback onFinish' signature to match the dashboard call route parameters
void showSmartMoneyPlanBottomSheet(BuildContext context, WalletModel wallet, VoidCallback onFinish) {
  // 🧮 Calculate portions dynamically from total_balance metric
  final double totalCoins = wallet.totalBalance ?? 
      ((wallet.saveBalance ?? 0.0) + (wallet.spendBalance ?? 0.0) + (wallet.shareBalance ?? 0.0));

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false, // Prevents closing early by tapping outside
    enableDrag: false,
    backgroundColor: Colors.transparent, 
    builder: (context) {
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
                    onPressed: () => Navigator.pop(context), // Pops cleanly; triggers video dispose() automatically
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
                      // 🎞️ LIVE VIDEO PLAYER CONTAINER (Decoupled lifecycle wrapper)
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFF312E81),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: const LocalVideoPlayer(
                            videoUrl: 'https://tbrefzeytkflqyadayvs.supabase.co/storage/v1/object/public/quest-videos/finance_video.mp4',
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

                      // 🟢 SAVE TARGET SEGMENT ROW
                      _buildAllocationCard(
                        title: '💚 Save 70% - Be Smart!',
                        subtitle: 'Put 70% of your money into savings for your big dreams like that gaming console or bicycle! This helps you reach your goals faster! 🎯',
                        icon: '🐷',
                        themeColor: const Color(0xFFDCFCE7),
                        textColor: const Color(0xFF15803D),
                        borderColor: const Color(0xFFBBF7D0),
                      ),
                      const SizedBox(height: 12),

                      // 🔵 SPEND TARGET SEGMENT ROW
                      _buildAllocationCard(
                        title: '💙 Spend 20% - Have Fun!',
                        subtitle: 'Use 20% for fun stuff you want right now! Snacks, games, or treats - enjoy the rewards of your hard work! 🎉',
                        icon: '🛍️',
                        themeColor: const Color(0xFFDBEAFE),
                        textColor: const Color(0xFF1D4ED8),
                        borderColor: const Color(0xFFBFDBFE),
                      ),
                      const SizedBox(height: 12),

                      // 💗 SHARE TARGET SEGMENT ROW
                      _buildAllocationCard(
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
                  final String? profileId = supabaseService.currentUserId;
                  if (profileId != null) {
                    try {
                      await supabaseService.client
                          .from('profiles')
                          .update({'has_completed_onboarding': true})
                          .eq('id', profileId);
                    } catch (e) {
                      debugPrint('Onboarding sync error: $e');
                    }
                  }

                  if (context.mounted) {
                    Navigator.pop(context); // Triggers LocalVideoPlayer's dispose() automatically!
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
}

// 📦 Reusable component helper function to keep build layout footprint clean
Widget _buildAllocationCard({
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

// --- Child Component: Live Tasks Display Panel (Centered Actions & Inline Camera) ---
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
              .select('id, title, description, reward_amount, status, proof_url, assigned_at, due_date') 
              .eq('profile_id', childId)
              .order('id', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
            }

            final tasksList = snapshot.data ?? [];

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
                
                final String taskId = task['id'] is num 
                    ? (task['id'] as num).toString() 
                    : task['id'].toString();
                    
                final String title = task['title'] ?? 'Secret Mission';
                final String? description = task['description'];
                final double reward = (task['reward_amount'] ?? 0.0).toDouble();
                final String status = task['status'] ?? 'assigned';
                final String rawDate = task['assigned_at'] ?? '';
                final String assignedDate = rawDate.isNotEmpty 
                    ? DateTime.parse(rawDate).toLocal().toString().split(' ')[0] 
                    : 'Recent';

                final String? rawDueDate = task['due_date'];
                final DateTime? dueDate = rawDueDate != null ? DateTime.parse(rawDueDate).toLocal() : null;
                final String formattedDueDate = dueDate != null ? dueDate.toString().split(' ')[0] : '';
                final bool isOverdue = dueDate != null && DateTime.now().isAfter(dueDate) && status != 'completed';

                bool isPendingOrDone = status == 'pending' || status == 'completed';
                final bool isCameraOpenForThisTask = _activeCameraTaskId == taskId;

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Main Layout Row: Metadata Left, Centered Controls Right
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center, 
                          children: [
                            // 📝 Left Side text stack (Title, Description, Horizontal Dates)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title, 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
                                  ),
                                  if (description != null && description.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      description.trim(),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.3),
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 12),

                                  // Horizontal Dates Layout (No divider lines)
                                  Wrap(
                                    spacing: 16, 
                                    runSpacing: 4, 
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey[400]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Assigned: $assignedDate',
                                            style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      if (formattedDueDate.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.alarm_rounded, 
                                              size: 12, 
                                              color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isOverdue ? 'Overdue: $formattedDueDate ⚠️' : 'Due: $formattedDueDate',
                                              style: TextStyle(
                                                color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 16),

                            // 🎯 Right Side action stack (Vertically centered relative to entire card)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${reward.toInt()} Coins 🟡',
                                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(width: 12),
                                isPendingOrDone
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: status == 'pending' ? Colors.orange[50] : Colors.green[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          status == 'pending' ? 'PENDING' : 'DONE',
                                          style: TextStyle(
                                            fontSize: 10, 
                                            fontWeight: FontWeight.bold, 
                                            color: status == 'pending' ? Colors.orange[700] : Colors.green[700],
                                          ),
                                        ),
                                      )
                                    : SizedBox(
                                        height: 32,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF8B5CF6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                          label: const Text('Complete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: () => _openCameraPopup(taskId, title), // 🎯 Switch to the new popup view trigger
                                        ),
                                      ),
                              ],
                            ),
                          ],
                        ),

                        // 🎥 Drop-down Inline Camera feed drawer
                        if (isCameraOpenForThisTask) ...[
                          const SizedBox(height: 14),
                          Container(
                            height: 220,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _isCameraInitializing
                                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                : CameraPreview(_cameraController!),
                          ),
                        ],
                      ],
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

void _openCameraPopup(String taskId, String taskTitle) async {
    List<CameraDescription> localCameras = [];
    try {
      localCameras = await availableCameras();
    } catch (e) {
      debugPrint('Direct popup hardware scan failed: $e');
    }

    if (localCameras.isEmpty) {
      localCameras = [
        const CameraDescription(
          name: '0', 
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 0,
        )
      ];
    }

    CameraDescription selectedLens = localCameras.firstWhere(
      (cam) => cam.lensDirection == (kIsWeb ? CameraLensDirection.front : CameraLensDirection.back),
      orElse: () => localCameras.first,
    );

    if (!mounted) return;

    // 🎯 CACHE THE ROOT CONTEXT: Captures your permanent HomeScreen context 
    // before launching the temporary popup tree context lane.
    final BuildContext rootContext = context;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) { // Renamed clearly to separate trees
        CameraController? popupCameraController;
        bool isInitialized = false;
        bool isCapturing = false;

        return StatefulBuilder(
          builder: (context, setPopupState) {
            if (popupCameraController == null) {
              popupCameraController = CameraController(
                selectedLens,
                ResolutionPreset.medium,
                enableAudio: false,
              );

              popupCameraController!.initialize().then((_) {
                if (context.mounted) setPopupState(() => isInitialized = true);
              }).catchError((e) {
                popupCameraController = CameraController(localCameras.first, ResolutionPreset.medium, enableAudio: false);
                popupCameraController!.initialize().then((_) {
                  if (context.mounted) setPopupState(() => isInitialized = true);
                });
              });
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380), 
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '📸 Proof: $taskTitle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                            onPressed: () async {
                              // 💡 LIFE CYCLE FIX: Pop the UI first, then safely dispose background hardware tracks
                              Navigator.pop(dialogContext);
                              await popupCameraController?.dispose();
                            },
                          )
                        ],
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: SizedBox(
                          width: 280,
                          height: 280,
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            clipBehavior: Clip.antiAlias,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(24)),
                            ),
                            color: Colors.black,
                            child: !isInitialized
                                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                : ClipRect(
                                    child: OverflowBox(
                                      alignment: Alignment.center,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: popupCameraController!.value.previewSize!.height,
                                          height: popupCameraController!.value.previewSize!.width,
                                          child: CameraPreview(popupCameraController!),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: (!isInitialized || isCapturing)
                            ? null
                            : () async {
                                setPopupState(() => isCapturing = true);

                                try {
                                  // Snap picture file
                                  final XFile imageFile = await popupCameraController!.takePicture();

                                  // 💡 FIX ENGINE FLOW: Close the UI instantly so the frame stops rendering 
                                  // before clearing the operational camera controllers downstream
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }

                                  // Hand off the hardware controller to the system disposal track safely
                                  final CameraController? controllerToDispose = popupCameraController;
                                  popupCameraController = null;
                                  if (controllerToDispose != null) {
                                    await controllerToDispose.dispose();
                                  }

                                  // 💡 MOUNTED GUARD GUARD: Show temporary warning using the persistent root layout trees
                                  if (rootContext.mounted) {
                                    ScaffoldMessenger.of(rootContext).showSnackBar(
                                      const SnackBar(content: Text('Transmitting image validation assets to Supabase storage...')),
                                    );
                                  }

                                  final bytes = await imageFile.readAsBytes();
                                  final String extension = imageFile.path.split('.').last;
                                  final String name = '${supabaseService.currentUserId}_${taskId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
                                  final String path = 'proofs/$name';

                                  await supabaseService.client.storage.from('task-proofs').uploadBinary(path, bytes);
                                  final String publicUrl = supabaseService.client.storage.from('task-proofs').getPublicUrl(path);

                                  await supabaseService.client.from('tasks').update({
                                    'status': 'pending',
                                    'proof_url': publicUrl,
                                  }).eq('id', taskId);

                                  _refreshData();

                                  if (rootContext.mounted) {
                                    ScaffoldMessenger.of(rootContext).clearSnackBars();
                                    ScaffoldMessenger.of(rootContext).showSnackBar(
                                      SnackBar(content: Text('Sent proof for "$taskTitle" successfully! Awaiting approval. 🌟')),
                                    );
                                  }
                                } catch (e) {
                                  if (rootContext.mounted) {
                                    ScaffoldMessenger.of(rootContext).clearSnackBars();
                                    ScaffoldMessenger.of(rootContext).showSnackBar(
                                      SnackBar(content: Text('Failed to transmit photo proof: $e'), backgroundColor: Colors.redAccent),
                                    );
                                  }
                                }
                              },
                        icon: isCapturing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                        label: Text(
                          isCapturing ? 'Uploading...' : 'Take Photo & Submit',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
      
      // 🔄 UPDATED LAYOUT CARD ACTIONS FOOTER BAR BELOW:
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 📊 DYNAMIC CEILING INDICATOR WITH CLICK EVENT
          InkWell(
            onTap: _showAdjustLimitDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
              child: Row(
                children: [
                  Text(
                    'Limit: RM ${_monthlyTransferLimit.toStringAsFixed(2)} / month', 
                    style: const TextStyle(color: Colors.white70, fontSize: 13)
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_rounded, color: Colors.white54, size: 14),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final String? parentId = supabaseService.currentUserId;
              if (parentId == null) return;

              try {
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

Widget _buildLinkedChildrenSection(WalletModel currentWalletContext) {
    final String? parentId = supabaseService.currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Managed Kids 🧑‍🧒',
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
          ),
          // 📥 New Download Button added cleanly to the right side of the row layout
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6), // Matches your purple design profile
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            icon: const Icon(Icons.download_for_offline_rounded, size: 22),
            label: const Text(
              'Download All Reports',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () async {
              final String? parentId = supabaseService.currentUserId;
              if (parentId == null) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gathering data and packaging family statement archive...'),
                ),
              );

              try {
                // 1. Pull the raw database relation arrays in one quick trip
                final List<dynamic> kidsList = await supabaseService.client
                    .from('profiles')
                    .select('''
                      id, 
                      username, 
                      wallets(total_balance, save_balance, spend_balance, share_balance),
                      transactions(title, category, amount, created_at)
                    ''')
                    .eq('parent_id', parentId)
                    .eq('role', 'child');

                if (kidsList.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No active child accounts found to report.')),
                    );
                  }
                  return;
                }

                // 2. 🚀 NEW CONCURRENT PIPELINE: Hand the dataset completely over to your service layer!
                await SummaryService().generateAndShareHouseholdZipArchive(kidsList);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF10B981),
                      content: Text('🎉 Combined ZIP archive downloaded successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to compile zip package: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
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
                            onTap: () async { 
                              if (isApproved) {
                                // Await the explicit configuration return parameter keys
                                final String? forwardAction = await showModalBottomSheet<String>(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                                  builder: (context) => ParentTaskManagerSheet(childName: kidName, childId: kidId),
                                );
                                
                                if (forwardAction == null) {
                                  _refreshData(); // Sync layout parameters anyway on standard swipe-dismissals
                                  return;
                                }

                                // Branch execution pathways gracefully without overlay clipping traps
                                switch (forwardAction) {
                                  case 'transfer':
                                    _showTransferMoneyBottomSheet(kidName, kidId);
                                    break;
                                  case 'assign':
                                    _showAddTaskBottomSheet(kidName, kidId);
                                    break;
                                  case 'remove':
                                    final bool removed = await _handleRemoveChildFromHousehold(kidId, kidName);
                                    if (removed) _refreshData();
                                    break;
                                  default:
                                    _refreshData();
                                }
                              } else {
                                _handleInstantApproval(kidId, kidName);
                              }
                            },
                            // 2. Keep the trailing property simple
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

class LocalVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const LocalVideoPlayer({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<LocalVideoPlayer> createState() => _LocalVideoPlayerState();
}

class _LocalVideoPlayerState extends State<LocalVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() => _isInitialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose(); // Safely detached by the framework engine natively
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          GestureDetector(
            onTap: () {
              setState(() {
                _controller.value.isPlaying ? _controller.pause() : _controller.play();
              });
            },
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withOpacity(0.9),
              child: Icon(
                _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: const Color(0xFF6366F1),
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RestrictedPagePlaceholder extends StatelessWidget {
  final String pageTitle;
  const RestrictedPagePlaceholder({Key? key, required this.pageTitle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🛡️', style: TextStyle(fontSize: 54)),
              const SizedBox(height: 16),
              Text(
                'Oops! $pageTitle Locked',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 8),
              Text(
                'Your parents have turned on page restrictions. Access to certain pages is paused for now.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmbeddedQRScanner extends StatefulWidget {
  final Function(String) onCodeScanned;

  const EmbeddedQRScanner({super.key, required this.onCodeScanned});

  @override
  State<EmbeddedQRScanner> createState() => _EmbeddedQRScannerState();
}

class _EmbeddedQRScannerState extends State<EmbeddedQRScanner> {
  // Creating the controller inside initState guarantees it initializes exactly ONCE
  late final MobileScannerController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      autoStart: true, // Let it boot up naturally once
    );
  }

  @override
  void dispose() {
    // Explicitly shut down the lens when unmounted from the tree
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: MobileScanner(
        controller: _scannerController,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            final String? codeValue = barcode.rawValue;
            if (codeValue != null && codeValue.trim().isNotEmpty) {
              widget.onCodeScanned(codeValue.trim());
              break;
            }
          }
        },
      ),
    );
  }
}