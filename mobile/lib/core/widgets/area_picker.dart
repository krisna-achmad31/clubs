import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'basics.dart';
import 'chunky.dart';

/// A kecamatan the user can pick for clubs, mabar and "near me".
class Area {
  const Area(this.name, this.city, this.lat, this.lng);

  final String name;
  final String city;
  final double lat;
  final double lng;

  String get label => '$name, $city';

  double _distSq(double la, double ln) {
    final dy = lat - la;
    final dx = (lng - ln) * math.cos(la * math.pi / 180);
    return dx * dx + dy * dy;
  }
}

abstract final class Areas {
  static const all = [
    Area('Kebayoran Baru', 'Jakarta Selatan', -6.2433, 106.7997),
    Area('Kebayoran Lama', 'Jakarta Selatan', -6.2449, 106.7791),
    Area('Cilandak', 'Jakarta Selatan', -6.2903, 106.7979),
    Area('Pasar Minggu', 'Jakarta Selatan', -6.2836, 106.8441),
    Area('Mampang Prapatan', 'Jakarta Selatan', -6.2425, 106.8237),
    Area('Setiabudi', 'Jakarta Selatan', -6.2183, 106.8294),
    Area('Tebet', 'Jakarta Selatan', -6.2265, 106.8566),
    Area('Pancoran', 'Jakarta Selatan', -6.2513, 106.8442),
    Area('Jagakarsa', 'Jakarta Selatan', -6.3342, 106.8236),
    Area('Pesanggrahan', 'Jakarta Selatan', -6.2445, 106.7586),
    Area('Menteng', 'Jakarta Pusat', -6.1960, 106.8320),
    Area('Tanah Abang', 'Jakarta Pusat', -6.2017, 106.8130),
    Area('Gambir', 'Jakarta Pusat', -6.1767, 106.8219),
    Area('Kemayoran', 'Jakarta Pusat', -6.1612, 106.8566),
    Area('Senen', 'Jakarta Pusat', -6.1777, 106.8443),
    Area('Kebon Jeruk', 'Jakarta Barat', -6.1928, 106.7698),
    Area('Palmerah', 'Jakarta Barat', -6.2075, 106.7963),
    Area('Grogol Petamburan', 'Jakarta Barat', -6.1631, 106.7896),
    Area('Kembangan', 'Jakarta Barat', -6.1885, 106.7409),
    Area('Cengkareng', 'Jakarta Barat', -6.1503, 106.7356),
    Area('Jatinegara', 'Jakarta Timur', -6.2250, 106.8700),
    Area('Duren Sawit', 'Jakarta Timur', -6.2346, 106.9158),
    Area('Cakung', 'Jakarta Timur', -6.1859, 106.9395),
    Area('Pulo Gadung', 'Jakarta Timur', -6.1912, 106.8960),
    Area('Kramat Jati', 'Jakarta Timur', -6.2700, 106.8680),
    Area('Kelapa Gading', 'Jakarta Utara', -6.1601, 106.9055),
    Area('Penjaringan', 'Jakarta Utara', -6.1263, 106.7920),
    Area('Tanjung Priok', 'Jakarta Utara', -6.1324, 106.8714),
    Area('Pademangan', 'Jakarta Utara', -6.1311, 106.8379),
    Area('Serpong', 'Tangerang Selatan', -6.3176, 106.6650),
    Area('Pondok Aren', 'Tangerang Selatan', -6.2720, 106.7090),
    Area('Ciputat', 'Tangerang Selatan', -6.3110, 106.7580),
    Area('Karawaci', 'Tangerang', -6.2240, 106.6100),
    Area('Beji', 'Depok', -6.3740, 106.8150),
    Area('Pancoran Mas', 'Depok', -6.3990, 106.8130),
    Area('Bekasi Selatan', 'Bekasi', -6.2490, 106.9960),
    Area('Bekasi Barat', 'Bekasi', -6.2300, 106.9800),
    Area('Bogor Tengah', 'Bogor', -6.5950, 106.7970),
    Area('Coblong', 'Bandung', -6.8870, 107.6130),
    Area('Sukajadi', 'Bandung', -6.8870, 107.5960),
    Area('Gubeng', 'Surabaya', -7.2750, 112.7500),
    Area('Wonokromo', 'Surabaya', -7.3000, 112.7380),
    Area('Gondokusuman', 'Yogyakarta', -7.7830, 110.3820),
    Area('Semarang Tengah', 'Semarang', -6.9800, 110.4180),
    Area('Medan Baru', 'Medan', 3.5740, 98.6560),
    Area('Denpasar Selatan', 'Denpasar', -8.6900, 115.2200),
    Area('Panakkukang', 'Makassar', -5.1500, 119.4500),
  ];

