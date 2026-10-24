import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../cubit/onboarding_cubit.dart';

/// A2 Buat akun.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  late final _phone = TextEditingController(text: context.read<OnboardingCubit>().state.phone);

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _send() {
    final c = context.read<OnboardingCubit>();
    c.setPhone(_phone.text.isEmpty ? '+62 812 3456 2210' : _phone.text);
    if (!c.state.phoneValid) return toast(context, 'Nomor WhatsApp belum lengkap');
    context.push(R.otp);
  }

  @override
  Widget build(BuildContext context) {
    return KPage(
      header: KHeader('Buat akun', leading: LucideIcons.x),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      children: [
        const MascotSays(animal: Animal.kiki, size: 96, bg: AppColors.blueL, text: 'Daftar sekali, langsung bisa ikut mabar & kumpulin stamp!'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('NOMOR WHATSAPP'),
          const SizedBox(height: 8),
          KInput(
            controller: _phone,
            hint: '+62 812 3456 2210',
            icon: LucideIcons.phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
          ),
          const SizedBox(height: 8),
          Text('Kami kirim kode OTP lewat WhatsApp. Nomor ini juga dipakai untuk RSVP dari link grup.', style: AppText.custom(13, w: FontWeight.w700, c: AppColors.muted, h: 1.35)),
        ]),
        KButton('KIRIM KODE OTP', onTap: _send),
        const OrDivider(),
        KButton.secondary('LANJUT DENGAN GOOGLE', icon: LucideIcons.globe, onTap: () => context.push(R.about)),
        KButton.secondary('LANJUT DENGAN APPLE', icon: LucideIcons.apple, onTap: () => context.push(R.about)),
        const SizedBox(height: 12),
        Text('Dengan mendaftar, kamu setuju dengan Ketentuan & Kebijakan Privasi Klubby.', textAlign: TextAlign.center, style: AppText.custom(12, w: FontWeight.w700, c: AppColors.faint)),
      ],
    );
  }
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
    });
  }

  void _verify() {
    final ok = context.read<OnboardingCubit>().verifyOtp(_ctrl.text);
    if (ok) {
      HapticFeedback.lightImpact();
      context.push(R.about);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _shake++;
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
            color: filled ? AppColors.blueL : AppColors.soft,
            borderRadius: BorderRadius.circular(14),
            border: chunkyBorder(filled ? AppColors.blueM : (active ? AppColors.blue : AppColors.line), bottom: 4),
          ),
          alignment: Alignment.center,
          child: filled ? PopIn(from: .3, child: Text(code[i], style: AppText.custom(26, c: AppColors.blueD))) : null,
        ),
      );
    }

    return KPage(
      header: const KHeader('Masukkan kode'),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      bottom: KButton('VERIFIKASI', onTap: code.length == 6 ? _verify : null),
      children: [
        Text('Kode 6 digit dikirim ke WhatsApp ${draft.maskedPhone}', style: AppText.custom(15, w: FontWeight.w700, c: AppColors.muted)),
        GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Stack(children: [
            Wobble(trigger: _shake, angle: .03, child: Row(children: [for (var i = 0; i < 6; i++) box(i)])),
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    setState(() => _error = false);
                    if (v.length == 6) _verify();
                  },
                ),
              ),
            ),
          ]),
        ),
        Row(children: [
          const Icon(LucideIcons.timer, size: 18, color: AppColors.faint),
          const SizedBox(width: 6),
          if (_left > 0)
            Text('Kirim ulang dalam 0:${_left.toString().padLeft(2, '0')}', style: AppText.custom(14, w: FontWeight.w800, c: AppColors.faint))
          else
            Pressable(
              onTap: () => setState(() {
                _left = 42;
                _tick();
                toast(context, 'Kode baru dikirim ke WhatsApp');
              }),
              depth: 0,
              child: Text('KIRIM ULANG KODE', style: AppText.custom(14, c: AppColors.blue)),
            ),
        ]),
        AnimatedSwitcher(
          duration: Motion.base,
          child: _error
              ? KBanner(
                  key: const ValueKey('err'),
                  text: 'Kode salah? Cek lagi ya, sisa ${draft.otpAttemptsLeft} percobaan.',
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
  @override
  Widget build(BuildContext context) {
    final c = context.read<OnboardingCubit>();
    final d = context.watch<OnboardingCubit>().state;
    final initials = d.name.trim().isEmpty ? 'BS' : UserProfile(name: d.name, username: '', phone: '').initials;
    return KPage(
      header: const ProgressHeader(value: .24),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      bottom: KButton('LANJUT', onTap: () => context.push(R.location)),
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tentang kamu', style: AppText.custom(26)),
          const SizedBox(height: 4),
          Text('Biar teman mabar gampang kenal kamu.', style: AppText.custom(15, w: FontWeight.w800, c: AppColors.muted)),
        ]),
        Row(children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.primaryD, width: 5)),
            child: AnimatedSwitcher(duration: Motion.base, child: Text(initials, key: ValueKey(initials), style: AppText.custom(34, c: AppColors.white))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Pressable(onTap: () => toast(context, 'Pilih foto dari galeri'), depth: 0, child: Text('UNGGAH FOTO', style: AppText.custom(15, c: AppColors.blue))),
              const SizedBox(height: 4),
              Text('Atau pakai maskotmu nanti sebagai avatar', style: AppText.custom(13, w: FontWeight.w700, c: AppColors.muted)),
            ]),
          ),
        ]),
        _Field('NAMA', KInput(hint: 'Budi Santoso', icon: LucideIcons.user, initialValue: d.name, onChanged: c.setName)),
        _Field('USERNAME', KInput(hint: 'budismash', icon: LucideIcons.atSign, initialValue: d.username, onChanged: c.setUsername)),
        _Field('EMAIL (OPSIONAL)', KInput(hint: 'budi@email.com', icon: LucideIcons.mail, keyboardType: TextInputType.emailAddress, initialValue: d.email, onChanged: c.setEmail)),
        _Field(
          'JENIS KELAMIN (UNTUK MABAR KHUSUS)',
          Row(children: [
            for (final (g, l) in [(Gender.lakiLaki, 'Laki-laki'), (Gender.perempuan, 'Perempuan'), (Gender.rahasia, 'Rahasia')]) ...[
              Expanded(child: KChip(l, selected: d.gender == g, expand: true, onTap: () => c.setGender(g))),
              if (g != Gender.rahasia) const SizedBox(width: 8),
            ],
          ]),
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
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FieldLabel(label), const SizedBox(height: 8), child]);
}

