import 'dart:async';

/// 简单的重置协调器，用于在清空数据库前，先通知界面层清理内存状态。
class ResetHub {
  ResetHub._();

  static final ResetHub instance = ResetHub._();

  final List<FutureOr<void> Function()> _listeners = [];

  void registerListener(FutureOr<void> Function() listener) {
    if (_listeners.contains(listener)) return;
    _listeners.add(listener);
  }

  void unregisterListener(FutureOr<void> Function() listener) {
    _listeners.remove(listener);
  }

  Future<void> notifyBeforeDatabaseReset() async {
    for (final listener in List.of(_listeners)) {
      await listener();
    }
  }
}
