import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../supabase_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginMode = true;
  int _signupStep = 1; // 1: Credentials, 2: Role Selection, 3: Goals Setup
  String _selectedRole = 'child';
  
  final _formKey = GlobalKey<FormState>();
  final _goalFormKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _goalNameController = TextEditingController();
  final TextEditingController _goalAmountController = TextEditingController();
  final TextEditingController _parentEmailController = TextEditingController();
  
  bool _isLoading = false;

  void _toggleAuthMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _signupStep = 1;
      _formKey.currentState?.reset();
      _goalFormKey.currentState?.reset();
      _emailController.clear();
      _passwordController.clear();
      _usernameController.clear();
    });
  }

  // --- Step 1: Login Check or Local Validation ---
  Future<void> _handleStepOneSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLoginMode) {
      setState(() => _isLoading = true);
      try {
        final response = await supabaseService.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        
        if (response.user != null) {
          // Verify if child approval gate condition is fully satisfied
          final profileCheck = await supabaseService.client
              .from('profiles')
              .select('role, is_approved')
              .eq('id', response.user!.id)
              .maybeSingle();

          if (profileCheck != null && profileCheck['role'] == 'child' && !(profileCheck['is_approved'] ?? false)) {
            await supabaseService.client.auth.signOut();
            if (mounted) _showWaitingForApprovalDialog();
            return;
          }
          _navigateToDashboard();
        }
      } catch (e) {
        _showSnackBar('Login Failed: ${e.toString()}');
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      // Purely local step transition. No network request made yet!
      setState(() => _signupStep = 2);
    }
  }

  // --- Step 2: Local Role Navigation Trigger ---
  Future<void> _handleStepTwoSubmit() async {
    if (_selectedRole == 'parent') {
      // Parent has no step 3. Finalize registration right here.
      await _executeFinalRegistration();
    } else {
      // Child transitions forward to target setup
      setState(() => _signupStep = 3);
    }
  }

  // --- Step 3 / Final Processing Layer ---
  Future<void> _executeFinalRegistration() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    try {
      String? parentUuid;

      // If account is a child, pre-verify parent presence before triggering auth signup
      if (_selectedRole == 'child') {
        if (!_goalFormKey.currentState!.validate()) return;
        
        final parentEmail = _parentEmailController.text.trim();
        final parentLookup = await supabaseService.client
            .from('profiles')
            .select('id')
            .eq('email', parentEmail)
            .eq('role', 'parent')
            .maybeSingle();

        if (parentLookup == null) {
          if (mounted) _showMissingParentDialog(parentEmail);
          return;
        }
        parentUuid = parentLookup['id'] as String;
      }

      // --- ALL CHECKS PASSED: Commit to Supabase Identity Vault ---
      final response = await supabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (response.user != null) {
        final profileId = response.user!.id;

        if (_selectedRole == 'parent') {
          await supabaseService.client.from('profiles').insert({
            'id': profileId,
            'username': username,
            'email': email,
            'role': 'parent',
            'is_approved': true,
            'xp': 0,
            'streak': 1,
          });
          _navigateToDashboard();
        } else {
          // 1. Commit child baseline profile data row
          await supabaseService.client.from('profiles').insert({
            'id': profileId,
            'username': username,
            'email': email,
            'role': 'child',
            'parent_id': parentUuid,
            'is_approved': false,
            'xp': 0,
            'streak': 1,
          });

          // 2. Commit target core savings goals configuration metrics
          await supabaseService.client.from('savings_goals').insert({
            'profile_id': profileId,
            'goal_name': _goalNameController.text.trim(),
            'target_amount': double.parse(_goalAmountController.text.trim()),
            'current_amount': 0.00,
          });

          if (mounted) _showWaitingForApprovalDialog();
        }
      }
    } catch (e) {
      _showSnackBar('Account registration failed: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    Widget currentFormBody;
    
    if (_isLoginMode) {
      currentFormBody = _buildCredentialForm();
    } else {
      switch (_signupStep) {
        case 2:
          currentFormBody = _buildRoleSelectionForm();
          break;
        case 3:
          currentFormBody = _buildGoalSetupForm();
          break;
        default:
          currentFormBody = _buildCredentialForm();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: currentFormBody,
          ),
        ),
      ),
    );
  }

  // --- UI Form Frameworks ---

  Widget _buildCredentialForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('🦉', textAlign: TextAlign.center, style: TextStyle(fontSize: 72)),
          const SizedBox(height: 12),
          Text(
            _isLoginMode ? 'Welcome Back!' : 'Create Credentials',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 24),
          if (!_isLoginMode) ...[
            _buildInputField(
              controller: _usernameController,
              label: 'Choose a Cool Username',
              icon: Icons.face_rounded,
              validator: (val) => val == null || val.trim().isEmpty ? 'Tell us your name!' : null,
            ),
            const SizedBox(height: 16),
          ],
          _buildInputField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email address.' : null,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _passwordController,
            label: 'Secret Password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters.' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isLoading ? null : _handleStepOneSubmit,
            child: Text(_isLoginMode ? 'Login' : 'Next Step ➡️', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _toggleAuthMode,
            child: Text(_isLoginMode ? 'New around here? Create an account!' : 'Already saving coins? Log in here!'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('🧑‍🧑‍🧒', textAlign: TextAlign.center, style: TextStyle(fontSize: 72)),
        const SizedBox(height: 12),
        const Text('Choose Your Role', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        _buildRoleCard(
          roleValue: 'parent',
          title: 'I am a Parent 🧑‍💼',
          subtitle: 'Assign custom chore missions & fund wallet allowances.',
        ),
        const SizedBox(height: 16),
        _buildRoleCard(
          roleValue: 'child',
          title: 'I am a Child 🐯',
          subtitle: 'Complete goals, track choices, and build savings pockets.',
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => setState(() => _signupStep = 1), // Step Backward
                child: const Text('Back', style: TextStyle(fontSize: 16, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _handleStepTwoSubmit,
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_selectedRole == 'parent' ? 'Register 🎉' : 'Next Step ➡️', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalSetupForm() {
    return Form(
      key: _goalFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('🎯', textAlign: TextAlign.center, style: TextStyle(fontSize: 72)),
          const SizedBox(height: 12),
          const Text('Set Savings Goals!', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildInputField(
            controller: _goalNameController,
            label: 'What do you want to save for? (e.g. Toy Car)',
            icon: Icons.star_border_rounded,
            validator: (val) => val == null || val.trim().isEmpty ? 'Enter a target item.' : null,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _goalAmountController,
            label: 'Target Cost (RM)',
            icon: Icons.payments_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (val) => val == null || double.tryParse(val) == null ? 'Enter a valid cost amount.' : null,
          ),
          const SizedBox(height: 24),
          const Text('Link to Parents 🧑‍🧑‍🧒', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _buildInputField(
            controller: _parentEmailController,
            label: 'Parents\' Registered Email',
            icon: Icons.supervisor_account_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (val) => val == null || !val.contains('@') ? 'Enter parent\'s email address.' : null,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => setState(() => _signupStep = 2), // Step Backward
                  child: const Text('Back', style: TextStyle(fontSize: 16, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _executeFinalRegistration,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Register 🎉', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({required String roleValue, required String title, required String subtitle}) {
    final isSelected = _selectedRole == roleValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = roleValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent, width: 2.5),
          boxShadow: isSelected ? [BoxShadow(color: Colors.purple.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required IconData icon, bool obscureText = false, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF8B5CF6)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  void _showWaitingForApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Awaiting Parent Approval! ✉️', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('We\'ve sent a confirmation request to your parent. Once they approve it from their side, you will get instant access to your coin dashboard!', textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Center(child: Text('OK', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  void _showMissingParentDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Parent Not Found!'),
        content: Text('No parent account is registered under "$email". Have them sign up first!'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back'))],
      ),
    );
  }
}