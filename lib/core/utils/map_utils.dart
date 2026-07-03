import 'package:latlong2/latlong.dart';
import '../../data/models/road_reading.dart';

class MapUtils {
  static bool isValidCoordinate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    return true;
  }

  static List<LatLng> filterValidRoutePoints(List<RoadReading> readings) {
    return readings
        .where((r) => isValidCoordinate(r.latitude, r.longitude))
        .map((r) => LatLng(r.latitude!, r.longitude!))
        .toList();
  }

  static List<LatLng> downsampleRoutePoints(List<LatLng> points, {int maxPoints = 1000}) {
    if (points.length <= maxPoints) return points;
    if (maxPoints <= 0) return [];
    
    final double step = points.length / maxPoints;
    final List<LatLng> result = [];
    
    for (int i = 0; i < maxPoints; i++) {
      int index = (i * step).round();
      if (index >= points.length) {
        index = points.length - 1;
      }
      result.add(points[index]);
    }
    
    // Always ensure the very last point is included for a complete path
    if (result.last != points.last) {
      result.add(points.last);
    }
    
    return result;
  }

  static LatLng calculateMapCenter({
    required List<LatLng> routePoints,
    required List<LatLng> eventPoints,
  }) {
    if (routePoints.isNotEmpty) {
      return routePoints.first;
    }
    if (eventPoints.isNotEmpty) {
      return eventPoints.first;
    }
    // Safe default center (e.g. Jakarta, Indonesia, or 0,0)
    // Using 0,0 as standard fallback
    return const LatLng(0, 0);
  }
}
