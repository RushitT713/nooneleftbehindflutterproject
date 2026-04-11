import '../constants.dart';

class HaltModel {
  final String haltId;
  final String proposedBy;
  final String proposerName;
  final double locationLat;
  final double locationLng;
  final String locationName;
  final String? note;
  final Map<String, String> votes; // uid -> 'yes' | 'no' | 'maybe'
  final HaltStatus status;
  final int createdAt;

  HaltModel({
    required this.haltId,
    required this.proposedBy,
    required this.proposerName,
    required this.locationLat,
    required this.locationLng,
    required this.locationName,
    this.note,
    this.votes = const {},
    this.status = HaltStatus.active,
    required this.createdAt,
  });

  int get yesCount => votes.values.where((v) => v == 'yes').length;
  int get noCount => votes.values.where((v) => v == 'no').length;
  int get maybeCount => votes.values.where((v) => v == 'maybe').length;

  HaltVote? voteOf(String uid) {
    switch (votes[uid]) {
      case 'yes':
        return HaltVote.yes;
      case 'no':
        return HaltVote.no;
      case 'maybe':
        return HaltVote.maybe;
      default:
        return null;
    }
  }

  factory HaltModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final rawVotes = map['votes'];
    final parsedVotes = <String, String>{};
    if (rawVotes is Map) {
      rawVotes.forEach((key, value) {
        parsedVotes[key.toString()] = value.toString();
      });
    }

    return HaltModel(
      haltId: id,
      proposedBy: map['proposedBy']?.toString() ?? '',
      proposerName: map['proposerName']?.toString() ?? 'Unknown',
      locationLat: (map['locationLat'] ?? 0.0).toDouble(),
      locationLng: (map['locationLng'] ?? 0.0).toDouble(),
      locationName: map['locationName']?.toString() ?? 'Unknown Location',
      note: map['note']?.toString(),
      votes: parsedVotes,
      status: HaltStatus.fromString(map['status']?.toString()),
      createdAt: map['createdAt'] is int ? map['createdAt'] as int : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'proposedBy': proposedBy,
      'proposerName': proposerName,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'locationName': locationName,
      'note': note,
      'votes': votes,
      'status': status.name,
      'createdAt': createdAt,
    };
  }
}
