import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../providers/trip_provider.dart';
import '../utils/page_transitions.dart';
import 'map_screen.dart';

class ShareCodeScreen extends StatelessWidget {
  const ShareCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final tripCode = provider.tripCode ?? "ERROR";
    final tripModel = provider.tripModel;

    // Duration label
    final durationLabel = tripModel?.tripDuration.label ?? 'Unknown';
    final durationHours = tripModel?.tripDuration.hours ?? 0;

    // Expiry countdown
    String expiryText = '';
    if (tripModel != null) {
      final remaining = tripModel.remainingTime;
      if (remaining.inHours > 0) {
        expiryText = 'Expires in ${remaining.inHours}h ${remaining.inMinutes % 60}m';
      } else if (remaining.inMinutes > 0) {
        expiryText = 'Expires in ${remaining.inMinutes}m';
      } else {
        expiryText = 'Expired';
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              Icon(Icons.check_circle_outline, size: 80, color: kPrimary),
              SizedBox(height: 24),
              Text(
                "Convoy Created!",
                textAlign: TextAlign.center,
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary), fontSize: 32, fontFamily: 'Thicccboi', fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 16),
              Text(
                "Share this code with your friends so they can join your trip.",
                textAlign: TextAlign.center,
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary), fontSize: 16),
              ),
              SizedBox(height: 48),

              // THE CODE DISPLAY
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kPrimary, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      tripCode,
                      style: TextStyle(
                        fontSize: 48,
                        fontFamily: 'Thicccboi',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                        color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                      ),
                    ),
                    SizedBox(height: 12),

                    // Duration & Expiry info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tripModel?.tripDuration.icon ?? Icons.timer, size: 16, color: kPrimary),
                        SizedBox(width: 6),
                        Text(
                          '$durationLabel ($durationHours h)',
                          style: TextStyle(color: kPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.schedule, size: 16, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary)),
                        SizedBox(width: 4),
                        Text(
                          expiryText,
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary), fontSize: 14),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // COPY & SHARE Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: tripCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Code copied to clipboard!")),
                            );
                          },
                          icon: Icon(Icons.copy, color: kAccentBlue, size: 20),
                          label: Text("COPY", style: TextStyle(color: kAccentBlue, fontSize: 14)),
                        ),
                        SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () {
                            SharePlus.instance.share(
                              ShareParams(
                                text: '🚗 Join my convoy on NoOneLeftBehind!\n\nTrip Code: $tripCode\n\nOpen the app and enter this code to join.',
                              ),
                            );
                          },
                          icon: Icon(Icons.share, color: kPrimary, size: 20),
                          label: Text("SHARE", style: TextStyle(color: kPrimary, fontSize: 14)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // LAUNCH MAP BUTTON
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    ScaleFadeRoute(page: const MapScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: Text("Launch Radar Map", style: TextStyle(fontSize: 18, fontFamily: 'Thicccboi', fontWeight: FontWeight.w700)),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}