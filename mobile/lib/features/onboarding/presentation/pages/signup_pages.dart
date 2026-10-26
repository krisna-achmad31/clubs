import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../cubit/onboarding_cubit.dart';

/// A2 Buat akun (or "Masuk" with `?mode=login`).
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  late final _phone = TextEditingController(
    text: context.read<OnboardingCubit>().state.phone,
  );
  late final _terms = TapGestureRecognizer()
    ..onTap = () => _legal(
      'Ketentuan',
      'Klubby dipakai untuk cari mabar, gabung klub, dan rekam aktivitas. Hormati teman main dan host, datang sesuai RSVP, dan bayar iuran yang kamu setujui. Versi demo ini belum punya ketentuan layanan produksi.',
    );
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => _legal(
      'Kebijakan Privasi',
      'Versi demo menyimpan profil, foto, dan pengaturan hanya di perangkat ini. Lokasimu dipakai untuk mencari klub terdekat dan tidak ditampilkan ke orang lain. Data klub dan pembayaran adalah contoh.',
    );

  /// Which social button is busy, if any.
  String? _social;

  bool get _login =>
      GoRouterState.of(context).uri.queryParameters['mode'] == 'login';

  @override
  void dispose() {
    _phone.dispose();
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  void _legal(String title, String body) => showKSheet<void>(
    context,
    (ctx) => KSheet(
      children: [
        Text(title, style: AppText.title()),
        Text(body, style: AppText.body()),
        KButton('TUTUP', onTap: () => Navigator.pop(ctx)),
      ],
    ),
  );

  void _send() {
    final c = context.read<OnboardingCubit>();
    c.setLogin(_login);
    c.setPhone(_phone.text);
    if (!c.state.phoneValid) {
      return toast(context, 'Nomor WhatsApp belum lengkap');
    }
    context.push(R.otp);
  }

  /// Demo social sign-in: short loading state, then the same next step as OTP.
  Future<void> _socialSignIn(String provider) async {
    if (_social != null) return;
    final c = context.read<OnboardingCubit>();
    final login = _login;
    c.setLogin(login);
    setState(() => _social = provider);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _social = null);
    if (login) {
      final me = sl<MeCubit>();
      me.completeOnboarding(
        name: me.state.name,
        username: me.state.username,
        phone: me.state.phone,
      );
      context.go(R.feed);
    } else {
      context.push(R.about);
    }
  }

  @override
  Widget build(BuildContext context) {
    final login = _login;
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    return KPage(
      header: KHeader(
        login ? 'Masuk' : 'Buat akun',
        leading: LucideIcons.x,
        onLeading: () =>
            context.canPop() ? context.pop() : context.go(R.welcome),
      ),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      children: [
        MascotSays(
          animal: Animal.kiki,
          size: 96,
          bg: AppColors.primaryL,
          text: login
              ? 'Halo lagi! Masuk pakai nomor WhatsApp-mu ya.'
              : 'Daftar sekali, langsung bisa ikut mabar & kumpulin stamp!',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('NOMOR WHATSAPP'),
            const SizedBox(height: 8),
            KInput(
              controller: _phone,
              hint: '0812 3456 2210',
              icon: LucideIcons.phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Kami kirim kode OTP lewat WhatsApp. Nomor ini juga dipakai untuk RSVP dari link grup.',
              style: AppText.custom(
                13,
                w: FontWeight.w700,
                c: AppColors.muted,
                h: 1.35,
              ),
            ),
          ],
        ),
        KBanner.info(
          'Mode demo: kode OTP tidak benar-benar dikirim. Masukkan 6 angka apa saja selain 000000.',
        ),
        KButton('KIRIM KODE OTP', onTap: digits.length >= 9 ? _send : null),
        const OrDivider(),
        _SocialButton(
          label: login ? 'MASUK DENGAN GOOGLE' : 'LANJUT DENGAN GOOGLE',
          leading: const _GoogleMark(),
          loading: _social == 'google',
          onTap: () => _socialSignIn('google'),
        ),
        if (isIos)
          _SocialButton(
            label: login ? 'MASUK DENGAN APPLE' : 'LANJUT DENGAN APPLE',
            leading: const Icon(
              LucideIcons.apple,
              size: 20,
              color: AppColors.ink,
            ),
            loading: _social == 'apple',
            onTap: () => _socialSignIn('apple'),
          ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: AppText.custom(12, w: FontWeight.w700, c: AppColors.faint),
            children: [
              TextSpan(
                text: login
                    ? 'Dengan masuk, kamu setuju dengan '
                    : 'Dengan mendaftar, kamu setuju dengan ',
              ),
              TextSpan(
                text: 'Ketentuan',
                recognizer: _terms,
                style: AppText.custom(12, c: AppColors.primary),
              ),
              const TextSpan(text: ' & '),
              TextSpan(
                text: 'Kebijakan Privasi',
                recognizer: _privacy,
                style: AppText.custom(12, c: AppColors.primary),
              ),
              const TextSpan(text: ' Klubby.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Secondary-style chunky button with a custom leading mark and a loading state.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.leading,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final Widget leading;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: loading ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 2),
        boxShadow: lip(AppColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            )
          else ...[
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.button(AppColors.ink, 17),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Letter "G" in a circle (Lucide has no brand icons).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.white,
      border: Border.all(color: AppColors.line, width: 2),
    ),
    child: Text('G', style: AppText.custom(13, c: AppColors.primary)),
  );
}

/// A2b OTP.
class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _left = 42;
  bool _error = false;
  int _shake = 0;
  int _lockLeft = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left == 0) return t.cancel();
      setState(() => _left--);
      if (_lockLeft > 0) {
        setState(() => _lockLeft--);
        if (_lockLeft == 0) {
          context.read<OnboardingCubit>().resetOtp();
          setState(() => _error = false);
        }
      }
    });
  }

  Future<void> _verify() async {
    final c = context.read<OnboardingCubit>();
    if (c.state.otpLocked) return;
    final ok = c.verifyOtp(_ctrl.text);
    if (ok) {
      HapticFeedback.lightImpact();
      if (c.state.login) {
        // Existing account: keep the stored profile, refresh the phone.
        final me = sl<MeCubit>();
        me.completeOnboarding(
          name: me.state.name,
          username: me.state.username,
          phone: c.state.phone,
        );
        if (mounted) context.go(R.feed);
      } else {
        context.push(R.about);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _shake++;
        _ctrl.clear();
        if (c.state.otpLocked) {
          _lockLeft = 30;
          _left = 30;
          _tick();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<OnboardingCubit>().state;
    final code = _ctrl.text;
    Widget box(int i) {
      final filled = i < code.length;
      final active = i == code.length;
      return Expanded(
        child: AnimatedContainer(
          duration: Motion.fast,
          height: 60,
          margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
          decoration: BoxDecoration(
            color: filled ? AppColors.primaryL : AppColors.soft,
            borderRadius: BorderRadius.circular(14),
            border: chunkyBorder(
              filled
                  ? AppColors.primaryM
                  : (active ? AppColors.primary : AppColors.line),
              bottom: 4,
            ),
          ),
          alignment: Alignment.center,
          child: filled
              ? PopIn(
                  from: .3,
                  child: Text(
                    code[i],
                    style: AppText.custom(26, c: AppColors.primaryD),
                  ),
                )
              : null,
        ),
      );
    }

    return KPage(
      header: const KHeader('Masukkan kode'),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      bottom: KButton(
        'VERIFIKASI',
        onTap: code.length == 6 && !draft.otpLocked ? _verify : null,
      ),
      children: [
        Text(
          'Kode 6 digit dikirim ke WhatsApp ${draft.maskedPhone}',
          style: AppText.custom(15, w: FontWeight.w700, c: AppColors.muted),
        ),
        GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Stack(
            children: [
              Wobble(
                trigger: _shake,
                angle: .03,
                child: Row(children: [for (var i = 0; i < 6; i++) box(i)]),
              ),
              // Invisible field drives the boxes and supports SMS/WhatsApp autofill.
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 60,
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    enabled: !draft.otpLocked,
                    decoration: const InputDecoration(
                      labelText: 'Kode demo 6 digit',
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      setState(() => _error = false);
                      if (v.length == 6) _verify();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            const Icon(LucideIcons.timer, size: 18, color: AppColors.faint),
            const SizedBox(width: 6),
            if (_left > 0)
              Text(
                'Kirim ulang dalam 0:${_left.toString().padLeft(2, '0')}',
                style: AppText.custom(
                  14,
                  w: FontWeight.w800,
                  c: AppColors.faint,
                ),
              )
            else
              Pressable(
                onTap: () => setState(() {
                  _left = 42;
                  context.read<OnboardingCubit>().resetOtp();
                  _ctrl.clear();
                  _error = false;
                  _tick();
                  toast(context, 'Percobaan kode demo direset');
                }),
                depth: 0,
                child: Text(
                  'KIRIM ULANG KODE',
                  style: AppText.custom(14, c: AppColors.primary),
                ),
              ),
          ],
        ),
        AnimatedSwitcher(
          duration: Motion.base,
          child: _error
              ? KBanner(
                  key: const ValueKey('err'),
                  text: draft.otpLocked
                      ? 'Coba lagi dalam $_lockLeft detik'
                      : 'Kode salah. Sisa ${draft.otpAttemptsLeft} percobaan.',
                  icon: LucideIcons.circleAlert,
                  bg: AppColors.redL,
                  fg: AppColors.redD,
                  iconColor: AppColors.red,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// A3 Tentang kamu.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  Future<void> _pickPhoto() async {
    final c = context.read<OnboardingCubit>();
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (photo != null && mounted) c.setPhoto(photo.path);
    } on Exception {
      if (mounted) {
        toast(
          context,
          'Foto belum bisa dibuka. Periksa izin galeri di pengaturan.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<OnboardingCubit>();
    final d = context.watch<OnboardingCubit>().state;
    final initials = d.name.trim().isEmpty
        ? '?'
        : UserProfile(name: d.name, username: '', phone: '').initials;
    return KPage(
      header: const ProgressHeader(value: .3),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      bottom: KButton(
        'LANJUT',
        onTap: d.aboutValid ? () => context.push(R.location) : null,
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tentang kamu', style: AppText.custom(26)),
            const SizedBox(height: 4),
            Text(
              'Biar teman mabar gampang kenal kamu.',
              style: AppText.custom(15, w: FontWeight.w800, c: AppColors.muted),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryD, width: 5),
              ),
              child: AnimatedSwitcher(
                duration: Motion.base,
                child: d.photoPath == null
                    ? Text(
                        initials,
                        key: ValueKey(initials),
                        style: AppText.custom(34, c: AppColors.white),
                      )
                    : ClipOval(
                        key: ValueKey(d.photoPath),
                        child: Image.file(
                          File(d.photoPath!),
                          width: 78,
                          height: 78,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KLink('UNGGAH FOTO', onTap: _pickPhoto),
                  const SizedBox(height: 4),
                  Text(
                    'Atau pakai maskotmu nanti sebagai avatar',
                    style: AppText.custom(
                      13,
                      w: FontWeight.w700,
                      c: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        _Field(
          'NAMA',
          KInput(
            hint: 'Budi Santoso',
            icon: LucideIcons.user,
            initialValue: d.name,
            onChanged: c.setName,
          ),
        ),
        _Field(
          'USERNAME',
          KInput(
            key: d.usernameEdited
                ? const ValueKey('edited-username')
                : ValueKey(d.username),
            hint: 'username',
            icon: LucideIcons.atSign,
            initialValue: d.username,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_.]')),
              LengthLimitingTextInputFormatter(20),
            ],
            onChanged: c.setUsername,
          ),
        ),
        _Field(
          'EMAIL (OPSIONAL)',
          KInput(
            hint: 'budi@email.com',
            icon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
            initialValue: d.email,
            onChanged: c.setEmail,
          ),
        ),
        _Field(
          'JENIS KELAMIN (UNTUK MABAR KHUSUS)',
          Row(
            children: [
              for (final (g, l) in [
                (Gender.lakiLaki, 'Laki-laki'),
                (Gender.perempuan, 'Perempuan'),
                (Gender.rahasia, 'Rahasia'),
              ]) ...[
                Expanded(
                  child: KChip(
                    l,
                    selected: d.gender == g,
                    expand: true,
                    onTap: () => c.setGender(g),
                  ),
                ),
                if (g != Gender.rahasia) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.child);

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [FieldLabel(label), const SizedBox(height: 8), child],
  );
}

/// A4 Mau main di mana?
class LocationPage extends StatelessWidget {
  const LocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.read<OnboardingCubit>();
    final d = context.watch<OnboardingCubit>().state;
    return KPage(
      header: const ProgressHeader(value: .4),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      bottom: KButton(
        'LANJUT',
        onTap: d.area.isEmpty ? null : () => context.push(R.sports),
      ),
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const FlatMap(
              height: 200,
              onboarding: true,
              layers: {MapLayer.pin},
            ),
            IgnorePointer(
              child: Container(
                width: 50.0 + d.radiusKm * 5,
                height: 50.0 + d.radiusKm * 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: .12),
                  border: Border.all(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mau main di mana?', style: AppText.custom(26)),
            const SizedBox(height: 4),
            Text(
              'Klubby carikan klub, mabar & lapangan terdekat. Lokasimu tetap privat, nggak pernah ditampilkan.',
              style: AppText.custom(
                15,
                w: FontWeight.w800,
                c: AppColors.muted,
                h: 1.35,
              ),
            ),
          ],
        ),
        KButton(
          'PAKAI LOKASI SEKARANG',
          icon: LucideIcons.locateFixed,
          loading: d.locating,
          onTap: () async {
            final ok = await c.useCurrentLocation();
            if (!ok && context.mounted) {
              toast(
                context,
                c.locationError ?? 'Pilih kecamatanmu secara manual.',
              );
            }
          },
        ),
        const OrDivider(),
        KCard(
          onTap: () async {
            final area = await showAreaPicker(context, current: d.area);
            if (area != null && context.mounted) c.setArea(area);
          },
          color: AppColors.primaryL,
          border: AppColors.primaryM,
          child: Row(
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 22,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.area.isEmpty ? 'Pilih kecamatan atau kota' : d.area,
                      style: AppText.custom(16),
                    ),
                    Text(
                      'Benar ini lokasimu?',
                      style: AppText.custom(
                        13,
                        w: FontWeight.w700,
                        c: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text('UBAH', style: AppText.custom(14, c: AppColors.primary)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Jarak cari'),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final km in const [5, 10, 20]) ...[
                  Expanded(
                    child: KChip(
                      '$km km',
                      selected: d.radiusKm == km,
                      expand: true,
                      onTap: () => c.setRadius(km),
                    ),
                  ),
                  if (km != 20) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}
