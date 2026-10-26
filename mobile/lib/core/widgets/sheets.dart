import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../entities/sport.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'basics.dart';
import 'chunky.dart';
import 'page.dart';

/// Yes/no sheet for destructive or money actions. Resolves to true on confirm.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? body,
  required String confirm,
  String cancel = 'Nggak jadi',
  Hue hue = Hue.red,
  IconData icon = LucideIcons.triangleAlert,
}) async {
  final ok = await showKSheet<bool>(
    context,
    (ctx) => KSheet(children: [
      Center(child: IconBox(icon, bg: hue.light, fg: hue.base, size: 64, iconSize: 30, radius: 20)),
      Text(title, textAlign: TextAlign.center, style: AppText.h2()),
      if (body != null) Text(body, textAlign: TextAlign.center, style: AppText.custom(15, w: FontWeight.w800, c: AppColors.muted, h: 1.35)),
      KActions([
        KButton(confirm, hue: hue, onTap: () => Navigator.pop(ctx, true)),
        KLink(cancel, color: AppColors.muted, onTap: () => Navigator.pop(ctx, false)),
      ]),
    ]),
  );
  return ok ?? false;
}

/// Lightweight profile of another member (feed authors, club members, rankings).
Future<void> showUserSheet(
  BuildContext context, {
  required String name,
  String? subtitle,
  Color color = AppColors.primary,
  String? sportId,
  List<(String, String)> stats = const [],
}) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  final initials = parts.isEmpty ? '?' : (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
  final sport = sportId == null ? null : Sports.byId(sportId);
  var following = false;
  return showKSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => KSheet(children: [
        Row(children: [
          LetterAvatar(initials, color: color, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: AppText.custom(20), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null) Text(subtitle, style: AppText.custom(14, w: FontWeight.w800, c: AppColors.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (sport != null) ...[
                const SizedBox(height: 6),
                KPill('${sport.emoji} ${sport.name}', bg: sport.hue.light, fg: sport.hue.dark),
              ],
            ]),
          ),
        ]),
        if (stats.isNotEmpty)
          KSplit(gap: 8, [
            for (final (value, label) in stats)
              KCard(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: Column(children: [
                  Text(value, style: AppText.custom(18), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(label, style: AppText.custom(11, c: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
          ]),
        KButton(
          following ? 'DIIKUTI ✓' : 'IKUTI',
          kind: following ? BtnKind.secondary : BtnKind.primary,
          onTap: () {
            set(() => following = !following);
            toast(context, following ? 'Kamu mengikuti $name' : 'Berhenti mengikuti $name');
          },
        ),
      ]),
    ),
  );
}

/// Searchable list of all sports. Returns the picked one.
Future<Sport?> showSportPicker(BuildContext context, {String? selectedId, Set<String> exclude = const {}, String title = 'Pilih olahraga'}) =>
    showKSheet<Sport>(context, (_) => _SportSheet(selectedId: selectedId, exclude: exclude, title: title));

class _SportSheet extends StatefulWidget {
  const _SportSheet({this.selectedId, required this.exclude, required this.title});

  final String? selectedId;
  final Set<String> exclude;
  final String title;

  @override
  State<_SportSheet> createState() => _SportSheetState();
}

class _SportSheetState extends State<_SportSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = Sports.all.where((s) => !widget.exclude.contains(s.id) && (q.isEmpty || s.name.toLowerCase().contains(q) || s.category.label.toLowerCase().contains(q))).toList();
    return KSheet(gap: 10, children: [
      Text(widget.title, style: AppText.title()),
      KInput(hint: 'Cari dari ${Sports.all.length} olahraga…', icon: LucideIcons.search, onChanged: (v) => setState(() => _q = v)),
      if (list.isEmpty) KBanner.info('Olahraga "${_q.trim()}" belum ada.'),
      for (final s in list)
        KRow(
          icon: s.icon,
          iconBg: s.id == widget.selectedId ? s.hue.base : s.hue.light,
          iconFg: s.id == widget.selectedId ? AppColors.white : s.hue.dark,
          title: s.name,
          subtitle: s.category.label,
          trailing: s.id == widget.selectedId ? const Icon(LucideIcons.check, color: AppColors.primary) : null,
          padding: const EdgeInsets.symmetric(vertical: 4),
          onTap: () => Navigator.pop(context, s),
        ),
    ]);
  }
}

/// A court/venue the user can pick for mabar, goyang and hosting.
class Venue {
  const Venue(this.id, this.name, this.area, {this.pricePerHour = 0});

  final String id;
  final String name;
  final String area;
  final int pricePerHour;
}

abstract final class Venues {
  static const all = [
    Venue('gor-senayan', 'GOR Senayan Badminton', 'Gelora, Jakarta Pusat', pricePerHour: 64000),
    Venue('gor-mahakam', 'GOR Mahakam', 'Kebayoran Baru, Jakarta Selatan', pricePerHour: 55000),
    Venue('gor-bulungan', 'GOR Bulungan', 'Kebayoran Baru, Jakarta Selatan', pricePerHour: 60000),
    Venue('gor-tebet', 'GOR Tebet', 'Tebet, Jakarta Selatan', pricePerHour: 50000),
    Venue('padel-pim', 'Padel Pondok Indah', 'Kebayoran Lama, Jakarta Selatan', pricePerHour: 350000),
    Venue('futsal-kuningan', 'Futsal Kuningan Arena', 'Setiabudi, Jakarta Selatan', pricePerHour: 250000),
    Venue('kolam-senayan', 'Aquatic Center Senayan', 'Gelora, Jakarta Pusat', pricePerHour: 40000),
    Venue('gbk-track', 'Track Lari GBK', 'Gelora, Jakarta Pusat'),
  ];

  static Venue byId(String? id) => all.firstWhere((v) => v.id == id, orElse: () => all.first);

  static Venue? byName(String name) => all.where((v) => v.name == name).firstOrNull;
}

/// Venue list with search; free-typed names are allowed too. Returns the venue name.
Future<String?> showVenuePicker(BuildContext context, {String? current}) => showKSheet<String>(context, (_) => _VenueSheet(current: current));

class _VenueSheet extends StatefulWidget {
  const _VenueSheet({this.current});

  final String? current;

  @override
  State<_VenueSheet> createState() => _VenueSheetState();
}

class _VenueSheetState extends State<_VenueSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = Venues.all.where((v) => q.isEmpty || v.name.toLowerCase().contains(q) || v.area.toLowerCase().contains(q)).toList();
    return KSheet(gap: 10, children: [
      Text('Pilih lokasi', style: AppText.title()),
      KInput(hint: 'Cari GOR, lapangan, area', icon: LucideIcons.search, onChanged: (v) => setState(() => _q = v)),
      if (q.length >= 3 && list.isEmpty)
        KRow(icon: LucideIcons.plus, title: 'Pakai "${_q.trim()}"', subtitle: 'Lokasi belum ada di daftar', onTap: () => Navigator.pop(context, _q.trim())),
      for (final v in list)
        KRow(
          icon: LucideIcons.mapPin,
          iconBg: v.name == widget.current ? AppColors.primary : AppColors.primaryL,
          iconFg: v.name == widget.current ? AppColors.white : AppColors.primary,
          title: v.name,
          subtitle: v.area,
          trailing: v.name == widget.current ? const Icon(LucideIcons.check, color: AppColors.primary) : null,
          padding: const EdgeInsets.symmetric(vertical: 4),
          onTap: () => Navigator.pop(context, v.name),
        ),
    ]);
  }
}

/// Date then time picker in one go. Null when either is dismissed.
Future<DateTime?> pickDateTime(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) async {
  final now = DateTime.now();
  final init = initial ?? now;
  final d = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: first ?? now.subtract(const Duration(days: 1)),
    lastDate: last ?? now.add(const Duration(days: 90)),
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(init));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}
