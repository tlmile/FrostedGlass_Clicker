import 'package:flutter/services.dart';

class UpdateChecker {
  static const platform = MethodChannel('com.tlmile.autoclick/update');

  // 检查更新的方法
  Future<void> checkForUpdate() async {
    try {
      // 调用原生 Android 代码的 checkForUpdate 方法
      final bool isUpdateAvailable = await platform.invokeMethod('checkForUpdate');

      if (isUpdateAvailable) {
        // 如果有更新，执行相应操作，比如弹出更新对话框
        print("Update available");
      } else {
        print("No updates available");
      }
    } on PlatformException catch (e) {
      print("Failed to check for update: '${e.message}'.");
    }
  }
}
