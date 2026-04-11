import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lobby_screen.dart';
import 'onboarding_screen.dart';
import 'permissions_onboarding_screen.dart';
import '../auth_service.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;
  double _scale = 0.8;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _opacity = 1.0;
      _scale = 1.0;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _scale = 3.0;
      _opacity = 0.0;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    // --- NEW ROUTING LOGIC ---
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // Ensure user is signed in anonymously on every startup to prevent RTDB permission issues
    await AuthService().signInAnonymously();
    
    // Check Location Permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    bool hasPermissions = serviceEnabled && permission == LocationPermission.always;

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            if (!hasSeenOnboarding) return const OnboardingScreen();
            if (!hasPermissions) return const PermissionsOnboardingScreen();
            return const LobbyScreen();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          opacity: _opacity,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
            scale: _scale,
            child: Image.asset(
              'assets/images/logo.png',
              width: 220,
              height: 220,
            ),
          ),
        ),
      ),
    );
  }
}