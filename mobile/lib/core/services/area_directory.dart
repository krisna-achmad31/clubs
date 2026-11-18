import 'dart:convert';

import 'package:http/http.dart' as http;

import 'location_service.dart';

class District {
  const District({
    required this.code,
    required this.name,
    required this.city,
    required this.province,
    required this.center,
  });

  final String code;
  final String name;
  final String city;
  final String province;
  final GeoPoint? center;

  String get label => '$name, $city';
}

typedef DistrictsNear = ({District? current, List<District> nearby});

class AreaDirectory {
  AreaDirectory(this._client);

  final http.Client _client;

  static final _endpoint = Uri.https(
    'geoservices.big.go.id',
    '/rbi/rest/services/BATASWILAYAH/BATAS_KECAMATAN_AR/MapServer/0/query',
  );

  Future<DistrictsNear> near(GeoPoint origin) async {
    final spatial = {
      'geometry':
          '${origin.lng.toStringAsFixed(5)},${origin.lat.toStringAsFixed(5)}',
      'geometryType': 'esriGeometryPoint',
      'inSR': '4326',
      'spatialRel': 'esriSpatialRelIntersects',
    };
    final results = await Future.wait([
      _query(spatial, limit: 5),
      _query({
        ...spatial,
        'distance': '15',
        'units': 'esriSRUnit_Kilometer',
      }, limit: 100),
    ]);
    final current = results.first.firstOrNull;
    final byCode = {for (final area in results.last) area.code: area};
    if (current != null) byCode[current.code] = current;
    final areas = byCode.values.toList();
    // The intersecting district comes first, followed by centers closest to GPS.
    final location = LocationService();
    double distance(District district) => district.center == null
        ? double.infinity
        : location.distanceMeters(origin, district.center!);
    areas.sort((a, b) {
      if (a.code == current?.code) return b.code == a.code ? 0 : -1;
      if (b.code == current?.code) return 1;
      final order = distance(a).compareTo(distance(b));
      return order == 0 ? a.label.compareTo(b.label) : order;
    });
    return (current: current, nearby: areas.take(25).toList());
  }

  Future<List<District>> search(String query) async {
    final words = query.trim().toUpperCase().split(',');
    final filters = [
      for (final word in words)
        if (word.trim().isNotEmpty)
          _searchFilter(
            word
                .trim()
                .replaceAll("'", "''")
                .replaceAll('%', ' ')
                .replaceAll('_', ' '),
          ),
    ];
    if (filters.isEmpty) return const [];
    final districts = await _query(
      {'where': filters.join(' AND ')},
      limit: 40,
      geometry: false,
    );
    return districts..sort((a, b) => a.label.compareTo(b.label));
  }

  Future<GeoPoint?> centerFor(District district) async {
    if (district.center != null) return district.center;
    if (!RegExp(r'^[0-9.]+$').hasMatch(district.code)) return null;
    final results = await _query(
      {'where': "KDCPUM = '${district.code}'"},
      limit: 1,
    );
    return results.firstOrNull?.center;
  }

  static String _searchFilter(String term) =>
      "(UPPER(WADMKC) LIKE '%$term%' OR UPPER(WADMKK) LIKE '%$term%')";

  Future<List<District>> _query(
    Map<String, String> filters, {
    required int limit,
    bool geometry = true,
  }) async {
    final response = await _client
        .get(
          _endpoint.replace(
            queryParameters: {
              'f': 'json',
              'outFields': 'KDCPUM,WADMKC,WADMKK,WADMPR',
              'returnGeometry': '$geometry',
              if (geometry) ...{
                'outSR': '4326',
                'maxAllowableOffset': '0.002',
                'geometryPrecision': '5',
              },
              'resultRecordCount': '$limit',
              ...filters,
            },
          ),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw const FormatException('Layanan wilayah tidak tersedia');
    }
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map || payload['features'] is! List) {
      throw const FormatException('Respons layanan wilayah tidak valid');
    }
    final byCode = <String, District>{};
    for (final feature in payload['features'] as List) {
      if (feature is! Map || feature['attributes'] is! Map) continue;
      final attributes = feature['attributes'] as Map;
      final name = (attributes['WADMKC'] as String?)?.trim() ?? '';
      final city = (attributes['WADMKK'] as String?)?.trim() ?? '';
      final province = (attributes['WADMPR'] as String?)?.trim() ?? '';
      if (name.isEmpty || city.isEmpty) continue;
      final code = (attributes['KDCPUM'] as String?)?.trim();
      final id = code == null || code.isEmpty ? '$name,$city,$province' : code;
      byCode[id] = District(
        code: id,
        name: name,
        city: city,
        province: province,
        center: _center(feature['geometry']),
      );
    }
    return byCode.values.toList();
  }

  // Use the bounding-box midpoint of the largest ring as a district reference
  // point, so small offshore islands do not pull the point away from the area.
  static GeoPoint? _center(Object? geometry) {
    if (geometry is! Map || geometry['rings'] is! List) return null;
    GeoPoint? center;
    double largest = 0;
    for (final ring in geometry['rings'] as List) {
      if (ring is! List || ring.length < 4) continue;
      var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
      for (final vertex in ring) {
        if (vertex is! List ||
            vertex.length < 2 ||
            vertex[0] is! num ||
            vertex[1] is! num) {
          continue;
        }
        final lng = (vertex[0] as num).toDouble();
        final lat = (vertex[1] as num).toDouble();
        if (!lng.isFinite ||
            !lat.isFinite ||
            lng.abs() > 180 ||
            lat.abs() > 90) {
          continue;
        }
        if (lat < south) south = lat;
        if (lat > north) north = lat;
        if (lng < west) west = lng;
        if (lng > east) east = lng;
      }
      if (south >= north || west >= east) continue;
      final size = (north - south) * (east - west);
      if (size > largest) {
        largest = size;
        center = GeoPoint((south + north) / 2, (west + east) / 2);
      }
    }
    return center;
  }

  void close() => _client.close();
}
