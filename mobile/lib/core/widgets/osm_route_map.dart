import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/activity/domain/entities/activity_sample.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Geographic route; normalized illustration coordinates are never geolocated.
class OsmRouteMap extends StatefulWidget {
  const OsmRouteMap({
    super.key,
    required this.samples,
    this.height = 150,
    this.radius = 20,
    this.interactive = false,
    this.children = const [],
  });
  final List<ActivitySample> samples;
  final double height, radius;
  final bool interactive;
  final List<Widget> children;

  static List<LatLng> coordinates(List<ActivitySample> samples) => [
    for (final s in samples)
      if (s.latitude?.isFinite == true &&
          s.longitude?.isFinite == true &&
          s.latitude!.abs() <= 90 &&
          s.longitude!.abs() <= 180)
        LatLng(s.latitude!, s.longitude!),
  ];

  @override
  State<OsmRouteMap> createState() => _OsmRouteMapState();
}

class _OsmRouteMapState extends State<OsmRouteMap> {
  final _controller = MapController();
  List<ActivitySample> get samples => widget.samples;
  double get height => widget.height;
  double get radius => widget.radius;
  bool get interactive => widget.interactive;
  List<Widget> get children => widget.children;

  @override
  void didUpdateWidget(covariant OsmRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.samples == samples) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final points = OsmRouteMap.coordinates(samples);
      if (points.isEmpty) return;
      if (points.length > 1 && points.any((p) => p != points.first)) {
        _controller.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(28),
            maxZoom: 17,
          ),
        );
      } else {
        _controller.move(points.first, 16);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = OsmRouteMap.coordinates(samples);
    final hasSpan = points.length > 1 && points.any((p) => p != points.first);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (points.isEmpty)
              ColoredBox(
                color: AppColors.soft,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Koordinat GPS belum tersedia',
                      style: AppText.bodySm(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: points.first,
                  initialZoom: 16,
                  initialCameraFit: hasSpan
                      ? CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(points),
                          padding: const EdgeInsets.all(28),
                          maxZoom: 17,
                        )
                      : null,
                  interactionOptions: InteractionOptions(
                    flags: interactive
                        ? InteractiveFlag.all & ~InteractiveFlag.rotate
                        : InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: const String.fromEnvironment(
                      'OSM_TILE_URL',
                      defaultValue:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    userAgentPackageName: 'id.klubby.app',
                    panBuffer: 0,
                    errorTileCallback: (_, _, _) {},
                  ),
                  if (points.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          color: AppColors.orange,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: points.first,
                        width: 18,
                        height: 18,
                        child: _dot(AppColors.primary),
                      ),
                      if (points.length > 1)
                        Marker(
                          point: points.last,
                          width: 18,
                          height: 18,
                          child: _dot(AppColors.red),
                        ),
                    ],
                  ),
                ],
              ),
            ...children,
            if (points.isNotEmpty)
              Positioned(
                right: 4,
                bottom: 2,
                child: Material(
                  color: AppColors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: Text(
                        '© OpenStreetMap contributors',
                        style: AppText.micro(AppColors.ink),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.white, width: 2),
    ),
  );
}
