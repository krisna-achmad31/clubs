import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/sport.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/area_picker.dart';
import '../../../profile/domain/entities/user_profile.dart';

class OnboardingDraft extends Equatable {
  const OnboardingDraft({
    this.login = false,
    this.phone = '',
    this.otp = '',
    this.otpAttemptsLeft = 3,
    this.name = '',
    this.username = '',
    this.usernameEdited = false,
    this.email = '',
    this.gender,
    this.photoPath,
    this.area = '',
    this.radiusKm = 10,
    this.sports = const [],
    this.notifications = true,
    this.goyang = true,
    this.locating = false,
  });

  /// "SAYA SUDAH PUNYA AKUN": OTP leads straight to the feed.
  final bool login;
  final String phone;
  final String otp;
  final int otpAttemptsLeft;
  final String name;
  final String username;

  /// False while the username is still auto-suggested from the name.
  final bool usernameEdited;
  final String email;
  final Gender? gender;
  final String? photoPath;
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
    final local = d.startsWith('62')
        ? d.substring(2)
        : (d.startsWith('0') ? d.substring(1) : d);
    return '+62 ${local.substring(0, 3)} •••• ${local.substring(local.length - 4)}';
  }

  bool get phoneValid => phone.replaceAll(RegExp(r'\D'), '').length >= 9;
  bool get aboutValid =>
      name.trim().length >= 2 && username.length >= 3 && gender != null;
  bool get otpLocked => otpAttemptsLeft <= 0;
  bool hasSport(String id) => sports.any((s) => s.sport.id == id);

  OnboardingDraft copyWith({
    bool? login,
    String? phone,
    String? otp,
    int? otpAttemptsLeft,
    String? name,
    String? username,
    bool? usernameEdited,
    String? email,
    Gender? gender,
    String? photoPath,
    bool clearPhoto = false,
    String? area,
    int? radiusKm,
    List<UserSport>? sports,
    bool? notifications,
    bool? goyang,
    bool? locating,
  }) => OnboardingDraft(
    login: login ?? this.login,
    phone: phone ?? this.phone,
    otp: otp ?? this.otp,
    otpAttemptsLeft: otpAttemptsLeft ?? this.otpAttemptsLeft,
    name: name ?? this.name,
    username: username ?? this.username,
    usernameEdited: usernameEdited ?? this.usernameEdited,
    email: email ?? this.email,
    gender: gender ?? this.gender,
    photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    area: area ?? this.area,
    radiusKm: radiusKm ?? this.radiusKm,
    sports: sports ?? this.sports,
    notifications: notifications ?? this.notifications,
    goyang: goyang ?? this.goyang,
    locating: locating ?? this.locating,
  );

  @override
  List<Object?> get props => [
    login,
    phone,
    otp,
    otpAttemptsLeft,
    name,
    username,
    usernameEdited,
    email,
    gender,
    photoPath,
    area,
    radiusKm,
    sports,
    notifications,
    goyang,
    locating,
  ];
}

/// Collects A2–A9 answers before they are committed to [MeCubit].
class OnboardingCubit extends Cubit<OnboardingDraft> {
  OnboardingCubit(this._location) : super(const OnboardingDraft());

  final LocationService _location;
  String? locationError;

  static const usernameMax = 20;

  static String cleanUsername(String v) {
    final s = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    return s.length > usernameMax ? s.substring(0, usernameMax) : s;
  }

  void setLogin(bool v) => emit(state.copyWith(login: v));
  void setPhone(String v) => emit(state.copyWith(phone: v));

  /// Suggests a username from the name until the user types one.
  void setName(String v) => emit(
    state.copyWith(
      name: v,
      username: state.usernameEdited
          ? null
          : cleanUsername(v.replaceAll(' ', '')),
    ),
  );
  void setUsername(String v) => emit(
    state.copyWith(username: cleanUsername(v), usernameEdited: v.isNotEmpty),
  );
  void setEmail(String v) => emit(state.copyWith(email: v));
  void setGender(Gender g) => emit(state.copyWith(gender: g));
  void setPhoto(String? path) =>
      emit(state.copyWith(photoPath: path, clearPhoto: path == null));
  void setArea(String v) => emit(state.copyWith(area: v.trim()));
  void setRadius(int km) => emit(state.copyWith(radiusKm: km));
  void setNotifications(bool v) => emit(state.copyWith(notifications: v));
  void setGoyang(bool v) => emit(state.copyWith(goyang: v));

  /// Demo verification: any 6 digits except 000000 pass.
  bool verifyOtp(String code) {
    if (state.otpLocked) return false;
    emit(state.copyWith(otp: code));
    if (RegExp(r'^\d{6}$').hasMatch(code) && code != '000000') return true;
    emit(
      state.copyWith(
        otp: '',
        otpAttemptsLeft: (state.otpAttemptsLeft - 1).clamp(0, 3),
      ),
    );
    return false;
  }

  /// New code sent (or lock expired): fresh attempts.
  void resetOtp() => emit(state.copyWith(otp: '', otpAttemptsLeft: 3));

  /// GPS → nearest kecamatan. False when location is off or denied.
  Future<bool> useCurrentLocation() async {
    if (isClosed || state.locating) return false;
    locationError = null;
    emit(state.copyWith(locating: true));
    try {
      final p = await _location.current();
      if (isClosed) return false;
      final area = p == null ? null : Areas.nearby(p.lat, p.lng);
      locationError = p == null
          ? _location.failureMessage
          : area == null
          ? 'Lokasi terbaca, tetapi kecamatanmu belum ada di daftar. Pilih area secara manual.'
          : null;
      if (area != null) emit(state.copyWith(area: area.label));
      return area != null;
    } on Exception {
      locationError =
          'Lokasi belum bisa dibaca. Coba lagi atau pilih area secara manual.';
      return false;
    } finally {
      if (!isClosed) emit(state.copyWith(locating: false));
    }
  }

  void toggleSport(Sport s) {
    if (state.hasSport(s.id)) {
      emit(
        state.copyWith(
          sports: state.sports.where((x) => x.sport.id != s.id).toList(),
        ),
      );
    } else {
      emit(state.copyWith(sports: [...state.sports, UserSport(s)]));
    }
  }

  void saveSport(UserSport u) {
    final exists = state.hasSport(u.sport.id);
    emit(
      state.copyWith(
        sports: exists
            ? [for (final s in state.sports) s.sport.id == u.sport.id ? u : s]
            : [...state.sports, u],
      ),
    );
  }
}
