import 'package:flutter/foundation.dart';

class ScanFeedbackNotifier extends ChangeNotifier {
  bool _soundEnabled = true;
  bool _vibrationEnabled = false;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  void setSoundEnabled(bool value) {
    _soundEnabled = value;
    notifyListeners();
  }

  void setVibrationEnabled(bool value) {
    _vibrationEnabled = value;
    notifyListeners();
  }
}
