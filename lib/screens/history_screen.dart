import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../models/history_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance;
  List<TripHistoryModel> _history = [];
  bool _isLoading = true;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final ref = _db.ref('users/$uid/history');
      final snapshot = await ref.orderByChild('timestamp').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final items = data.entries
            .map((e) => TripHistoryModel.fromMap(
                e.key.toString(), e.value as Map<dynamic, dynamic>))
            .toList();
        // Newest first
        items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          _history = items;
          _isLoading = false;
        });
      } else {
        setState(() {
          _history = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteHistoryItem(String historyId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.ref('users/$uid/history/$historyId').remove();
    } catch (e) {
      debugPrint('Error deleting history: $e');
    }
  }

  String _formatDate(int ms) {
    if (ms == 0) return 'Unknown Date';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('MMM d, yyyy • h:mm a').format(dt);
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '< 1m';
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes.remainder(60)}m';
  }

  String _getVehicleEmoji(String type) {
    final lower = type.toLowerCase();
    final v = kVehicles.firstWhere(
      (element) => element.name.toLowerCase() == lower,
      orElse: () => kVehicles.first,
    );
    return v.emoji;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trip History',
          style: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w900,
            color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: kPrimary));
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off,
                size: 80, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary).withValues(alpha: 0.3)),
            SizedBox(height: 24),
            Text(
              'No past trips found',
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
                fontSize: 18,
                fontFamily: 'Thicccboi',
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Completed trips will appear here.',
              style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: kPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final trip = _history[index];
          return _buildHistoryCard(trip);
        },
      ),
    );
  }

  Widget _buildHistoryCard(TripHistoryModel trip) {
    final isExpanded = _expandedId == trip.id;
    final emoji = _getVehicleEmoji(trip.vehicleType);

    return Dismissible(
      key: Key(trip.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: kAlertRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: kAlertRed, size: 28),
      ),
      onDismissed: (_) {
        setState(() => _history.removeWhere((item) => item.id == trip.id));
        _deleteHistoryItem(trip.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip deleted from history'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedId = isExpanded ? null : trip.id;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isExpanded ? kPrimary.withValues(alpha: 0.5) : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder),
              width: isExpanded ? 2 : 1,
            ),
            boxShadow: isExpanded
                ? [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header (Always Visible) ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline Dot / Role Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: trip.wasHost
                            ? kPrimaryLight
                            : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder).withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          trip.wasHost ? '👑' : emoji,
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    SizedBox(width: 14),
                    // Summary Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                trip.destinationName?.isNotEmpty == true
                                    ? trip.destinationName!
                                    : 'No destination',
                                style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                                  fontFamily: 'Thicccboi',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatDate(trip.timestamp),
                            style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Expanded Content ──
              if (isExpanded) ...[
                Divider(height: 1, color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatWidget(
                            Icons.timer_outlined,
                            'Duration',
                            _formatDuration(trip.durationSeconds),
                            kAccentBlue,
                          ),
                          _buildStatWidget(
                            Icons.people_alt_outlined,
                            'Convoy',
                            '${trip.memberCount}',
                            kSuccessGreen,
                          ),
                          _buildStatWidget(
                            Icons.directions_car_outlined,
                            'Vehicle',
                            trip.vehicleType,
                            kHaltAmber,
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Members List
                      if (trip.memberNames.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'CONVOY MEMBERS (${trip.memberNames.length})',
                            style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                              fontSize: 10,
                              fontFamily: 'Thicccboi',
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: trip.memberNames.map((name) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      SizedBox(height: 16),
                      // Trip Code & Copy
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TRIP CODE',
                                  style: TextStyle(
                                    color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  trip.tripCode,
                                  style: TextStyle(
                                    color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                                    fontFamily: 'Thicccboi',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            if (trip.wasHost)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kPrimaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'HOST',
                                  style: TextStyle(
                                    color: kPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatWidget(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
