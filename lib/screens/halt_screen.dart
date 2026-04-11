import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/halt_model.dart';
import '../providers/trip_provider.dart';
import '../services/halt_service.dart';

/// Halt Proposals — functional real-time screen via Firebase RTDB.
class HaltScreen extends StatefulWidget {
  final String tripCode;

  const HaltScreen({super.key, required this.tripCode});

  @override
  State<HaltScreen> createState() => _HaltScreenState();
}

class _HaltScreenState extends State<HaltScreen> {
  final HaltService _haltService = HaltService();

  List<HaltModel> _proposals = [];
  StreamSubscription? _haltSubscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _haltSubscription = _haltService
        .listenToHalts(widget.tripCode)
        .listen((halts) {
      if (!mounted) return;
      setState(() => _proposals = halts);
    });
  }

  @override
  void dispose() {
    _haltSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final myUserId = provider.userId ?? '';
    final activeCount = _proposals.length;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Halt Proposals',
          style: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w900,
            color: kTextPrimary,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(height: 1, color: kSurfaceBorder),

          // Active Polls Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Active Polls',
                  style: TextStyle(
                    fontFamily: 'Thicccboi',
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: kTextPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$activeCount Active',
                    style: const TextStyle(
                      color: kPrimary,
                      fontFamily: 'Thicccboi',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Proposals List
          Expanded(
            child: _proposals.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.back_hand_outlined,
                            color: kTextTertiary.withValues(alpha: 0.4),
                            size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'No active proposals',
                          style: TextStyle(
                            color: kTextTertiary,
                            fontFamily: 'Thicccboi',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Propose a halt for the convoy to vote on!',
                          style: TextStyle(
                            color: kTextTertiary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: _proposals.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final halt = _proposals[index];
                      final isLeading = _isLeadingProposal(halt);
                      return _HaltProposalCard(
                        halt: halt,
                        myUserId: myUserId,
                        isLeading: isLeading,
                        tripCode: widget.tripCode,
                        haltService: _haltService,
                      );
                    },
                  ),
          ),
        ],
      ),

      // Propose New Halt FAB
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => _showProposeSheet(context),
              icon: const Icon(Icons.pin_drop, size: 20),
              label: const Text(
                'Propose New Halt',
                style: TextStyle(
                  fontFamily: 'Thicccboi',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Determines if a proposal is the leading one (highest yes count).
  bool _isLeadingProposal(HaltModel halt) {
    if (_proposals.length <= 1) return _proposals.isNotEmpty;
    final maxYes = _proposals
        .map((h) => h.yesCount)
        .reduce((a, b) => a > b ? a : b);
    return halt.yesCount == maxYes && halt.yesCount > 0;
  }

  void _showProposeSheet(BuildContext context) {
    final provider = context.read<TripProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: kBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ProposeHaltSheet(
        onSubmit: (locationName, note) {
          _haltService.proposeHalt(
            tripCode: widget.tripCode,
            userId: provider.userId ?? '',
            userName: provider.nickname ?? 'Unknown',
            locationName: locationName,
            note: note,
          );
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ─── Proposal Card ──────────────────────────────

class _HaltProposalCard extends StatelessWidget {
  final HaltModel halt;
  final String myUserId;
  final bool isLeading;
  final String tripCode;
  final HaltService haltService;

  const _HaltProposalCard({
    required this.halt,
    required this.myUserId,
    required this.isLeading,
    required this.tripCode,
    required this.haltService,
  });

  @override
  Widget build(BuildContext context) {
    final totalVoters = halt.votes.length;
    final yesPercent = totalVoters > 0
        ? (halt.yesCount / totalVoters * 100).round()
        : 0;
    final noPercent = totalVoters > 0
        ? (halt.noCount / totalVoters * 100).round()
        : 0;
    final myVote = halt.voteOf(myUserId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLeading
              ? kPrimary.withValues(alpha: 0.3)
              : kSurfaceBorder,
          width: isLeading ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading badge
          if (isLeading)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: kPrimary, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'LEADING OPTION',
                    style: TextStyle(
                      fontFamily: 'Thicccboi',
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: kPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

          // Title + Note + Proposer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      halt.locationName,
                      style: const TextStyle(
                        fontFamily: 'Thicccboi',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: kTextPrimary,
                      ),
                    ),
                    if (halt.note != null && halt.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        halt.note!,
                        style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: kPrimaryLight,
                          child: Text(
                            halt.proposerName.isNotEmpty
                                ? halt.proposerName[0]
                                : '?',
                            style: const TextStyle(
                              color: kPrimary,
                              fontFamily: 'Thicccboi',
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Proposed by ${halt.proposerName}',
                          style: const TextStyle(
                            color: kTextTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${halt.votes.length} vote${halt.votes.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: kTextTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isLeading) ...[
            const SizedBox(height: 16),

            // Vote progress bars
            _VoteBar(label: 'Yes', percent: yesPercent, color: kPrimary),
            const SizedBox(height: 8),
            _VoteBar(label: 'No', percent: noPercent, color: kAlertRed),
            const SizedBox(height: 14),

            // Vote action + cancel
            Row(
              children: [
                Expanded(
                  child: _VoteActionButton(
                    icon: Icons.thumb_up,
                    label: 'Yes',
                    count: halt.yesCount,
                    isActive: myVote == HaltVote.yes,
                    color: kPrimary,
                    onTap: () => _castVote(HaltVote.yes, myVote),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _VoteActionButton(
                    icon: Icons.thumb_down,
                    label: 'No',
                    count: halt.noCount,
                    isActive: myVote == HaltVote.no,
                    color: kAlertRed,
                    onTap: () => _castVote(HaltVote.no, myVote),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _VoteActionButton(
                    icon: Icons.help_outline,
                    label: 'Maybe',
                    count: halt.maybeCount,
                    isActive: myVote == HaltVote.maybe,
                    color: kHaltAmber,
                    onTap: () => _castVote(HaltVote.maybe, myVote),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),

            // Vote buttons row
            Row(
              children: [
                _VoteActionButton(
                  icon: Icons.thumb_up_outlined,
                  label: 'Yes',
                  count: halt.yesCount,
                  isActive: myVote == HaltVote.yes,
                  color: kPrimary,
                  onTap: () => _castVote(HaltVote.yes, myVote),
                ),
                const SizedBox(width: 12),
                _VoteActionButton(
                  icon: Icons.thumb_down_outlined,
                  label: 'No',
                  count: halt.noCount,
                  isActive: myVote == HaltVote.no,
                  color: kAlertRed,
                  onTap: () => _castVote(HaltVote.no, myVote),
                ),
                const SizedBox(width: 12),
                _VoteActionButton(
                  icon: Icons.help_outline,
                  label: 'Maybe',
                  count: halt.maybeCount,
                  isActive: myVote == HaltVote.maybe,
                  color: kHaltAmber,
                  onTap: () => _castVote(HaltVote.maybe, myVote),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _castVote(HaltVote vote, HaltVote? currentVote) {
    if (currentVote == vote) {
      // Toggle off — remove vote
      haltService.removeVote(
        tripCode: tripCode,
        haltId: halt.haltId,
        userId: myUserId,
      );
    } else {
      // Cast / change vote
      haltService.vote(
        tripCode: tripCode,
        haltId: halt.haltId,
        userId: myUserId,
        vote: vote,
      );
    }
  }
}

// ─── Vote Action Button ──────────────────────────

class _VoteActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _VoteActionButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : kBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : kSurfaceBorder,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? color : kTextTertiary, size: 18),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Thicccboi',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isActive ? color : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Vote Progress Bar ──────────────────────────

class _VoteBar extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;

  const _VoteBar({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Thicccboi',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: kTextPrimary,
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                fontFamily: 'Thicccboi',
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100.0,
            minHeight: 6,
            backgroundColor: kSurfaceBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─── Propose Halt Bottom Sheet ──────────────────

class _ProposeHaltSheet extends StatefulWidget {
  final void Function(String locationName, String? note) onSubmit;

  const _ProposeHaltSheet({required this.onSubmit});

  @override
  State<_ProposeHaltSheet> createState() => _ProposeHaltSheetState();
}

class _ProposeHaltSheetState extends State<_ProposeHaltSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _selectedCategory;

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onCategoryTap(String category) {
    setState(() {
      if (_selectedCategory == category) {
        _selectedCategory = null;
        // Clear the name if it matches the category
      } else {
        _selectedCategory = category;
        // Auto-fill the name field with the category
        if (_nameController.text.isEmpty) {
          _nameController.text = category;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 20, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kSurfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Propose a Halt',
            style: TextStyle(
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your convoy will vote on this stop.',
            style: TextStyle(color: kTextSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Location Name
          const Text(
            'LOCATION NAME',
            style: TextStyle(
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: kTextTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: kTextPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'e.g. Shell Gas Station',
              hintStyle:
                  TextStyle(color: kTextTertiary.withValues(alpha: 0.6)),
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kSurfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kSurfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kPrimary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Reason
          const Text(
            'REASON (OPTIONAL)',
            style: TextStyle(
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: kTextTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 2,
            style: const TextStyle(color: kTextPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'e.g. Running low on fuel',
              hintStyle:
                  TextStyle(color: kTextTertiary.withValues(alpha: 0.6)),
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kSurfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kSurfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kPrimary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),

          // Quick categories
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _categoryChip('⛽ Fuel Stop'),
              _categoryChip('🍔 Food'),
              _categoryChip('🚻 Restroom'),
              _categoryChip('📸 Photo Op'),
              _categoryChip('🛌 Rest'),
            ],
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a location name'),
                      backgroundColor: kAlertRed,
                    ),
                  );
                  return;
                }
                final note = _noteController.text.trim();
                widget.onSubmit(name, note.isEmpty ? null : note);
              },
              icon: const Icon(Icons.pin_drop, size: 20),
              label: const Text(
                'Submit Proposal',
                style: TextStyle(
                  fontFamily: 'Thicccboi',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () => _onCategoryTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryLight : kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kPrimary : kSurfaceBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Thicccboi',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isSelected ? kPrimary : kTextPrimary,
          ),
        ),
      ),
    );
  }
}
