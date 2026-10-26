import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_analysis.dart';

String _pace(double? seconds) => seconds == null
    ? '—'
    : '${seconds.round() ~/ 60}:${(seconds.round() % 60).toString().padLeft(2, '0')} /km';

/// Detailed sensor data within the existing activity post, using Klubby widgets.
class ActivityDataSections extends StatelessWidget {
  const ActivityDataSections({
    super.key,
    required this.activity,
    this.owner = false,
  });
  final Activity activity;
  final bool owner;

  @override
  Widget build(BuildContext context) {
    final data = ActivityAnalysis(activity);
    final cadenceUnit = const {'sepeda', 'mtb'}.contains(activity.sportId)
        ? 'rpm'
        : 'spm';
    String sensor(double? value, String unit) =>
        value == null ? '—' : '${value.round()} $unit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        KCard(
          child: Column(
            spacing: 12,
            children: [
              for (final (label, value) in [
                ('Waktu bergerak', Fmt.clock(activity.duration)),
                ('Total waktu', Fmt.clock(data.elapsed)),
                if (activity.score?.isNotEmpty == true)
                  ('Skor', activity.score!),
                if (activity.distanceKm > 0)
                  ('Pace rata-rata', _pace(data.averagePace)),
                if (activity.distanceKm > 0)
                  ('Pace termasuk jeda', _pace(data.elapsedPace)),
                if (activity.distanceKm > 0)
                  ('Split tercepat', _pace(data.fastestSplit)),
                if (activity.device?.isNotEmpty == true)
                  ('Perangkat', activity.device!),
                (
                  'Sumber',
                  switch (activity.source.name) {
                    'gps' => 'GPS ponsel',
                    'wearable' => 'Perangkat terhubung',
                    'qr' => 'Check-in QR',
                    'manual' => 'Catatan manual',
                    _ => 'Goyang',
                  },
                ),
              ])
                _MetricRow(label, value),
            ],
          ),
        ),
        if (activity.sport.tracksDistance ||
            data.series(ActivityMetric.elevation).isNotEmpty)
          ActivityMetricChart(
            title: 'Elevasi',
            points: data.series(ActivityMetric.elevation),
            color: AppColors.muted,
            distanceAxis: data.distanceAxis,
            format: (v) => '${v.round()} m',
            empty: 'Data elevasi belum terekam pada aktivitas ini.',
            summaries: [
              ('Kenaikan elevasi GPS', sensor(data.elevationGain, 'm')),
            ],
          ),
        if (!activity.hideHr || owner)
          ActivityMetricChart(
            title: 'Detak jantung',
            points: data.series(ActivityMetric.heartRate),
            color: AppColors.red,
            distanceAxis: data.distanceAxis,
            format: (v) => '${v.round()} bpm',
            empty: data.averageHeartRate == null
                ? 'Belum ada data detak jantung dari perangkat terhubung.'
                : 'Aktivitas ini hanya menyimpan rata-rata detak jantung, tanpa grafik.',
            summaries: [
              ('Rata-rata', sensor(data.averageHeartRate, 'bpm')),
              ('Maksimum', sensor(data.maxHeartRate, 'bpm')),
            ],
          ),
        if (activity.distanceKm > 0)
          ActivityMetricChart(
            title: 'Pace',
            points: data.series(ActivityMetric.pace),
            color: AppColors.primary,
            distanceAxis: data.distanceAxis,
            inverted: true,
            format: (v) => _pace(v),
            empty:
                'Grafik pace memerlukan rangkaian titik GPS bertanggal waktu.',
            summaries: [
              ('Pace rata-rata', _pace(data.averagePace)),
              ('Pace termasuk jeda', _pace(data.elapsedPace)),
            ],
          ),
        if (activity.sport.tracksDistance ||
            data.series(ActivityMetric.cadence).isNotEmpty)
          ActivityMetricChart(
            title: 'Cadence',
            points: data.series(ActivityMetric.cadence),
            color: AppColors.purple,
            distanceAxis: data.distanceAxis,
            format: (v) => '${v.round()} $cadenceUnit',
            empty: 'Belum ada data cadence. Data berasal dari jam atau catatan langkah Health Connect / Apple Health.',
            summaries: [
              ('Rata-rata', sensor(data.averageCadence, cadenceUnit)),
              ('Maksimum', sensor(data.maxCadence, cadenceUnit)),
            ],
          ),
        if (data.splits.isNotEmpty)
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text('Split per km', style: AppText.cardTitle()),
                for (final (i, split) in data.splits.indexed)
                  _MetricRow(
                    split.km >= .999
                        ? 'Km ${i + 1}'
                        : '${Fmt.dec(split.km)} km terakhir',
                    _pace(split.pace),
                  ),
              ],
            ),
          ),
        if (activity.note.isNotEmpty)
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text('Catatan', style: AppText.cardTitle()),
                Text(activity.note, style: AppText.body()),
              ],
            ),
          ),
        if (activity.photos.isNotEmpty)
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: activity.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(activity.photos[i]),
                  width: 170,
                  height: 170,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 170,
                    color: AppColors.soft,
                    alignment: Alignment.center,
                    child: Text('Foto tidak tersedia', style: AppText.bodySm()),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: AppText.bodySm())),
      const SizedBox(width: 12),
      Flexible(
        child: Text(value, textAlign: TextAlign.right, style: AppText.name()),
      ),
    ],
  );
}

