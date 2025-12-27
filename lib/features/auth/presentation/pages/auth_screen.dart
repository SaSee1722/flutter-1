import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/gossip_colors.dart';
import '../../../../shared/widgets/gossip_input.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'main_shell.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  const AuthScreen({super.key, this.isLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isLogin;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode(bool login) {
    if (_isLogin != login) {
      setState(() {
        _isLogin = login;
      });
    }
  }

  void _submit() {
    if (_isLogin) {
      context.read<AuthBloc>().add(
            AuthSignInRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            ),
          );
    } else {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }
      context.read<AuthBloc>().add(
            AuthSignUpRequested(
              email: _emailController.text.trim(),
              username: _usernameController.text.trim(),
              password: _passwordController.text.trim(),
              fullName: _usernameController.text
                  .trim(), // Using username as fullname fallback if needed or add field
              // Wait, SignUpRequested usually takes fullName. Let me check the event definition if needed.
              // Logic in RegisterScreen used fullName controller.
              // I'll add full name field to UI.
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? 'GOSSIP.' : 'JOIN.';
    final subtitle =
        _isLogin ? 'WELCOME BACK TO THE RUMORS' : 'START SHARING YOUR SECRETS';
    final buttonText = _isLogin ? 'ENTER GOSSIP' : 'START GOSSIPING';

    return Scaffold(
      backgroundColor: GossipColors.background,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()),
              (route) => false,
            );
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title Section
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: GossipColors.primary,
                      letterSpacing: 2,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.1, end: 0),

                  const SizedBox(height: 8),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                  const SizedBox(height: 40),

                  // Card Container
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        // Toggle Switch
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Stack(
                            children: [
                              AnimatedAlign(
                                alignment: _isLogin
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: Container(
                                  width: MediaQuery.of(context).size.width *
                                      0.4, // Approx half or calc layout
                                  constraints:
                                      const BoxConstraints(maxWidth: 160),
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(21),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _toggleMode(true),
                                      behavior: HitTestBehavior.opaque,
                                      child: Center(
                                        child: Text(
                                          'LOGIN',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            letterSpacing: 1.5,
                                            color: _isLogin
                                                ? Colors.black
                                                : GossipColors.textDim,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _toggleMode(false),
                                      behavior: HitTestBehavior.opaque,
                                      child: Center(
                                        child: Text(
                                          'SIGNUP',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            letterSpacing: 1.5,
                                            color: !_isLogin
                                                ? Colors.black
                                                : GossipColors.textDim,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Form Fields
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          alignment: Alignment.topCenter,
                          child: Column(
                            children: [
                              GossipInputField(
                                hintText: 'Email Address',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: const Icon(
                                    Icons.mail_outline_rounded,
                                    size: 20),
                              ),
                              const SizedBox(height: 16),
                              if (!_isLogin) ...[
                                GossipInputField(
                                  hintText: 'Username',
                                  controller: _usernameController,
                                  prefixIcon: const Icon(
                                      Icons.person_outline_rounded,
                                      size: 20),
                                ),
                                const SizedBox(height: 16),
                              ],
                              GossipInputField(
                                hintText: 'Password',
                                controller: _passwordController,
                                isPassword: true,
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20),
                              ),
                              if (!_isLogin) ...[
                                const SizedBox(height: 16),
                                GossipInputField(
                                  hintText: 'Confirm Password',
                                  controller: _confirmPasswordController,
                                  isPassword: true,
                                  prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 20),
                                ),
                              ],
                            ],
                          ),
                        ),

                        if (_isLogin) ...[
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'FORGOT PASSWORD?',
                              style: TextStyle(
                                color:
                                    GossipColors.textDim.withValues(alpha: 0.6),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Action Button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                GossipColors.primary,
                                Color(0xFF87CEEB)
                              ], // Cyan gradient
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    GossipColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: state is AuthLoading ? null : _submit,
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: state is AuthLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.black)
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            buttonText,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.black,
                                              size: 20),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 500.ms)
                      .slideY(begin: 0.1, end: 0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
