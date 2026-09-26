import 'package:flutter/foundation.dart';

class AppShortcutController extends ChangeNotifier {
  static const startPomodoroAction = 'com.taskflow.app.START_POMODORO';

  var _startPomodoroRequested = false;

  void handleAction(String? action) {
    if (action != startPomodoroAction) return;
    _startPomodoroRequested = true;
    notifyListeners();
  }

  bool consumeStartPomodoroRequest() {
    if (!_startPomodoroRequested) return false;
    _startPomodoroRequested = false;
    return true;
  }
}
