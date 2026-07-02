import '../../data/models/road_reading.dart';
import '../../data/models/road_session.dart';

class TripSummaryCalculator {
  static RoadSession calculateSummary(RoadSession session, List<RoadReading> readings) {
    if (readings.isEmpty) {
      return session.copyWith(
        averageSpeed: 0.0,
        maxSpeed: 0.0,
        maxVibration: 0.0,
      );
    }

    double maxSpeed = 0.0;
    double maxVibration = 0.0;
    double sumSpeed = 0.0;

    for (final r in readings) {
      if (r.speed > maxSpeed) maxSpeed = r.speed;
      if (r.vibration > maxVibration) maxVibration = r.vibration;
      sumSpeed += r.speed;
    }

    final avgSpeed = sumSpeed / readings.length;

    return session.copyWith(
      averageSpeed: avgSpeed,
      maxSpeed: maxSpeed,
      maxVibration: maxVibration,
    );
  }
}
