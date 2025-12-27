import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/gossip_colors.dart';

class PinScreen extends StatefulWidget {
  final bool isSettingUp;
  final Future<bool> Function(BuildContext, String) onComplete;

  const PinScreen({
    super.key,
    this.isSettingUp = false,
    required this.onComplete,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  final int _pinLength = 4;
  bool _hasError = false;

  void _onNumberTap(String number) {
    if (_hasError) {
      setState(() {
        _hasError = false;
        _pin = '';
      });
    }

    if (_pin.length < _pinLength) {
      setState(() {
        _pin += number;
      });
      if (_pin.length == _pinLength) {
        // Give a small delay for the last circle to fill
        Future.delayed(const Duration(milliseconds: 100), () async {
          if (!mounted) return;
          final success = await widget.onComplete(context, _pin);
          if (!mounted) return;
          if (!success) {
            setError();
          }
        });
      }
    }
  }

  void _onBackspace() {
    if (_hasError) {
      setState(() {
        _hasError = false;
        _pin = '';
      });
      return;
    }
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void setError() {
    setState(() {
      _hasError = true;
    });
    // Reset after animation
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _pin = '';
          _hasError = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GossipColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.lock_outline,
                    size: 64, color: GossipColors.primary)
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1)),
            const SizedBox(height: 24),
            Text(
              widget.isSettingUp ? 'Set App Pin' : 'Enter Pin',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 12),
            const Text(
              'For your security, please enter your pin',
              style: TextStyle(color: GossipColors.textDim),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pinLength,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pin.length
                        ? GossipColors.primary
                        : Colors.white24,
                    boxShadow: index < _pin.length
                        ? [
                            BoxShadow(
                                color:
                                    GossipColors.primary.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2)
                          ]
                        : [],
                  ),
                ),
              ),
            )
                .animate(target: _hasError ? 1 : 0)
                .shake(hz: 8, curve: Curves.easeInOutCubic, duration: 400.ms),
            if (_hasError)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Incorrect PIN. Try again.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ).animate().fadeIn(),
            const Spacer(),
            _buildKeypad()
                .animate()
                .fadeIn(delay: 800.ms, duration: 600.ms)
                .slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['1', '2', '3']
                .map(
                    (n) => _KeypadButton(text: n, onTap: () => _onNumberTap(n)))
                .toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['4', '5', '6']
                .map(
                    (n) => _KeypadButton(text: n, onTap: () => _onNumberTap(n)))
                .toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['7', '8', '9']
                .map(
                    (n) => _KeypadButton(text: n, onTap: () => _onNumberTap(n)))
                .toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 64),
              _KeypadButton(text: '0', onTap: () => _onNumberTap('0')),
              IconButton(
                icon: const Icon(Icons.backspace_outlined, color: Colors.white),
                onPressed: _onBackspace,
                iconSize: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _KeypadButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
