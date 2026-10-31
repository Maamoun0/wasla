import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// A rounded position for "near me" (about 1 km), so the exact location of
/// the user never leaves the device.
class ApproxLocation {
  const ApproxLocation(this.lat, this.lng);
  final double lat;
  final double lng;

  factory ApproxLocation.round(double lat, double lng) =>
      ApproxLocation((lat * 100).roundToDouble() / 100, (lng * 100).roundToDouble() / 100);
}

/// Why no location could be read, to tell the user what to do.
enum LocationIssue { serviceOff, denied, deniedForever, unavailable }

class LocationResult {
  const LocationResult.found(ApproxLocation this.location) : issue = null;
  const LocationResult.failed(LocationIssue this.issue) : location = null;
  final ApproxLocation? location;
  final LocationIssue? issue;

  String? get message => switch (issue) {
        LocationIssue.serviceOff => 'شغّل خدمة الموقع في الموبايل عشان نعرضلك الأقرب.',
        LocationIssue.denied => 'محتاجين إذن الموقع عشان نعرضلك الإعلانات القريبة.',
        LocationIssue.deniedForever => 'إذن الموقع مقفول. فعّله من إعدادات التطبيق.',
        LocationIssue.unavailable => 'تعذّر تحديد موقعك. حاول مرة أخرى.',
        null => null,
      };
}

/// Asks for permission only when called (the user tapped "near me").
Future<LocationResult> readApproxLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) return const LocationResult.failed(LocationIssue.serviceOff);
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.deniedForever) return const LocationResult.failed(LocationIssue.deniedForever);
  if (permission == LocationPermission.denied) return const LocationResult.failed(LocationIssue.denied);
  try {
    // geolocator 12 API (the project's pinned version).
    final p = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 10),
    );
    return LocationResult.found(ApproxLocation.round(p.latitude, p.longitude));
  } catch (_) {
    return const LocationResult.failed(LocationIssue.unavailable);
  }
}

/// Overridable in tests.
final locationReaderProvider = Provider<Future<LocationResult> Function()>((ref) => readApproxLocation);
