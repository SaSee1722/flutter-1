import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/gossip_button.dart';
import '../../../../shared/widgets/gossip_input.dart';
import '../../../../core/theme/gossip_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'main_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Account',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),
            const SizedBox(height: 8),
            const Text(
              'Join the most private gossip network',
              style: TextStyle(color: GossipColors.textDim),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 600.ms)
                .slideX(begin: -0.2, end: 0),
            const SizedBox(height: 48),
            GlassCard(
              child: Column(
                children: [
                  GossipInputField(
                    hintText: 'Full Name',
                    controller: _fullNameController,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  const SizedBox(height: 16),
                  GossipInputField(
                    hintText: 'Username',
                    controller: _usernameController,
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                  const SizedBox(height: 16),
                  GossipInputField(
                    hintText: 'Email Address',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                  GossipInputField(
                    hintText: 'Password',
                    controller: _passwordController,
                    isPassword: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
            const SizedBox(height: 32),
            BlocConsumer<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthAuthenticated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Account created successfully!')),
                  );

                  if (!mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  );
                } else if (state is AuthFailure) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message)),
                  );
                }
              },
              builder: (context, state) {
                return GossipButton(
                  text: 'Register',
                  isLoading: state is AuthLoading,
                  onPressed: () {
                    context.read<AuthBloc>().add(
                          AuthSignUpRequested(
                            email: _emailController.text.trim(),
                            password: _passwordController.text.trim(),
                            username: _usernameController.text.trim(),
                            fullName: _fullNameController.text.trim(),
                          ),
                        );
                  },
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0);
              },
            ),
          ],
        ),
      ),
    );
  }
}