/// A4 Mau main di mana?
class LocationPage extends StatelessWidget {
  const LocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.read<OnboardingCubit>();
    final d = context.watch<OnboardingCubit>().state;
    return KPage(
      header: const ProgressHeader(value: .39),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      bottom: KButton('LANJUT', onTap: () => context.push(R.sports)),
      children: [
        const FlatMap(height: 200, onboarding: true, layers: {MapLayer.searchRadius, MapLayer.pin}),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mau main di mana?', style: AppText.custom(26)),
          const SizedBox(height: 4),
          Text('Klubby carikan klub, mabar & lapangan terdekat. Lokasimu tetap privat, nggak pernah ditampilkan.', style: AppText.custom(15, w: FontWeight.w800, c: AppColors.muted, h: 1.35)),
        ]),
        KButton(
          'PAKAI LOKASI SEKARANG',
          icon: LucideIcons.locateFixed,
          loading: d.locating,
          onTap: () async {
            final ok = await c.useCurrentLocation();
            if (!ok && context.mounted) toast(context, 'Izin lokasi ditolak. Ketik kecamatanmu saja ya.');
          },
        ),
        const OrDivider(),
        KInput(hint: 'Ketik kecamatan atau kota', icon: LucideIcons.search, iconColor: AppColors.faint, onChanged: (v) => v.length > 3 ? c.setArea(v) : null),
        KCard(
          color: AppColors.blueL,
          border: AppColors.blueM,
          child: Row(children: [
            const Icon(LucideIcons.mapPin, size: 22, color: AppColors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.area, style: AppText.custom(16)),
                Text('Benar ini lokasimu?', style: AppText.custom(13, w: FontWeight.w700, c: AppColors.muted)),
              ]),
            ),
            Text('UBAH', style: AppText.custom(14, c: AppColors.blue)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('Jarak cari'),
          const SizedBox(height: 8),
          Row(children: [
            for (final km in const [5, 10, 20]) ...[
              Expanded(child: KChip('$km km', selected: d.radiusKm == km, expand: true, onTap: () => c.setRadius(km))),
              if (km != 20) const SizedBox(width: 8),
            ],
          ]),
        ]),
      ],
    );
  }
}
