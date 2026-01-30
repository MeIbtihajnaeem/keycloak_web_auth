import 'package:fake_async/fake_async.dart';
import 'package:keycloak_web_auth/src/refresh_scheduler.dart';
import 'package:test/test.dart';

void main() {
  group('RefreshScheduler', () {
    test('schedules refresh before expiry', () {
      fakeAsync((async) {
        var refreshed = false;
        final scheduler = RefreshScheduler(
          thresholdSeconds: 2,
          onRefresh: () async {
            refreshed = true;
          },
        );

        final expiry = DateTime.now().toUtc().add(const Duration(seconds: 5));
        scheduler.schedule(expiry);

        async.elapse(const Duration(seconds: 2));
        expect(refreshed, isFalse);

        async.elapse(const Duration(seconds: 2));
        expect(refreshed, isTrue);
      });
    });
  });
}
