import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/utils/app_date_time.dart';
import 'package:roadsense/data/models/road_session.dart';

void main() {
  group('AppDateTime', () {
    test('parseServer keeps the same instant and converts to local time', () {
      const raw = '2026-07-12T05:30:00Z';

      final parsed = AppDateTime.parseServer(raw);

      expect(parsed.isUtc, isFalse);
      expect(parsed.toUtc(), DateTime.parse(raw).toUtc());
    });

    test('displaySessionTitle regenerates auto-generated trip title from startTime', () {
      final start = DateTime.utc(2026, 7, 12, 8, 30).toLocal();
      final session = RoadSession(
        id: 's1',
        userId: 'u1',
        title: 'Road Trip 2026-07-12 01:30',
        startTime: start,
        createdAt: start,
      );

      final title = AppDateTime.displaySessionTitle(session);

      expect(title, AppDateTime.autoTripTitle(value: start));
    });

    test('displaySessionTitle preserves custom title', () {
      final start = DateTime.utc(2026, 7, 12, 8, 30).toLocal();
      final session = RoadSession(
        id: 's1',
        userId: 'u1',
        title: 'Survey Jalan Kampus',
        startTime: start,
        createdAt: start,
      );

      expect(AppDateTime.displaySessionTitle(session), 'Survey Jalan Kampus');
    });
  });
}
