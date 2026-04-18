import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import '../utils/page_transitions.dart';
import 'lobby_screen.dart';

class PermissionsOnboardingScreen extends StatefulWidget {
  const PermissionsOnboardingScreen({super.key});

  @override
  State<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState
    extends State<PermissionsOnboardingScreen> with WidgetsBindingObserver {
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When returning to the app from Settings, verify permissions again.
    if (state == AppLifecycleState.resumed) {
      _checkAndProceed(silent: true);
    }
  }

  Future<void> _checkAndProceed({bool silent = false}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent) {
          _showDialog(
            title: "Location Services Disabled",
            content:
                "Please enable Location Services in your device settings to keep your convoy connected.",
            buttonText: "Open Settings",
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
          );
        }
        return;
      }

      // 2. Check permissions
      LocationPermission permission = await Geolocator.checkPermission();

      // If completely denied, ask for permission
      if (permission == LocationPermission.denied) {
        if (silent) return; // Don't trigger system prompts simply because app resumed
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return; // They denied it
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!silent) {
          _showDialog(
            title: "Access Denied Forever",
            content:
                "Location permission has been permanently denied. Please go to App Settings and grant 'Allow all the time' to proceed.",
            buttonText: "Open Settings",
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
          );
        }
        return;
      }

      // 3. We have whileInUse or always. We want Always.
      // Note: On Android 11+, you must request whileInUse first, then always.
      if (permission == LocationPermission.whileInUse) {
        if (Platform.isAndroid) {
          // On Android, we can try requesting again or redirect to settings.
          // Let's ask them explicitly.
          if (!silent) {
            _showDialog(
              title: "Upgrade to 'Allow all the time'",
              content:
                  "For your safety, the app needs to track your location even when running in the background. Please select 'Allow all the time'.",
              buttonText: "Update Permission",
              onPressed: () async {
                Navigator.pop(context);
                final upgradePerm = await Geolocator.requestPermission();
                if (upgradePerm != LocationPermission.always) {
                  // Fallback to app settings if it fails
                  await Geolocator.openAppSettings();
                } else {
                  _goToLobby();
                }
              },
            );
          }
          return;
        } else if (Platform.isIOS) {
          // On iOS, requestPermission() might handle this differently, but we can also open app settings.
          if (!silent) {
            _showDialog(
              title: "Upgrade to 'Always Allow'",
              content:
                  "For your safety, the app needs to track your location even when running in the background. Please select 'Always' in settings.",
              buttonText: "Open Settings",
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openAppSettings();
              },
            );
          }
          return;
        }
      }

      // 4. If we have Always permission, we are good to go!
      if (permission == LocationPermission.always) {
        _goToLobby();
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _goToLobby() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        ScaleFadeRoute(page: const LobbyScreen()),
      );
    }
  }

  void _showDialog({
    required String title,
    required String content,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(title,
            style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        content: Text(content,
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary), fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary))),
          ),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Visual Icon Illustration
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: kPrimaryLight.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.security_rounded, // Shield/Location mix could be used
                    size: 70,
                    color: kPrimary,
                  ),
                ),
              ),
              SizedBox(height: 40),
              // Title
              Text(
                "Background Safety",
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(fontSize: 28),
              ),
              SizedBox(height: 16),
              // Description
              Text(
                "To keep your convoy safe and coordinated, we need access to your location even when your phone is locked or you're using other apps.\n\n"
                "Please ensure Location Services are ON, and select \"Allow all the time\" when prompted.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  height: 1.5,
                  color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
                ),
              ),
              const Spacer(),
              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : () => _checkAndProceed(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _isChecking
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Grant Permission",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
