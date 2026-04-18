import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import '../models/sos_model.dart';
import '../providers/trip_provider.dart';
import '../services/sos_service.dart';

/// SOS Emergency Center — functional screen with Firebase RTDB.
class SosScreen extends StatefulWidget {
  final String tripCode;

  /// If provided, an auto-triggered reason (e.g. from shake detection).
  final SosReason? autoReason;

  const SosScreen({super.key, required this.tripCode, this.autoReason});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  final SosService _sosService = SosService();
  final TextEditingController _noteController = TextEditingController();

  SosReason? _selectedReason;
  bool _isSending = false;
  String? _activeSosId;

  // Active SOS listener
  SosModel? _activeSos;
  StreamSubscription? _sosSubscription;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Start listening for any existing active SOS
    _startListening();

    // If auto-triggered (shake/impact), pre-select the reason
    if (widget.autoReason != null) {
      _selectedReason = widget.autoReason;
    }
  }

  void _startListening() {
    _sosSubscription = _sosService
        .listenToActiveSos(widget.tripCode)
        .listen((sos) {
      if (!mounted) return;
      setState(() => _activeSos = sos);
    });
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    _pulseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _onSendSos() async {
    if (_selectedReason == null) return;
    setState(() => _isSending = true);

    final provider = context.read<TripProvider>();
    final userId = provider.userId ?? '';
    final nickname = provider.nickname ?? 'Unknown';

    // Get current location
    double lat = 0.0;
    double lng = 0.0;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      lat = position.latitude;
      lng = position.longitude;
    } catch (_) {
      // Use 0,0 if location unavailable
    }

    try {
      final sosId = await _sosService.triggerSos(
        tripCode: widget.tripCode,
        userId: userId,
        userName: nickname,
        reason: _selectedReason!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        lat: lat,
        lng: lng,
      );
      if (mounted) {
        setState(() {
          _activeSosId = sosId;
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SOS: $e'),
            backgroundColor: kAlertRed,
          ),
        );
      }
    }
  }

  Future<void> _onResolveSos() async {
    final sosId = _activeSos?.sosId ?? _activeSosId;
    if (sosId == null) return;

    await _sosService.resolveSos(
      tripCode: widget.tripCode,
      sosId: sosId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS resolved. Convoy notified.'),
          backgroundColor: kSuccessGreen,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _onAcknowledgeSos() async {
    if (_activeSos == null) return;
    final provider = context.read<TripProvider>();
    final userId = provider.userId ?? '';

    await _sosService.acknowledgeSos(
      tripCode: widget.tripCode,
      sosId: _activeSos!.sosId,
      userId: userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final myUserId = provider.userId ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SOS Center',
          style: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w900,
            color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
                fontFamily: 'Thicccboi',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _isSending
          ? _buildSendingState()
          : _activeSos != null
              ? _buildActiveSosState(myUserId)
              : _buildMainContent(),
    );
  }

  // ─── Sending State ─────────────────────────

  Widget _buildSendingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + _pulseController.value * 0.15,
                child: child,
              );
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: kAlertRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sos, size: 50, color: kAlertRed),
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Sending SOS Alert...',
            style: TextStyle(
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Your convoy will be notified immediately.\nYour location is being shared.',
            textAlign: TextAlign.center,
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary), fontSize: 15),
          ),
          SizedBox(height: 32),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: kAlertRed,
              strokeWidth: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Active SOS State (someone already triggered) ────

  Widget _buildActiveSosState(String myUserId) {
    final sos = _activeSos!;
    final isMyAlert = sos.triggeredBy == myUserId;
    final hasAcknowledged = sos.isAcknowledgedBy(myUserId);
    final ackCount = sos.acknowledgedBy.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(height: 32),

          // Pulsing SOS icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + _pulseController.value * 0.1,
                child: child,
              );
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: kAlertRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sos, size: 50, color: kAlertRed),
            ),
          ),
          SizedBox(height: 24),

          // Alert Title
          Text(
            '${sos.reason.emoji} ${sos.reason.label}',
            style: TextStyle(
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w900,
              fontSize: 26,
              color: kAlertRed,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Triggered by ${sos.triggerName}',
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
              fontSize: 15,
            ),
          ),
          if (sos.note != null && sos.note!.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              '"${sos.note}"',
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ],

          SizedBox(height: 28),

          // Status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kAlertRed.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: kAlertRed.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: kAlertRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'ACTIVE ALERT',
                      style: TextStyle(
                        fontFamily: 'Thicccboi',
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: kAlertRed,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$ackCount acknowledged',
                      style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Acknowledgers
                if (ackCount > 0)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: sos.acknowledgedBy
                        .map((uid) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: kSuccessGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: kSuccessGreen, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    uid.substring(0, uid.length > 6 ? 6 : uid.length),
                                    style: TextStyle(
                                      color: kSuccessGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Action buttons
          if (isMyAlert)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _onResolveSos,
                icon: Icon(Icons.check_circle, size: 20),
                label: Text(
                  'Resolve — I\'m OK',
                  style: TextStyle(
                    fontFamily: 'Thicccboi',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSuccessGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            )
          else if (!hasAcknowledged)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _onAcknowledgeSos,
                icon: Icon(Icons.visibility, size: 20),
                label: Text(
                  'Acknowledge — I See It',
                  style: TextStyle(
                    fontFamily: 'Thicccboi',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kSuccessGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: kSuccessGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: kSuccessGreen, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'You acknowledged this alert',
                    style: TextStyle(
                      fontFamily: 'Thicccboi',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: kSuccessGreen,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Main Content (no active SOS) ─────────────

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(height: 16),

          // Warning icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kAlertRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_rounded,
              size: 42,
              color: kAlertRed,
            ),
          ),
          SizedBox(height: 20),

          // Title
          Text(
            "What's the\nemergency?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w900,
              fontSize: 28,
              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
              height: 1.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Select a category to alert your convoy\nimmediately. Your location will be shared.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          SizedBox(height: 28),

          // Reason Grid (2x3)
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: SosReason.values.map((reason) {
              final isSelected = _selectedReason == reason;
              return _SosReasonCard(
                reason: reason,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedReason = reason),
              );
            }).toList(),
          ),
          SizedBox(height: 20),

          // Optional Note
          if (_selectedReason != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),
              ),
              child: TextField(
                controller: _noteController,
                maxLines: 2,
                style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a note (optional)...',
                  hintStyle: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            SizedBox(height: 20),
          ],

          // Convoy Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Convoy Status',
                      style: TextStyle(
                        fontFamily: 'Thicccboi',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: kSuccessGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'All Secure',
                          style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: kSuccessGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: kSuccessGreen,
                        fontFamily: 'Thicccboi',
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 28),

          // Send SOS Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedReason != null ? _onSendSos : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAlertRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder),
                disabledForegroundColor: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sos, size: 22),
                  SizedBox(width: 8),
                  Text(
                    _selectedReason != null
                        ? 'Send ${_selectedReason!.label} Alert'
                        : 'Select a category',
                    style: TextStyle(
                      fontFamily: 'Thicccboi',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── SOS Reason Card ────────────────────────────

class _SosReasonCard extends StatelessWidget {
  final SosReason reason;
  final bool isSelected;
  final VoidCallback onTap;

  const _SosReasonCard({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? kAlertRed.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kAlertRed : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              reason.icon,
              size: 32,
              color: isSelected ? kAlertRed : (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
            ),
            SizedBox(height: 10),
            Text(
              reason.label,
              style: TextStyle(
                fontFamily: 'Thicccboi',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isSelected ? kAlertRed : (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
              ),
            ),
            SizedBox(height: 2),
            Text(
              _getSubtitle(reason),
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? kAlertRed.withValues(alpha: 0.7)
                    : (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSubtitle(SosReason reason) {
    switch (reason) {
      case SosReason.accident:
        return 'Crash or collision';
      case SosReason.breakdown:
        return 'Engine or tire';
      case SosReason.medical:
        return 'Health emergency';
      case SosReason.tyrePuncture:
        return 'Flat or damaged';
      case SosReason.lost:
        return 'Separated from group';
      case SosReason.other:
        return 'General alert';
    }
  }
}
