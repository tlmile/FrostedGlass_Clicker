import 'package:flutter/services.dart';

/// Centralized MethodChannel used to talk to Android native side.
class AutoClickChannels {
  static const MethodChannel autoClickChannel =
  MethodChannel('auto_click_channel');
}
