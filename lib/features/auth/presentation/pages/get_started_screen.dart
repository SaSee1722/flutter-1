import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_screen.dart';
import '../../../../core/theme/gossip_colors.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Explicit black as per design
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(),
              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: GossipColors.primary.withValues(alpha: 0.1),
                      width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: GossipColors.primary.withValues(alpha: 0.1),
                      blurRadius: 40,
                      spreadRadius: 0,
                    )
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: GossipColors.primary,
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 24),

              // Title
              const Text(
                'GOSSIP.',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: GossipColors.primary,
                  letterSpacing: 1.5,
                  height: 1,
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 12),

              // Subtitle
              Text(
                'PRIVATE CONVERSATIONS\nREFINED FOR THE ELITE.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 2,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 200.ms),

              const Spacer(),

              // Feature Cards
              _buildFeatureCard(
                icon: Icons.bolt_rounded,
                title: 'INSTANT GOSSIP',
                subtitle: 'REAL-TIME RUMORS THAT TRAVEL FAST.',
                delay: 400,
              ),
              const SizedBox(height: 16),
              _buildFeatureCard(
                icon: Icons.shield_outlined,
                title: 'GHOST SECURITY',
                subtitle: 'END-TO-END ENCRYPTION FOR EVERY SECRET.',
                delay: 600,
              ),

              const Spacer(flex: 2),

              // Get Started Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [GossipColors.primary, Color(0xFF87CEEB)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: GossipColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AuthScreen(isLogin: false)),
                      );
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'GET STARTED',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded,
                              color: Colors.black, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5, end: 0),

              const SizedBox(height: 24),

              // Footer
              Text(
                'BY ENTERING, YOU ACCEPT OUR GHOST PROTOCOLS',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.3),
                  letterSpacing: 1.5,
                ),
              ).animate().fadeIn(delay: 1000.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      {required IconData icon,
      required String title,
      required String subtitle,
      required int delay}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: Icon(icon, color: GossipColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.1, end: 0);
  }
}
