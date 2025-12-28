import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'get_started_screen.dart';
import 'main_shell.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'package:gossip/features/call/presentation/bloc/call_bloc.dart';
import 'package:gossip/features/call/presentation/bloc/call_event.dart';
import '../../../../core/theme/gossip_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    // Use a delay to ensure context is fully ready
    Future.microtask(() {
      if (mounted) {
        context.read<AuthBloc>().add(AuthCheckRequested());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleNavigation(AuthState state) async {
    if (!mounted) return;

    if (state is AuthAuthenticated) {
      // Initialize CallBloc
      context.read<CallBloc>().add(InitializeCallBloc(state.user.id));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else if (state is AuthUnauthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated || state is AuthUnauthenticated) {
          // Delay to show splash animation
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _handleNavigation(state);
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: GossipColors.background,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      GossipColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'GOSSIP.',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Secure. Private. Real-time.',
                  style: TextStyle(
                    color: GossipColors.textDim,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
