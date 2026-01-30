import 'dart:async';

class RefreshScheduler {
  final int thresholdSeconds;
  final Future<void> Function() onRefresh;
  final void Function(Object error)? onError;
  Timer? _timer;
  DateTime? _expiry;

  RefreshScheduler({
    required this.thresholdSeconds,
    required this.onRefresh,
    this.onError,
  });

  void schedule(DateTime expiry) {
    _expiry = expiry;
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (_expiry == null) return;
    final now = DateTime.now().toUtc();
    final refreshAt = _expiry!.toUtc().subtract(
      Duration(seconds: thresholdSeconds),
    );
    var delay = refreshAt.difference(now);
    if (delay.isNegative) {
      delay = const Duration(seconds: 1);
    }
    _timer = Timer(delay, () async {
      try {
        await onRefresh();
      } catch (error) {
        if (onError != null) {
          onError!(error);
        }
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
  }
}
