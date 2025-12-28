import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_state.dart';
import '../pages/incoming_call_screen.dart';
import '../pages/active_call_screen.dart';

class CallOverlay extends StatelessWidget {
  final Widget child;

  const CallOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallBloc, CallState>(
      builder: (context, state) {
        return Stack(
          children: [
            child,
            if (state is CallRinging) IncomingCallScreen(state: state),
            if (state is CallActive) ActiveCallScreen(state: state),
            if (state is CallError)
              Material(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
