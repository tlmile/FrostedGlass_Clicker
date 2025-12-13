import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UpdateChecker {
  static const platform = MethodChannel('com.tlmile.autoclick/update');

  // 检查更新的方法
  Future<bool> checkForUpdate({BuildContext? context}) async {
    try {
      // 调用原生 Android 代码的 checkForUpdate 方法
      final bool isUpdateAvailable =
          await platform.invokeMethod('checkForUpdate');

      if (isUpdateAvailable) {
        // 如果有更新，执行相应操作，比如弹出更新对话框
        debugPrint('Update available');
        if (context != null) {
          _showUpdateDialog(context);
        }
      } else {
        debugPrint('No updates available');
      }
      return isUpdateAvailable;
    } on PlatformException catch (e) {
      debugPrint("Failed to check for update: '${e.message}'.");
      return false;
    }
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('发现新版本'),
          content: const Text('检测到有新版本可用，请前往更新以体验最新功能。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }
}
