# 使用 `update.json` 实现应用升级通知（超详细）

本文档完整说明 FrostedGlass Clicker 如何通过远程 `update.json` 检测版本并向用户展示升级提示，涵盖文件格式、托管要求、Flutter ↔ Android 交互以及关键代码示例，方便快速接入或调整。 

## 1. `update.json` 文件格式

项目默认将升级配置放在仓库的 `doc/update.json`，通过原始链接供客户端拉取。字段含义如下：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `version` | `string` | 线上最新版本号（与 `build.gradle`/`pubspec.yaml` 中的 `versionName` 对比）。|
| `apk_url` | `string` | 新版本 APK 下载地址。|
| `changelog` | `string` | 展示给用户的更新内容。|
| `force_update` | `bool` | 是否强制更新（`true` 时弹窗不可取消）。|

示例（项目当前的配置）：

```json
{
  "version": "1.1.0",
  "apk_url": "https://github.com/tlmile/FrostedGlass_Clicker/releases/download/v1.0.0/autoclick-v1.0.0.1.-release.apk",
  "changelog": "Bug fixes and performance improvements.",
  "force_update": false
}
```

> **托管地址：** Android 端通过 `https://raw.githubusercontent.com/tlmile/FrostedGlass_Clicker/main/doc/update.json` 拉取，所以发布后务必确保该链接可直接访问到最新 JSON。 【F:doc/update.json†L1-L6】

## 2. Flutter 层：触发检查 & UI 提示

1. **启动时触发**：在 `main.dart` 完成 Hive 初始化后，使用 `UpdateChecker`（封装 MethodChannel）发起检查，保证首帧绘制后有可用 `BuildContext`：

```dart
final updateChecker = UpdateChecker();

// 在第一帧绘制完成后检查更新
WidgetsBinding.instance.addPostFrameCallback((_) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    updateChecker.checkForUpdate(context: context);
  } else {
    updateChecker.checkForUpdate();
  }
});
```

该逻辑来自 `lib/main.dart` 的应用入口。 【F:lib/main.dart†L18-L34】

2. **封装 MethodChannel**：`lib/update_checker.dart` 通过 `MethodChannel('com.tlmile.autoclick/update')` 调用原生 `checkForUpdate`。当返回 `true` 时会弹出基础更新提示框：

```dart
class UpdateChecker {
  static const platform = MethodChannel('com.tlmile.autoclick/update');

  Future<bool> checkForUpdate({BuildContext? context}) async {
    final bool isUpdateAvailable = await platform.invokeMethod('checkForUpdate');
    if (isUpdateAvailable && context != null) {
      _showUpdateDialog(context);
    }
    return isUpdateAvailable;
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本'),
        content: const Text('检测到有新版本可用，请前往更新以体验最新功能。'),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('知道了'))],
      ),
    );
  }
}
```

此处的弹窗仅为示例，实际产品可根据 `force_update` 等字段自行扩展。 【F:lib/update_checker.dart†L1-L41】

## 3. Android 原生层：解析 `update.json` 并返回结果

### 3.1 MethodChannel 桥接
`android/app/src/main/kotlin/com/tlmile/autoclick/MainActivity.kt` 注册了 `checkForUpdate` 方法。Flutter 侧调用后，原生线程会执行 HTTP 请求并对比版本号：

```kotlin
private fun checkForUpdate(result: MethodChannel.Result) {
    val updateUrl = "https://raw.githubusercontent.com/tlmile/FrostedGlass_Clicker/main/doc/update.json"
    val client = OkHttpClient()
    val request = Request.Builder().url(updateUrl).build()

    Thread {
        try {
            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val jsonObject = JSONObject(response.body?.string() ?: "{}")
                    val latestVersion = jsonObject.optString("version", "")
                    val currentVersion = packageManager.getPackageInfo(packageName, 0).versionName
                    val hasUpdate = latestVersion.isNotEmpty() && latestVersion != (currentVersion ?: "")
                    result.success(hasUpdate)
                } else {
                    result.success(false)
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "checkForUpdate failed", e)
            result.success(false)
        }
    }.start()
}
```

关键点：
- **请求地址**：使用 `raw.githubusercontent.com` 确保拿到纯 JSON。 
- **线程处理**：在子线程中执行网络请求，避免阻塞 UI。 
- **版本对比**：仅当 `latestVersion` 与当前 `versionName` 不一致时返回 `true`。 
- **异常兜底**：异常或非 2xx 响应均返回 `false`，Flutter 侧不会弹出提示。 【F:android/app/src/main/kotlin/com/tlmile/autoclick/MainActivity.kt†L26-L55】

### 3.2 可选：原生弹窗/下载逻辑
项目中另有 `UpdateChecker.kt` 示例，展示了更完整的原生弹窗与强制更新处理（未在当前流程中调用，但可复用）：

```kotlin
private fun showUpdateDialog(apkUrl: String, changelog: String, forceUpdate: Boolean) {
    val builder = AlertDialog.Builder(context)
        .setTitle("更新版本")
        .setMessage(changelog)
        .setCancelable(!forceUpdate)
        .setPositiveButton("更新") { _, _ -> downloadAndInstall(apkUrl) }
    if (!forceUpdate) {
        builder.setNegativeButton("稍后") { dialog, _ -> dialog.dismiss() }
    }
    builder.show()
}
```

- 可依据 `force_update` 控制弹窗是否可取消。
- `downloadAndInstall(apkUrl)` 留作实际下载实现入口。 【F:android/app/src/main/kotlin/com/tlmile/autoclick/UpdateChecker.kt†L38-L56】

## 4. 端到端流程回顾

1. **发布新版本**：更新 `doc/update.json` 中的 `version` / `apk_url` / `changelog` / `force_update`，并推送到默认分支，保证原始链接可访问。
2. **应用启动**：Flutter `main.dart` 在首帧后调用 `UpdateChecker.checkForUpdate`。
3. **原生网络请求**：`MainActivity.checkForUpdate` 拉取 `update.json`，对比当前 `versionName`。
4. **返回结果**：原生将布尔值通过 MethodChannel 返回给 Flutter。
5. **用户提示**：Flutter 收到 `true` 后弹窗提示；若需要强制/跳转下载，可移植 `UpdateChecker.kt` 的弹窗与下载逻辑。

通过以上配置，即可在保持 `update.json` 为唯一真源的前提下，实现跨 Flutter 与原生的统一升级通知流程。
