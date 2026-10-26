import 'package:geolocator/geolocator.dart';

Position testPosition({
  double lat = -6.2903,
  double lng = 106.7979,
  DateTime? at,
  double accuracy = 15,
}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: at ?? DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class FakeLocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.denied;
  Position? position = testPosition();
  Position? cached;
  Exception? serviceError;
  Exception? positionError;
  Exception? cacheError;
  int requests = 0;
  int fixes = 0;
  int settingsOpened = 0;
  int appSettingsOpened = 0;

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (serviceError != null) throw serviceError!;
    return enabled;
  }

  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    fixes++;
    if (positionError != null) throw positionError!;
    return position!;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    if (cacheError != null) throw cacheError!;
    return cached;
  }

  @override
  Future<bool> openLocationSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }
}
