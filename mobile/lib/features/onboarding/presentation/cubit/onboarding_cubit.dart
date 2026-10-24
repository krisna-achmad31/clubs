import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/sport.dart';
import '../../../../core/services/location_service.dart';
import '../../../profile/domain/entities/user_profile.dart';

class OnboardingDraft extends Equatable {
  const OnboardingDraft({
    this.phone = '',
    this.otp = '',
    this.otpAttemptsLeft = 3,
    this.name = '',
    this.username = '',
    this.email = '',
    this.gender = Gender.lakiLaki,
    this.area = 'Kebayoran Baru, Jakarta Selatan',
    this.radiusKm = 10,
    this.sports = const [],
    this.notifications = true,
    this.goyang = true,
    this.locating = false,
  });

  final String phone;
  final String otp;
  final int otpAttemptsLeft;
  final String name;
  final String username;
  final String email;
  final Gender gender;
  final String area;
  final int radiusKm;
  final List<UserSport> sports;
  final bool notifications;
  final bool goyang;
  final bool locating;

  /// "+62 812 •••• 2210".
  String get maskedPhone {
    final d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.length < 8) return phone;
    final local = d.startsWith('62') ? d.substring(2) : (d.startsWith('0') ? d.substring(1) : d);
    return '+62 ${local.substring(0, 3)} •••• ${local.substring(local.length - 4)}';
  }

  bool get phoneValid => phone.replaceAll(RegExp(r'\D'), '').length >= 9;
  bool hasSport(String id) => sports.any((s) => s.sport.id == id);

  OnboardingDraft copyWith({
    String? phone,
    String? otp,
    int? otpAttemptsLeft,
    String? name,
    String? username,
    String? email,
    Gender? gender,
    String? area,
    int? radiusKm,
    List<UserSport>? sports,
    bool? notifications,
    bool? goyang,
    bool? locating,
  }) =>
      OnboardingDraft(
        phone: phone ?? this.phone,
        otp: otp ?? this.otp,
        otpAttemptsLeft: otpAttemptsLeft ?? this.otpAttemptsLeft,
        name: name ?? this.name,
        username: username ?? this.username,
        email: email ?? this.email,
        gender: gender ?? this.gender,
        area: area ?? this.area,
        radiusKm: radiusKm ?? this.radiusKm,
        sports: sports ?? this.sports,
        notifications: notifications ?? this.notifications,
        goyang: goyang ?? this.goyang,
        locating: locating ?? this.locating,
      );

  @override
  List<Object?> get props => [phone, otp, otpAttemptsLeft, name, username, email, gender, area, radiusKm, sports, notifications, goyang, locating];
}

/// Collects A2–A9 answers before they are committed to [MeCubit].
class OnboardingCubit extends Cubit<OnboardingDraft> {
  OnboardingCubit(this._location)
      : super(OnboardingDraft(sports: [
          UserSport(Sports.badminton, level: SkillLevel.menengah),
          UserSport(Sports.padel, level: SkillLevel.pemula),
        ]));

  final LocationService _location;

  void setPhone(String v) => emit(state.copyWith(phone: v));
  void setName(String v) => emit(state.copyWith(name: v, username: state.username.isEmpty ? null : state.username));
  void setUsername(String v) => emit(state.copyWith(username: v.replaceAll(RegExp(r'[^a-zA-Z0-9_.]'), '').toLowerCase()));
  void setEmail(String v) => emit(state.copyWith(email: v));
  void setGender(Gender g) => emit(state.copyWith(gender: g));
  void setArea(String v) => emit(state.copyWith(area: v));
  void setRadius(int km) => emit(state.copyWith(radiusKm: km));
  void setNotifications(bool v) => emit(state.copyWith(notifications: v));
  void setGoyang(bool v) => emit(state.copyWith(goyang: v));

  /// Demo verification: any 6 digits except 000000 pass.
  bool verifyOtp(String code) {
    emit(state.copyWith(otp: code));
    if (code.length == 6 && code != '000000') return true;
    emit(state.copyWith(otpAttemptsLeft: (state.otpAttemptsLeft - 1).clamp(0, 3)));
    return false;
  }

  Future<bool> useCurrentLocation() async {
    emit(state.copyWith(locating: true));
    final ok = await _location.ensureReady();
    final p = ok ? await _location.current() : null;
    emit(state.copyWith(locating: false, area: p == null ? null : 'Kebayoran Baru, Jakarta Selatan'));
    return p != null;
  }

  void toggleSport(Sport s) {
    if (state.hasSport(s.id)) {
      emit(state.copyWith(sports: state.sports.where((x) => x.sport.id != s.id).toList()));
    } else {
      emit(state.copyWith(sports: [...state.sports, UserSport(s)]));
    }
  }

  void saveSport(UserSport u) {
    final exists = state.hasSport(u.sport.id);
    emit(state.copyWith(sports: exists ? [for (final s in state.sports) s.sport.id == u.sport.id ? u : s] : [...state.sports, u]));
  }
}
