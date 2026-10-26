import 'package:equatable/equatable.dart';

/// P6 sensitivity → accelerometer threshold in m/s² (lower = easier to trigger).
enum ShakeSensitivity {
  pelan('Pelan', 18),
  normal('Normal', 14),
  kuat('Kuat', 10);

  const ShakeSensitivity(this.label, this.threshold);
  final String label;
  final double threshold;
}

enum InviteAudience {
  semuaTeman('Semua teman'),
  klubku('Klubku'),
  temanDekat('Teman dekat');

  const InviteAudience(this.label);
  final String label;
}

class GoyangSettings extends Equatable {
  const GoyangSettings({
    this.enabled = true,
    this.sensitivity = ShakeSensitivity.normal,
    this.audience = InviteAudience.semuaTeman,
    this.quietHours = true,
    this.shakeTogether = true,
    this.nearby = false,
    this.limitIncoming = true,
  });

  final bool enabled;
  final ShakeSensitivity sensitivity;
  final InviteAudience audience;
  final bool quietHours;
  final bool shakeTogether;
  final bool nearby;
  final bool limitIncoming;

  GoyangSettings copyWith({
    bool? enabled,
    ShakeSensitivity? sensitivity,
    InviteAudience? audience,
    bool? quietHours,
    bool? shakeTogether,
    bool? nearby,
    bool? limitIncoming,
  }) => GoyangSettings(
    enabled: enabled ?? this.enabled,
    sensitivity: sensitivity ?? this.sensitivity,
    audience: audience ?? this.audience,
    quietHours: quietHours ?? this.quietHours,
    shakeTogether: shakeTogether ?? this.shakeTogether,
    nearby: nearby ?? this.nearby,
    limitIncoming: limitIncoming ?? this.limitIncoming,
  );

  @override
  List<Object?> get props => [
    enabled,
    sensitivity,
    audience,
    quietHours,
    shakeTogether,
    nearby,
    limitIncoming,
  ];
}

/// P1 draft.
class GoyangInvite extends Equatable {
  const GoyangInvite({
    this.sportId = 'badminton',
    this.when = 0,
    this.friends = true,
    this.club = true,
    this.nearby = false,
    this.venue = 'GOR Mahakam',
    this.courtFee = 120000,
    this.split = 4,
  });

  final String sportId;

  /// 0 Sekarang, 1 1 jam lagi, 2 Nanti malam.
  final int when;
  final bool friends;
  final bool club;
  final bool nearby;
  final String venue;

  /// Court rent for the 2-hour slot, shared by [split] players.
  final int courtFee;
  final int split;

  int get share => courtFee ~/ split;

  static const whenLabels = ['Sekarang', '1 jam lagi', 'Nanti malam'];
  String get whenLabel => whenLabels[when];

  GoyangInvite copyWith({
    String? sportId,
    int? when,
    bool? friends,
    bool? club,
    bool? nearby,
    String? venue,
  }) => GoyangInvite(
    sportId: sportId ?? this.sportId,
    when: when ?? this.when,
    friends: friends ?? this.friends,
    club: club ?? this.club,
    nearby: nearby ?? this.nearby,
    venue: venue ?? this.venue,
    courtFee: courtFee,
    split: split,
  );

  @override
  List<Object?> get props => [
    sportId,
    when,
    friends,
    club,
    nearby,
    venue,
    courtFee,
    split,
  ];
}

enum LobbyStatus { ikut, nanti, dilihat }

/// Avatar tone, mapped to theme colours in the UI so the domain stays UI-free.
enum LobbyTone { me, blue, purple, orange, red }

class LobbyResponse extends Equatable {
  const LobbyResponse(
    this.name,
    this.initials,
    this.tone,
    this.status, {
    this.note,
    this.host = false,
  });

  final String name;
  final String initials;
  final LobbyTone tone;
  final LobbyStatus status;
  final String? note;
  final bool host;

  @override
  List<Object?> get props => [name, status];
}
