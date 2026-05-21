import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../supabase_service.dart';
import '../models.dart';
import '../widgets/balance_card.dart';
import 'quest_screen.dart';
import 'goals_screen.dart';
import 'auth_screen.dart'; // Imported to ensure logout forces redirection route

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
    final String? profileId = supabaseService.currentUserId;

    if (profileId == null) {
      throw Exception('No active authenticated user session detected.');
    }

    final walletUri = Uri.parse('${supabaseService.backendBaseUrl}/wallet/$profileId');

    try {
      final responses = await Future.wait<dynamic>([
        http.get(walletUri),
        supabaseService.client.from('profiles').select().eq('id', profileId).maybeSingle(),
      ]);

      final walletHttpResponse = responses[0] as http.Response;
      final profileDbResponse = responses[1];

      if (walletHttpResponse.statusCode == 200) {
        final walletMetrics = WalletModel.fromJson(jsonDecode(walletHttpResponse.body));
        
        UserModel profileMetrics;
        if (profileDbResponse != null) {
          profileMetrics = UserModel.fromJson(profileDbResponse as Map<String, dynamic>);
        } else {
          profileMetrics = UserModel(
            id: profileId,
            username: 'Young Saver',
            role: 'child',
            xp: 0,
            streak: 1,
          );
        }

        return DashboardData(profile: profileMetrics, wallet: walletMetrics);
      } else if (walletHttpResponse.statusCode == 404) {
        String userRole = 'child';
        if (profileDbResponse != null) {
          userRole = profileDbResponse['role'] ?? 'child';
        }

        if (userRole == 'parent') {
          final emptyWalletForParent = WalletModel(
            profileId: profileId,
            saveBalance: 0.00,
            spendBalance: 0.00,
            shareBalance: 0.00,
          );
          
          final profileMetrics = UserModel.fromJson(profileDbResponse as Map<String, dynamic>);
          return DashboardData(profile: profileMetrics, wallet: emptyWalletForParent);
        } else {
          throw Exception('Wallet profile data records are still being synchronized. Please pull down to refresh!');
        }
      } else {
        throw Exception('Failed to synchronize current wallet accounts.');
      }
    } catch (e) {
      throw Exception('Failed to synchronize dashboard telemetry: $e');
    }
  }

  // --- Opens Modal to Assign a Task to a Specific Child Identity Node ---
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
                      await supabaseService.client.from('quests').insert({
                        'profile_id': childId,
                        'title': taskTitleController.text.trim(),
                        'reward_amount': double.parse(taskRewardController.text.trim()),
                        'status': 'assigned',
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
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

  // --- Show Name Alteration Input Frame Dialog ---
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
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profile Settings 🐯', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFF8B5CF6)),
                  title: const Text('Change Username'),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangeUsernameDialog(currentUsername);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Mission Reminders'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
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
        final bool isParent = snapshot.hasData && snapshot.data!.profile.role == 'parent';

        final List<Widget> screens = [
          _buildHomeDashboard(snapshot),
          const QuestScreen(),
          const GoalsScreen(),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          body: SafeArea(child: isParent ? screens[0] : screens[_currentIndex]),
          bottomNavigationBar: isParent
              ? null // 🧠 Hides tracking bars completely to isolate parent administration views
              : BottomNavigationBar(
                  currentIndex: _currentIndex,
                  selectedItemColor: const Color(0xFF8B5CF6),
                  unselectedItemColor: Colors.grey,
                  onTap: (index) => setState(() => _currentIndex = index),
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
                    BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Missions'),
                    BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Dreams'),
                  ],
                ),
        );
      },
    );
  }

