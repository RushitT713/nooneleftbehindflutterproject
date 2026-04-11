import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/trip_provider.dart';
import '../services/location_service.dart';
import '../utils/page_transitions.dart';
import '../screens/splash_screen.dart';

class TripSummaryDialog extends StatelessWidget {
  final Map<dynamic, dynamic>? meta;
  final int memberCount;

  const TripSummaryDialog({
    super.key,
    required this.meta,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = meta?['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final endedAt = meta?['endedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final duration = Duration(milliseconds: endedAt - createdAt);

    String durationText = '';
    if (duration.inHours > 0) {
      durationText = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      durationText = '${duration.inMinutes}m';
    }

    if (durationText == '0m') {
      durationText = '< 1m';
    }

    final destData = meta?['destination'] as Map<dynamic, dynamic>?;
    final destName = destData?['name']?.toString() ?? 'No destination';

    return PopScope(
      canPop: false, // Prevent dismissing by tapping outside or back button
      child: Dialog(
        backgroundColor: kBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Icon(Icons.check_circle_outline, color: kSuccessGreen, size: 64),
              const SizedBox(height: 16),
              Text(
                'Trip Ended',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The host has concluded this convoy.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: durationText,
                  ),
                  _StatItem(
                    icon: Icons.group_outlined,
                    label: 'Convoy',
                    value: '$memberCount',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Destination
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kSurfaceBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_rounded, color: kPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Final Destination',
                            style: TextStyle(
                              color: kTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            destName,
                            style: const TextStyle(
                              color: kTextPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Done Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    // Cleanup and go home
                    final provider = context.read<TripProvider>();
                    await LocationService.stopTracking();
                    await provider.clearTrip();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        FadeSlideRoute(page: const SplashScreen()),
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: kTextSecondary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFamily: 'Thicccboi',
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: kTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
