import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

// ─── Gateway Setup Page (URL entry) ─────────────────────────────────────────

class GatewaySetupPage extends StatefulWidget {
  final Function(String baseUrl) onGatewaySet;

  const GatewaySetupPage({super.key, required this.onGatewaySet});

  @override
  State<GatewaySetupPage> createState() => _GatewaySetupPageState();
}

class _GatewaySetupPageState extends State<GatewaySetupPage>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Gateway URL is required');
      return;
    }

    String url = raw;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() => _isLoading = false);
    widget.onGatewaySet(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 3),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF222222)),
                    ),
                    child: const Icon(
                      Icons.hub_outlined,
                      color: Color(0xFFCCCCCC),
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Connect to\nGateway',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF5F5F5),
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Enter your server URL to continue',
                    style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
                  ),
                  const Spacer(flex: 2),
                  _GatewayTextField(
                    controller: _urlController,
                    hint: 'https://your-worker.workers.dev',
                    icon: Icons.dns_outlined,
                    error: _error,
                    onSubmitted: (_) => _proceed(),
                    keyboardType: TextInputType.url,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF4444),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _PrimaryButton(
                    label: 'Proceed',
                    isLoading: _isLoading,
                    onTap: _proceed,
                  ),
                  const Spacer(flex: 4),
                  Center(
                    child: Text(
                      'POWERED BY REDFOX PACK',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.12),
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Gateway Login Page ──────────────────────────────────────────────────────

class GatewayLoginPage extends StatefulWidget {
  final String baseUrl;
  final String ownerName;
  final Function(Map<String, dynamic> user, String baseUrl) onLoginSuccess;
  final VoidCallback onBack;

  const GatewayLoginPage({
    super.key,
    required this.baseUrl,
    required this.ownerName,
    required this.onLoginSuccess,
    required this.onBack,
  });

  @override
  State<GatewayLoginPage> createState() => _GatewayLoginPageState();
}

class _GatewayLoginPageState extends State<GatewayLoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  bool _isSignup = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    if (_isSignup && _usernameController.text.trim().isEmpty) {
      setState(() => _error = 'Username is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final endpoint = _isSignup ? '/api/register' : '/api/login';
      final body = _isSignup
          ? {
              'username': _usernameController.text.trim(),
              'email': email,
              'password': password,
            }
          : {'email': email, 'password': password};

      final client = HttpClient();
      final uri = Uri.parse('${widget.baseUrl}$endpoint');
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.write(jsonEncode(body));
      final resp = await req.close();
      final respStr = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(respStr) as Map<String, dynamic>;
      client.close();

      if (!mounted) return;

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (data['success'] == true) {
          if (_isSignup) {
            setState(() {
              _isSignup = false;
              _isLoading = false;
              _error = null;
            });
            _showSnack('Account created! Please sign in.');
            return;
          } else {
            widget.onLoginSuccess(
              data['user'] as Map<String, dynamic>,
              widget.baseUrl,
            );
            return;
          }
        }
      }
      setState(() => _error = data['error']?.toString() ?? 'Something went wrong');
    } on SocketException {
      if (mounted) setState(() => _error = 'Connection failed. Check the URL.');
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isSignup = !_isSignup;
      _error = null;
    });
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  // Back button
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F0F),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E1E1E)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF777777),
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Welcome to',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.ownerName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF0F0F0),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignup ? 'Create your account' : 'Sign in to continue',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4A4A4A),
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (_isSignup) ...[
                    _GatewayTextField(
                      controller: _usernameController,
                      hint: 'Username',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                  ],

                  _GatewayTextField(
                    controller: _emailController,
                    hint: 'Email address',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _GatewayTextField(
                    controller: _passwordController,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _submit(),
                    suffix: GestureDetector(
                      onTap: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF3A3A3A),
                        size: 18,
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF120000),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2E0000)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFCC3333),
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFCC3333),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  _PrimaryButton(
                    label: _isSignup ? 'Create Account' : 'Sign In',
                    isLoading: _isLoading,
                    onTap: _submit,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: _toggleMode,
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13),
                          children: [
                            TextSpan(
                              text: _isSignup
                                  ? 'Already have an account?  '
                                  : "Don't have an account?  ",
                              style: const TextStyle(color: Color(0xFF4A4A4A)),
                            ),
                            TextSpan(
                              text: _isSignup ? 'Sign In' : 'Sign Up',
                              style: const TextStyle(
                                color: Color(0xFFCCCCCC),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _GatewayTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? error;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Function(String)? onSubmitted;
  final Widget? suffix;

  const _GatewayTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.error,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error != null
              ? const Color(0xFF2E0000)
              : const Color(0xFF1A1A1A),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          color: Color(0xFFDDDDDD),
          fontSize: 14,
          letterSpacing: 0.1,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF303030), fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF333333), size: 18),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: suffix,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: isLoading ? const Color(0xFF141414) : const Color(0xFFEAEAEA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF444444),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