Widget _buildHomeDashboard(AsyncSnapshot<DashboardData> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    } else if (snapshot.hasError) {
      return RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Text(
                'Error balancing books: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        ),
      );
    } else if (!snapshot.hasData) {
      return const Center(child: Text('No wallet profile data found.'));
    }

    final profile = snapshot.data!.profile;
    final wallet = snapshot.data!.wallet;
    final bool isParent = profile.role == 'parent';

    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 🧠 Ensures child structures scale properly
          children: [
            // --- Header Component Section ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                ),
                
                PopupMenuButton<String>(
                  tooltip: 'Profile Menu',
                  onSelected: (value) => _handleProfileMenuAction(value, profile.username),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  offset: const Offset(0, 56),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: isParent ? Colors.blue[100] : Colors.amber[100],
                    child: Text(isParent ? '🦉' : '🐯', style: const TextStyle(fontSize: 32)),
                  ),
                  itemBuilder: (BuildContext context) => [
                    //  RESTORED: Available to both Parent and Child profiles universally!
                    PopupMenuItem<String>(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 12),
                          const Text('Profile Settings', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: const [
                          Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                          SizedBox(width: 12),
                          Text('Logout', style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- 🧠 FIXED VIEW INJECTION GATEWAY ---
            // Separating parent configurations from child wallet widgets completely avoids layout row collisions!
            if (isParent) ...[
              _buildMockBankLinkCard(), 
              const SizedBox(height: 28),
              _buildLinkedChildrenSection(),
            ] else ...[
              BalanceCard(wallet: wallet),
            ],
          ],
        ),
      ),
    );
  }

  // --- Parent Component: Localized FPX Direct Debit Link Card (Layout Bounded) ---
  Widget _buildMockBankLinkCard() {
      return Container(
        width: double.infinity, // 🧠 Securely forces card element to span screen boundaries cleanly
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
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
              onPressed: () {
                setState(() {
                  _isBankLinked = false;
                  _accountNumberController.clear();
                });
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
      mainAxisSize: MainAxisSize.min, // 🧠 Forces column to hug content vertically
      crossAxisAlignment: CrossAxisAlignment.stretch, // Handshakes the parent width cleanly
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
          value: _selectedBank,
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
            elevation: 0,
          ),
          onPressed: () {
            if (_accountNumberController.text.trim().length < 8) return;
            setState(() => _isBankLinked = true);
          },
          child: const Text('Authorize & Link Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  void _showBankRequiredBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Security Verification 🏦', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'To preserve regulatory compliance and protect children from unbacked allowance allocations, DuitWise requires an authenticated funding pool before launching child pairing invites.\n\nConnecting a bank accountwill instantiate a verified ledger to backing child reward tasks instantly.',
              style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Got It!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildLinkedChildrenSection() {
    final String? parentId = supabaseService.currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Managed Households 🧑‍🧑‍🧒',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 12),
        
        // 1. Enforce our banking barrier gate condition first
        if (!_isBankLinked) ...[
          // Empty state view block when bank validation fails
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: const [
                Text('🔒', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                Text(
                  'Household Pairings Suspended', // 💡 Updated Title
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your paired child accounts are safely stored but temporarily locked. Reconnect your bank account via FPX above to instantly restore allowance distribution profiles and task management panels.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4), // 💡 Updated Explanatory Text
                ),
              ],
            ),
          ),
        ] else ... [
          // 2. BANK IS ACTIVE: Query Supabase row assets for genuine paired children
          FutureBuilder<List<dynamic>>(
            future: supabaseService.client
                .from('profiles')
                .select('id, username, email, is_approved')
                .eq('parent_id', parentId ?? '')
                .eq('role', 'child'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final kidsList = snapshot.data ?? [];

              // --- STATE A: REAL EMPTY RECORD STATE ---
              if (kidsList.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Text('📡', style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 12),
                      const Text(
                        'Awaiting Child Connection',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Give your registered email address to your kid:\n"${supabaseService.client.auth.currentUser?.email ?? ''}"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Once they enter it during their registration flow, their profile card will automatically materialize here live!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                );
              }

              // --- STATE B: ACTIVE PAIRINGS FOUND RECONCILIATION ---
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: kidsList.length,
                itemBuilder: (context, index) {
                  final kid = kidsList[index];
                  final String kidName = kid['username'] ?? 'Young Saver';
                  final String kidId = kid['id'];
                  final bool isApproved = kid['is_approved'] ?? false;

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber[100],
                        radius: 24,
                        child: const Text('🐯', style: TextStyle(fontSize: 24)),
                      ),
                      title: Text(kidName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(
                        isApproved ? 'Allowance Status: Active' : 'Status: Pending Approval Gates',
                        style: TextStyle(color: isApproved ? Colors.green : Colors.orange, fontWeight: FontWeight.w500),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isApproved ? const Color(0xFF8B5CF6) : Colors.orange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (isApproved) {
                            _showAddTaskBottomSheet(kidName, kidId);
                          } else {
                            // Quick internal approval invocation function loop if clicking a pending child
                            _handleInstantApproval(kidId, kidName);
                          }
                        },
                        child: Text(
                          isApproved ? 'Add Task' : 'Approve Link',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  // --- Helper function to handle approvals natively if a child links up ---
  Future<void> _handleInstantApproval(String childId, String childName) async {
    try {
      // Direct call update to activate child profile rows
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
}