import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/trip_provider.dart';
import '../services/trip_service.dart';
import '../auth_service.dart';
import '../utils/page_transitions.dart';
import 'host_setup_screen.dart';
import 'join_setup_screen.dart';
import 'map_screen.dart';
import 'history_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TripService _tripService = TripService();
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _tryReconnect();
  }

  /// Checks if there's a saved trip session and reconnects if valid.
  Future<void> _tryReconnect() async {
    try {
      final provider = context.read<TripProvider>();
      final restored = await provider
          .tryRestoreSession()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (restored && mounted) {
        Navigator.pushReplacement(
          context,
          ScaleFadeRoute(page: const MapScreen()),
        );
        return;
      }
    } catch (e) {
      debugPrint('Session restore failed: $e');
    }
    if (mounted) setState(() => _checkingSession = false);
  }

  Future<void> _onJoinSubmit() async {
    final code = _pinController.text.trim().toUpperCase();
    if (code.length < kTripCodeLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 6-character code")),
      );
      return;
    }

    try {
      // Ensure we are signed in before hitting Firebase
      await AuthService().signInAnonymously();

      // Quick validation — TripService.joinTrip will do full validation,
      // but we can give early feedback here.
      final isActive = await _tripService.isTripActive(code);
      if (!isActive) throw 'Trip not found or has expired.';

      if (mounted) {
        Navigator.push(
          context,
          FadeSlideRoute(page: JoinSetupScreen(tripCode: code)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kAlertRed),
      );
    }
  }

  void _onCreatePressed() {
    Navigator.push(
      context,
      FadeSlideRoute(page: const HostSetupScreen()),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: kBackground,
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    final theme = Theme.of(context);

    // Pinput theme — white boxes for the blue background
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: const TextStyle(
        fontFamily: 'Thicccboi',
        fontSize: 24,
        color: kAccentBlue,
        fontWeight: FontWeight.w900,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Scaffold(
      backgroundColor: kBackground,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final topHeight = constraints.maxHeight * 0.60;
          final bottomHeight = constraints.maxHeight * 0.40;

          return Stack(
            children: [
              // ── BOTTOM SECTION (40%) ──
              Positioned(
                top: topHeight,
                left: 0,
                right: 0,
                height: bottomHeight,
                child: Container(
                  color: kBackground,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          Text(
                            "Don't have a code? Create Convoy!",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: kTextPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "That's ok, we'll walk you through setup.",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: kTextSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _onCreatePressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary, // App's CTA Green
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                'Get started',
                                style: theme.textTheme.displayMedium?.copyWith(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
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

              // ── TOP SECTION (60%) ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topHeight,
                child: Container(
                  decoration: const BoxDecoration(
                    color: kAccentBlue,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.history, color: Colors.white),
                            onPressed: () => Navigator.push(context, FadeSlideRoute(page: const HistoryScreen())),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 52),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Text(
                            'Joining a Convoy? Enter your\ninvite code',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Pinput(
                            controller: _pinController,
                            length: 6,
                            defaultPinTheme: defaultPinTheme,
                            focusedPinTheme: defaultPinTheme.copyWith(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.characters,
                            separatorBuilder: (index) {
                              if (index == 2) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    "-",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox(width: 8);
                            },
                            onCompleted: (pin) => _onJoinSubmit(),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Tip: You may need to ask the Convoy creator for\nthe code.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _onJoinSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                'Submit',
                                style: theme.textTheme.displayMedium?.copyWith(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24), // Space before bottom curve
                        ],
                      ),
                    ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── OR DIVIDER BADGE ──
              Positioned(
                top: topHeight - 24, // Half of badge height (48) so it overlaps equally
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kSurface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'OR',
                      style: TextStyle(
                        fontFamily: 'Thicccboi',
                        color: kTextSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}