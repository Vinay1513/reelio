import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/supabase_service.dart';
import '../../home/screens/home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _service = SupabaseService();

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerUsernameController = TextEditingController();

  bool _isLoading = false;
  bool _loginObscure = true;
  bool _registerObscure = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerUsernameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final response = await _service.signIn(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
      print('LOGIN - session: ${response.session}');
      print('LOGIN - user: ${response.user}');
      print('LOGIN - user id: ${response.user?.id}');
      if (response.session != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        print('LOGIN - currentUserId after delay: ${_service.currentUserId}');
        
        // Check if profile exists, if not create one
        var profile = await _service.getProfile(_service.currentUserId ?? '');
        print('LOGIN - profile: $profile');
        
        if (profile == null && response.user != null) {
          // Create profile if doesn't exist
          final username = response.user?.userMetadata?['username'] as String? ?? 
              response.user?.email?.split('@').first ?? 'user';
          print('LOGIN - creating profile with username: $username');
          await _service.createProfile(
            response.user!.id, 
            username, 
            response.user!.email ?? ''
          );
          profile = await _service.getProfile(_service.currentUserId ?? '');
          print('LOGIN - profile after creation: $profile');
        }
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final response = await _service.signUp(
        email: _registerEmailController.text.trim(),
        password: _registerPasswordController.text,
        username: _registerUsernameController.text.trim(),
      );
      print('SIGNUP - user: ${response.user}');
      print('SIGNUP - user id: ${response.user?.id}');
      print('SIGNUP - session: ${response.session}');
      if (response.user != null && mounted) {
        await Future.delayed(const Duration(seconds: 1));
        print('SIGNUP - currentUserId after delay: ${_service.currentUserId}');
        if (mounted && _service.currentUserId != null) {
          final profile = await _service.getProfile(_service.currentUserId!);
          print('SIGNUP - profile: $profile');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildLogo(),
              const SizedBox(height: 48),
              _buildTabBar(),
              const SizedBox(height: 32),
              SizedBox(
                height: 420,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoginForm(),
                    _buildRegisterForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.white, size: 48),
        ),
        const SizedBox(height: 16),
        const Text(
          'Reelio',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Short videos that hit different',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        tabs: const [
          Tab(text: 'Sign In'),
          Tab(text: 'Sign Up'),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _loginEmailController,
              hint: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v!.isEmpty ? 'Enter your email' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _loginPasswordController,
              hint: 'Password',
              icon: Icons.lock_outline,
              obscure: _loginObscure,
              suffixIcon: IconButton(
                icon: Icon(
                  _loginObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _loginObscure = !_loginObscure),
              ),
              validator: (v) =>
                  v!.isEmpty ? 'Enter your password' : null,
            ),
            const SizedBox(height: 32),
            _buildPrimaryButton('Sign In', _login),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _registerUsernameController,
              hint: 'Username',
              icon: Icons.person_outline,
              validator: (v) => v!.length < 3 ? 'Min 3 characters' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _registerEmailController,
              hint: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v!.isEmpty ? 'Enter your email' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _registerPasswordController,
              hint: 'Password',
              icon: Icons.lock_outline,
              obscure: _registerObscure,
              suffixIcon: IconButton(
                icon: Icon(
                  _registerObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _registerObscure = !_registerObscure),
              ),
              validator: (v) =>
                  v!.length < 6 ? 'Min 6 characters' : null,
            ),
            const SizedBox(height: 32),
            _buildPrimaryButton('Create Account', _register),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}