  static Area nearest(double lat, double lng) =>
      all.reduce((a, b) => a._distSq(lat, lng) <= b._distSq(lat, lng) ? a : b);

  /// The local list is incomplete. Do not assign a distant city as the user's area.
  static Area? nearby(double lat, double lng, {double maxDistanceKm = 25}) {
    if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    final area = nearest(lat, lng);
    return area._distSq(lat, lng) * 111.195 * 111.195 <=
            maxDistanceKm * maxDistanceKm
        ? area
        : null;
  }

  /// Finds an area by name or "name, city"; null for free-typed areas.
  static Area? find(String text) {
    final t = text.toLowerCase();
    for (final a in all) {
      if (t == a.name.toLowerCase() ||
          t == a.label.toLowerCase() ||
          t.startsWith('${a.name.toLowerCase()},')) {
        return a;
      }
    }
    return null;
  }
}

/// Sheet: GPS → nearest kecamatan, or search the list, or use what was typed.
/// Returns the picked label ("Kebayoran Baru, Jakarta Selatan").
Future<String?> showAreaPicker(BuildContext context, {String? current}) =>
    showKSheet<String>(context, (_) => _AreaSheet(current: current));

class _AreaSheet extends StatefulWidget {
  const _AreaSheet({this.current});

  final String? current;

  @override
  State<_AreaSheet> createState() => _AreaSheetState();
}

class _AreaSheetState extends State<_AreaSheet> {
  final _location = LocationService();
  String _q = '';
  bool _locating = false;
  String? _error;
  Area? _suggestion;

  Future<void> _locate() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _error = null;
      _suggestion = null;
    });
    try {
      final p = await _location.current();
      if (!mounted) return;
      final area = p == null ? null : Areas.nearby(p.lat, p.lng);
      setState(() {
        _suggestion = area;
        _error = p == null
            ? _location.failureMessage
            : area == null
            ? 'Lokasi terbaca, tetapi area ini belum ada di daftar. Cari atau ketik kecamatanmu.'
            : null;
      });
    } on Exception {
      if (mounted) {
        setState(
          () => _error = 'Lokasi belum bisa dibaca. Coba lagi atau pilih area secara manual.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openSettings() async {
    try {
      final opened = _location.issue == LocationIssue.permissionDeniedForever
          ? await _location.openAppSettings()
          : await _location.openSettings();
      if (mounted && !opened) {
        setState(
          () => _error = 'Pengaturan tidak bisa dibuka. Buka pengaturan lokasi perangkat secara manual.',
        );
      }
    } on Exception {
      if (mounted) {
        setState(
          () => _error = 'Buka pengaturan perangkat untuk mengaktifkan GPS dan izin lokasi Klubby.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? Areas.all
        : Areas.all.where((a) => a.label.toLowerCase().contains(q)).toList();
    final selected = widget.current == null
        ? null
        : Areas.find(widget.current!);
    return KSheet(
      children: [
        Text('Pilih area', style: AppText.title()),
        KButton(
          'PAKAI LOKASI SEKARANG',
          icon: LucideIcons.locateFixed,
          loading: _locating,
          onTap: _locating ? null : _locate,
        ),
        if (_error != null) KBanner.error(_error!),
        if (_error != null &&
            (_location.issue == LocationIssue.serviceDisabled ||
                _location.issue == LocationIssue.permissionDeniedForever))
          KButton.secondary(
            'BUKA PENGATURAN',
            icon: LucideIcons.settings,
            onTap: _openSettings,
          ),
        if (_suggestion case final area?) ...[
          KBanner.info(
            'Perkiraan area terdekat: ${area.label}. Pastikan kecamatannya sesuai; daftar area belum lengkap.',
          ),
          KButton(
            'PAKAI AREA INI',
            icon: LucideIcons.check,
            onTap: () => Navigator.pop(context, area.label),
          ),
        ],
        KInput(
          hint: 'Cari kecamatan atau kota',
          icon: LucideIcons.search,
          iconColor: AppColors.faint,
          onChanged: (v) => setState(() => _q = v),
        ),
        if (list.isEmpty && q.length >= 3)
          KRow(
            icon: LucideIcons.plus,
            title: 'Pakai "${_q.trim()}"',
            subtitle: 'Area belum ada di daftar',
            onTap: () => Navigator.pop(context, _q.trim()),
          ),
        for (final a in list)
          KRow(
            icon: LucideIcons.mapPin,
            iconBg: a == selected ? AppColors.primary : AppColors.primaryL,
            iconFg: a == selected ? AppColors.white : AppColors.primary,
            title: a.name,
            subtitle: a.city,
            trailing: a == selected
                ? const Icon(LucideIcons.check, color: AppColors.primary)
                : null,
            padding: const EdgeInsets.symmetric(vertical: 6),
            onTap: () => Navigator.pop(context, a.label),
          ),
      ],
    );
  }
}