class ActivityMetricChart extends StatefulWidget {
  const ActivityMetricChart({
    super.key,
    required this.title,
    required this.points,
    required this.color,
    required this.distanceAxis,
    required this.format,
    required this.empty,
    this.summaries = const [],
    this.inverted = false,
  });
  final String title, empty;
  final List<MetricPoint> points;
  final Color color;
  final bool distanceAxis, inverted;
  final String Function(double) format;
  final List<(String, String)> summaries;
  @override
  State<ActivityMetricChart> createState() => _ActivityMetricChartState();
}

class _ActivityMetricChartState extends State<ActivityMetricChart> {
  int? _selected;
  void _pick(double x, double width) {
    if (widget.points.isEmpty || width <= 0) return;
    final maxX = widget.points.last.x;
    final at = (x / width).clamp(0.0, 1.0) * maxX;
    var index = 0;
    for (var i = 1; i < widget.points.length; i++) {
      if ((widget.points[i].x - at).abs() <
          (widget.points[index].x - at).abs()) {
        index = i;
      }
    }
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final index = _selected == null || points.isEmpty
        ? null
        : _selected!.clamp(0, points.length - 1);
    final selected = index == null ? null : points[index];
    String position(MetricPoint p) =>
        '${Fmt.dec(p.x)} ${widget.distanceAxis ? 'km' : 'menit'}';
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(widget.title, style: AppText.cardTitle()),
          if (points.isEmpty)
            Text(widget.empty, style: AppText.bodySm())
          else ...[
            Text(
              selected == null
                  ? 'Sentuh atau geser grafik untuk melihat detail.'
                  : '${widget.format(selected.value)} · ${position(selected)}',
              key: ValueKey('metric-reading-${widget.title}'),
              style: AppText.custom(
                13,
                c: selected == null ? AppColors.muted : widget.color,
              ),
            ),
            LayoutBuilder(
              builder: (_, constraints) => Semantics(
                label: 'Grafik ${widget.title}',
                slider: true,
                value: selected == null
                    ? '${points.length} titik data'
                    : '${widget.format(selected.value)}, ${position(selected)}',
                onIncrease: () => setState(
                  () => _selected = ((index ?? -1) + 1).clamp(
                    0,
                    points.length - 1,
                  ),
                ),
                onDecrease: () => setState(
                  () => _selected = ((index ?? 1) - 1).clamp(
                    0,
                    points.length - 1,
                  ),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (event) =>
                      _pick(event.localPosition.dx, constraints.maxWidth),
                  onHorizontalDragStart: (event) =>
                      _pick(event.localPosition.dx, constraints.maxWidth),
                  onHorizontalDragUpdate: (event) =>
                      _pick(event.localPosition.dx, constraints.maxWidth),
                  child: SizedBox(
                    height: 156,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _MetricPainter(
                        points,
                        widget.color,
                        index,
                        widget.inverted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: AppText.caption()),
                Text(position(points.last), style: AppText.caption()),
              ],
            ),
          ],
          for (final (label, value) in widget.summaries)
            _MetricRow(label, value),
        ],
      ),
    );
  }
}

class _MetricPainter extends CustomPainter {
  const _MetricPainter(this.points, this.color, this.selected, this.inverted);
  final List<MetricPoint> points;
  final Color color;
  final int? selected;
  final bool inverted;
  @override
  void paint(Canvas canvas, Size size) {
    final minimum = points.map((p) => p.value).reduce(math.min);
    final maximum = points.map((p) => p.value).reduce(math.max);
    final span = math.max(maximum - minimum, 1.0);
    final maxX = math.max(points.last.x, 1e-9);
    Offset offset(MetricPoint point) {
      final y = (point.value - minimum) / span;
      return Offset(
        point.x / maxX * size.width,
        8 + (inverted ? y : 1 - y) * (size.height - 16),
      );
    }

    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final line = Path(), fill = Path()..moveTo(0, size.height);
    // Keep painting bounded for long recordings; full resolution stays saved.
    final step = math.max(1, (points.length / 600).ceil());
    var first = true;
    for (var i = 0; i < points.length; i += step) {
      final p = offset(points[i]);
      if (first) {
        line.moveTo(p.dx, p.dy);
        first = false;
      } else {
        line.lineTo(p.dx, p.dy);
      }
      fill.lineTo(p.dx, p.dy);
    }
    final last = offset(points.last);
    line.lineTo(last.dx, last.dy);
    fill.lineTo(last.dx, last.dy);
    fill.lineTo(last.dx, size.height);
    fill.close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: .22));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    if (selected != null) {
      final p = offset(points[selected!]);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()
          ..color = AppColors.ink.withValues(alpha: .5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(p, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _MetricPainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.color != color ||
      old.inverted != inverted;
}
