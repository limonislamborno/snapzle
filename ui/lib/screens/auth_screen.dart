import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gaming_button.dart';
import '../widgets/glass_card.dart';

enum AuthMode { welcome, login, register, verifyOtp, forgotPassword, resetPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.welcome;
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Login failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    if (username.length < 3) {
      setState(() => _errorMessage = 'Username must be at least 3 characters.');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Check if username is already taken
      final usernameTaken = await SupabaseService.isUsernameTaken(username);
      if (usernameTaken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        await _showUsernameTakenDialog(username);
        return;
      }

      // 2. Perform Supabase Sign Up
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      // 3. Supabase anti-enumeration detection:
      // When email confirmation is active and an email already exists, identities is returned empty
      if (res.user != null && res.user!.identities != null && res.user!.identities!.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        await _showEmailAlreadyRegisteredDialog(email);
        return;
      }

      if (res.session == null) {
        // Confirmation email with OTP required
        setState(() => _mode = AuthMode.verifyOtp);
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') ||
          msg.contains('already exists') ||
          msg.contains('user already registered') ||
          e.statusCode == '422' ||
          e.code == 'user_already_exists') {
        if (mounted) {
          setState(() => _isLoading = false);
          await _showEmailAlreadyRegisteredDialog(email);
        }
        return;
      } else if (msg.contains('username') &&
          (msg.contains('taken') || msg.contains('unique') || msg.contains('exists') || msg.contains('already'))) {
        if (mounted) {
          setState(() => _isLoading = false);
          await _showUsernameTakenDialog(username);
        }
        return;
      }
      setState(() => _errorMessage = e.message);
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('already registered') || str.contains('already exists')) {
        if (mounted) {
          setState(() => _isLoading = false);
          await _showEmailAlreadyRegisteredDialog(email);
        }
        return;
      }
      setState(() => _errorMessage = 'Registration failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEmailAlreadyRegisteredDialog(String email) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder, width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.mailWarning, color: AppColors.primaryOrange, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Already Registered',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'An account is already registered with this email:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                email,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'If you forgot your password, please use the Forgot Password option to reset it and access your account.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _mode = AuthMode.login;
                _emailController.text = email;
                _errorMessage = null;
              });
            },
            child: const Text(
              'Sign In',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _mode = AuthMode.forgotPassword;
                _emailController.text = email;
                _errorMessage = null;
              });
            },
            child: const Text(
              'Forgot Password',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUsernameTakenDialog(String username) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder, width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.userX, color: AppColors.primaryOrange, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Username Taken',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The gamer tag "$username" already exists and is in use by another player.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please choose a different unique username to create your account.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _usernameController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _usernameController.text.length,
              );
            },
            child: const Text(
              'Choose Another',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVerifyOtp() async {
    final email = _emailController.text.trim();
    final token = _otpController.text.trim();

    if (token.length < 6 || token.length > 8) {
      setState(() => _errorMessage = 'Please enter the verification code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Verification failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendResetOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your registered email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _supabase.auth.resetPasswordForEmail(email);
      setState(() {
        _mode = AuthMode.resetPassword;
        _errorMessage = null;
        _otpController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent to $email'),
            backgroundColor: AppColors.accentCyan,
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to send reset code: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    final token = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (token.isEmpty || newPassword.isEmpty) {
      setState(() => _errorMessage = 'Please enter both the OTP code and new password.');
      return;
    }

    if (newPassword.length < 6) {
      setState(() => _errorMessage = 'New password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Verify OTP with recovery type
      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );

      // Update password
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Password reset successful! Logging you in...'),
            backgroundColor: AppColors.accentEmerald,
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Reset failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Icon & Title
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            blurRadius: 20,
                          )
                        ],
                      ),
                      child: const Icon(LucideIcons.gamepad2, size: 44, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SNAPZLE',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your Photos. Your Games. Your Challenge.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Auth Form Card
                    GlassCard(
                      isStrong: true,
                      padding: const EdgeInsets.all(22),
                      child: _buildFormContent(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }

  Widget _buildFormContent() {
    switch (_mode) {
      case AuthMode.welcome:
        return _buildWelcomeView();
      case AuthMode.login:
        return _buildLoginView();
      case AuthMode.register:
        return _buildRegisterView();
      case AuthMode.verifyOtp:
        return _buildVerifyOtpView();
      case AuthMode.forgotPassword:
        return _buildForgotPasswordView();
      case AuthMode.resetPassword:
        return _buildResetPasswordView();
    }
  }

  Widget _buildWelcomeView() {
    return Column(
      children: [
        const Text(
          'Play with your private memories',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Upload 5–10 photos and compete on global leaderboards. Your photos always stay 100% private.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        GamingButton(
          label: 'Create Account',
          icon: LucideIcons.userPlus,
          onPressed: () => setState(() {
            _mode = AuthMode.register;
            _errorMessage = null;
          }),
        ),
        const SizedBox(height: 12),
        GamingButton(
          label: 'Sign In',
          icon: LucideIcons.logIn,
          color: AppColors.surfaceMuted,
          textColor: AppColors.primaryOrange,
          border: Border.all(color: AppColors.glassBorder, width: 1.2),
          onPressed: () => setState(() {
            _mode = AuthMode.login;
            _errorMessage = null;
          }),
        ),
      ],
    );
  }

  Widget _buildLoginView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sign In',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildTextField(_emailController, 'Email', LucideIcons.mail, TextInputType.emailAddress),
        const SizedBox(height: 12),
        _buildTextField(_passwordController, 'Password', LucideIcons.lock, TextInputType.text, obscure: true),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() {
              _mode = AuthMode.forgotPassword;
              _errorMessage = null;
            }),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (_errorMessage != null) _buildError(),
        const SizedBox(height: 12),
        GamingButton(
          label: 'Sign In',
          isLoading: _isLoading,
          onPressed: _handleLogin,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _mode = AuthMode.register;
              _errorMessage = null;
            }),
            child: const Text(
              "Don't have an account? Create one",
              style: TextStyle(color: AppColors.primaryOrange, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _mode = AuthMode.welcome),
            child: const Text(
              'Back',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Account',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildTextField(_usernameController, 'Username', LucideIcons.user, TextInputType.text),
        const SizedBox(height: 12),
        _buildTextField(_emailController, 'Email', LucideIcons.mail, TextInputType.emailAddress),
        const SizedBox(height: 12),
        _buildTextField(_passwordController, 'Password (min 6 chars)', LucideIcons.lock, TextInputType.text, obscure: true),
        if (_errorMessage != null) _buildError(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accentEmerald.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: const [
              Icon(LucideIcons.shieldCheck, color: AppColors.accentEmerald, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Photos stay 100% private in encrypted storage.',
                  style: TextStyle(color: AppColors.accentEmerald, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GamingButton(
          label: 'Create Account',
          isLoading: _isLoading,
          onPressed: _handleRegister,
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _mode = AuthMode.login;
              _errorMessage = null;
            }),
            child: const Text(
              'Already have an account? Sign In',
              style: TextStyle(color: AppColors.primaryOrange, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyOtpView() {
    return Column(
      children: [
        const Icon(LucideIcons.mailCheck, size: 48, color: AppColors.accentCyan),
        const SizedBox(height: 12),
        const Text(
          'Verify Your Email',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the code sent to ${_emailController.text}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 8,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.surfaceMuted,
            hintText: '12345678',
            hintStyle: const TextStyle(color: AppColors.textMuted, letterSpacing: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
          ),
        ),
        if (_errorMessage != null) _buildError(),
        const SizedBox(height: 20),
        GamingButton(
          label: 'Confirm & Play',
          isLoading: _isLoading,
          onPressed: _handleVerifyOtp,
        ),
      ],
    );
  }

  Widget _buildForgotPasswordView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Forgot Password',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your registered email address to receive a password reset code.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildTextField(_emailController, 'Email', LucideIcons.mail, TextInputType.emailAddress),
        if (_errorMessage != null) _buildError(),
        const SizedBox(height: 20),
        GamingButton(
          label: 'Send Reset Code',
          icon: LucideIcons.send,
          isLoading: _isLoading,
          onPressed: _handleSendResetOtp,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _mode = AuthMode.login;
              _errorMessage = null;
            }),
            child: const Text(
              'Back to Sign In',
              style: TextStyle(color: AppColors.primaryOrange, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetPasswordView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.keyRound, color: AppColors.accentCyan, size: 22),
            SizedBox(width: 8),
            Text(
              'Set New Password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter the code sent to your email and your new password.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 8,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, letterSpacing: 3, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.surfaceMuted,
            hintText: 'Enter 6 or 8-digit OTP',
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              letterSpacing: 1,
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _newPasswordController,
          'New Password (min 6 chars)',
          LucideIcons.lock,
          TextInputType.text,
          obscure: true,
        ),
        if (_errorMessage != null) _buildError(),
        const SizedBox(height: 20),
        GamingButton(
          label: 'Save & Sign In',
          icon: LucideIcons.shieldCheck,
          isLoading: _isLoading,
          onPressed: _handleResetPassword,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _mode = AuthMode.login;
              _errorMessage = null;
            }),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    TextInputType type, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }
}
