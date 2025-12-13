package com.tlmile.autoclick

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.content.ComponentName
import android.text.TextUtils


class MainActivity : FlutterActivity() {

    private val channelName = "auto_click_channel"


    private val CHANNEL = "com.tlmile.autoclick/update"  // Flutter 层和 Android 原生层通信的通道

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        MethodChannel(flutterEngine?.dartExecutor, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkForUpdate") {
                checkForUpdate(result)  // 调用检查更新的方法
            } else {
                result.notImplemented()
            }
        }
    }

    private fun checkForUpdate(result: MethodChannel.Result) {
        val updateUrl = "https://github.com/tlmile/FrostedGlass_Clicker/blob/main/doc/update.json"
        val client = OkHttpClient()
        val request = Request.Builder().url(updateUrl).build()

        Thread {
            try {
                val response = client.newCall(request).execute()
                if (response.isSuccessful) {
                    val responseBody = response.body?.string()
                    val jsonObject = JSONObject(responseBody)

                    val latestVersion = jsonObject.getString("version")
                    val currentVersion = packageManager.getPackageInfo(packageName, 0).versionName

                    if (latestVersion != currentVersion) {
                        // 如果有新版本，返回 true
                        result.success(true)
                    } else {
                        // 没有新版本，返回 false
                        result.success(false)
                    }
                } else {
                    result.success(false)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                result.success(false)
            }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        )

        // 存到全局，Service 那边也要用
        AutoClickChannelHolder.channel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startFloatingDot" -> {
                    val granted = ensureOverlayPermission()
                    if (granted) {
                        val rawArgs = call.arguments
                        val args = rawArgs as? Map<*, *> ?: emptyMap<Any, Any>()

                        val themeId = args["themeId"] as? String ?: "tech_blue"
                        val x = (args["x"] as? Number)?.toInt()
                        val y = (args["y"] as? Number)?.toInt()
                        val clickCount = (args["clickCount"] as? Number)?.toInt()
                        val isRandom = args["isRandom"] as? Boolean
                        val fixedIntervalMs = (args["fixedIntervalMs"] as? Number)?.toLong()
                        val randomMinMs = (args["randomMinMs"] as? Number)?.toLong()
                        val randomMaxMs = (args["randomMaxMs"] as? Number)?.toLong()

                        val popupAnchorX = (args["popupAnchorX"] as? Number)?.toInt()
                        val popupAnchorY = (args["popupAnchorY"] as? Number)?.toInt()

                        val taskId = args["taskId"] as? String
                        val taskName = args["taskName"] as? String

                        // 工作流相关
                        val isWorkflow = args["isWorkflow"] as? Boolean ?: false
                        val stepIndex = (args["stepIndex"] as? Number)?.toInt() ?: 1
                        val displayNumber =
                            (args["displayNumber"] as? Number)?.toInt() ?: stepIndex
                        val showNextStep =
                            args["showNextStep"] as? Boolean ?: isWorkflow

                        // 工作流步骤列表（来自 Flutter）
                        val workflowStepsSerializable = args["workflowSteps"]

                        val intent = Intent(this, FloatingDotService::class.java).apply {
                            putExtra("extra_theme_id", themeId)

                            if (x != null) putExtra("extra_x", x)
                            if (y != null) putExtra("extra_y", y)

                            if (clickCount != null) {
                                putExtra("extra_clickCount", clickCount)
                            }
                            if (isRandom != null) {
                                putExtra("extra_isRandom", isRandom)
                            }
                            if (fixedIntervalMs != null) {
                                putExtra("extra_fixedIntervalMs", fixedIntervalMs)
                            }
                            if (randomMinMs != null) {
                                putExtra("extra_randomMinMs", randomMinMs)
                            }
                            if (randomMaxMs != null) {
                                putExtra("extra_randomMaxMs", randomMaxMs)
                            }

                            if (popupAnchorX != null) {
                                putExtra("extra_popupAnchorX", popupAnchorX)
                            }
                            if (popupAnchorY != null) {
                                putExtra("extra_popupAnchorY", popupAnchorY)
                            }

                            if (taskId != null) {
                                putExtra("extra_taskId", taskId)
                            }
                            if (taskName != null) {
                                putExtra("extra_taskName", taskName)
                            }

                            putExtra("extra_isWorkflow", isWorkflow)
                            putExtra("extra_stepIndex", stepIndex)
                            putExtra("extra_displayNumber", displayNumber)
                            putExtra("extra_showNextStep", showNextStep)

                            if (workflowStepsSerializable is java.io.Serializable) {
                                putExtra("extra_workflowSteps", workflowStepsSerializable)
                            }
                        }

                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }

                "stopFloatingDot" -> {
                    AutoClickExecutor.stopAll()
                    stopService(Intent(this, FloatingDotService::class.java))
                    result.success(true)
                }

                "executeSingleTask" -> {
                    val args = call.arguments as? Map<*, *>
                    val x = (args?.get("x") as? Number)?.toInt()
                    val y = (args?.get("y") as? Number)?.toInt()
                    val clickCount = (args?.get("clickCount") as? Number)?.toInt() ?: 1
                    val isRandom = args?.get("isRandom") as? Boolean ?: false
                    val fixedInterval = (args?.get("fixedIntervalMs") as? Number)?.toLong()
                    val randomMin = (args?.get("randomMinMs") as? Number)?.toLong()
                    val randomMax = (args?.get("randomMaxMs") as? Number)?.toLong()
                    val taskId = args?.get("taskId") as? String

                    if (x != null && y != null) {
                        val step = ClickStepConfig(
                            x,
                            y,
                            clickCount,
                            isRandom,
                            fixedInterval,
                            randomMin,
                            randomMax,
                        )
                        AutoClickExecutor.executeSingle(this, step, taskId)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }

                "executeWorkflow" -> {
                    val args = call.arguments as? Map<*, *>
                    val stepsArg = args?.get("steps") as? List<*>
                    val loopInfiniteArg = args?.get("loopInfinite") as? Boolean
                    val loopCountArg = (args?.get("loopCount") as? Number)?.toInt()
                    val taskId = args?.get("taskId") as? String

                    val firstStepMap = stepsArg?.firstOrNull() as? Map<*, *>
                    val stepLoopInfinite = firstStepMap?.get("loopInfinite") as? Boolean
                    val stepLoopCount = (firstStepMap?.get("loopCount") as? Number)?.toInt()

                    Log.i(
                        "MainActivity",
                        "executeWorkflow argsLoop=$loopCountArg/$loopInfiniteArg stepLoop=$stepLoopCount/$stepLoopInfinite taskId=$taskId steps=${stepsArg?.size}"
                    )

                    val loopCount = normalizeLoopCount(
                        rawCount = loopCountArg ?: stepLoopCount,
                        loopInfiniteFlag = loopInfiniteArg ?: stepLoopInfinite,
                    )

                    Log.i(
                        "MainActivity",
                        "executeWorkflow normalizedLoopCount=$loopCount",
                    )

                    val steps = stepsArg
                        ?.mapNotNull { it as? Map<*, *> }
                        ?.mapNotNull { map -> mapToClickStep(map) }
                        ?: emptyList()

                    AutoClickExecutor.executeWorkflow(this, steps, loopCount, taskId)
                    result.success(true)
                }

                "stopExecution" -> {
                    val args = call.arguments as? Map<*, *>
                    val taskId = args?.get("taskId") as? String
                    AutoClickExecutor.stopAll(taskId)
                    result.success(true)
                }

                "getFloatingBallSize" -> {
                    val current = FloatingBallPreferences.loadDiameterDp(this)
                    result.success(current)
                }

                "setFloatingBallSize" -> {
                    val args = call.arguments as? Map<*, *>
                    val dp = (args?.get("dp") as? Number)?.toInt()
                    if (dp == null) {
                        result.error("INVALID_DP", "Missing dp value", null)
                    } else {
                        val saved = FloatingBallPreferences.saveDiameterDp(this, dp)
                        result.success(saved)
                    }
                }

                // ⭐ 新增：隐藏/显示所有悬浮球（给 Flutter 弹对话框用）
                "hideFloatingDots" -> {
                    FloatingDotService.instance?.hideAllDotsForExecution()
                    result.success(true)
                }

                "showFloatingDots" -> {
                    FloatingDotService.instance?.showDotsAfterExecution()
                    result.success(true)
                }

                "updateFloatingConfig" -> {
                    val args = call.arguments as? Map<*, *>
                    val taskId = args?.get("taskId") as? String
                    val isWorkflow = args?.get("isWorkflow") as? Boolean
                    val stepIndex = (args?.get("stepIndex") as? Number)?.toInt()
                    val displayNumber = (args?.get("displayNumber") as? Number)?.toInt()
                    val clickCount = (args?.get("clickCount") as? Number)?.toInt()
                    val isRandom = args?.get("isRandom") as? Boolean
                    val fixedInterval =
                        (args?.get("fixedIntervalMs") as? Number)?.toLong()
                    val randomMin = (args?.get("randomMinMs") as? Number)?.toLong()
                    val randomMax = (args?.get("randomMaxMs") as? Number)?.toLong()
                    val includeLoop = isWorkflow == true && (displayNumber == 1 || stepIndex == 1)
                    val loopCount = if (includeLoop) {
                        (args?.get("loopCount") as? Number)?.toInt()
                    } else {
                        null
                    }
                    val loopInfinite = if (includeLoop) {
                        args?.get("loopInfinite") as? Boolean
                    } else {
                        null
                    }

                    Log.i(
                        "MainActivity",
                        "updateFloatingConfig task=$taskId stepIndex=$stepIndex displayNumber=$displayNumber includeLoop=$includeLoop loopCount=$loopCount loopInfinite=$loopInfinite"
                    )

                    FloatingDotService.instance?.applyExternalConfigUpdate(
                        taskId = taskId,
                        isWorkflow = isWorkflow,
                        stepIndex = stepIndex,
                        clickCount = clickCount,
                        isRandom = isRandom,
                        fixedIntervalMs = fixedInterval,
                        randomMinMs = randomMin,
                        randomMaxMs = randomMax,
                        loopCount = loopCount,
                        loopInfinite = loopInfinite,
                    )

                    result.success(true)
                }

                "removeWorkflowSteps" -> {
                    val args = call.arguments as? Map<*, *>
                    val taskId = args?.get("taskId") as? String
                    val stepIndexesAny = args?.get("stepIndexes") as? List<*>
                    val stepIndexes = stepIndexesAny
                        ?.mapNotNull { (it as? Number)?.toInt() }
                        ?: emptyList()

                    // 这里只用到 stepIndexes，taskId 目前可以不用
                    FloatingDotService.instance?.removeWorkflowSteps(stepIndexes)

                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }


//    /**
//     * 检查并跳转悬浮窗权限设置（Draw over other apps）
//     * 这里不用返回值，纯粹负责“如果没权限就打开设置界面”
//     */
//    private fun checkAndRequestOverlayPermission() {
//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
//            !Settings.canDrawOverlays(this)
//        ) {
//            val intent = Intent(
//                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
//                Uri.parse("package:$packageName")
//            ).apply {
//                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
//            }
//            startActivity(intent)
//        }
//    }
//
//    /**
//     * 判断我们的无障碍服务是否已经被用户开启
//     */
//    private fun isMyAccessibilityServiceEnabled(): Boolean {
//        // 这个就是你在 manifest 里声明的无障碍服务类
//        val serviceComponent = ComponentName(this, AutoClickAccessibilityService::class.java)
//        val serviceId = serviceComponent.flattenToString()
//
//        val enabledServices = Settings.Secure.getString(
//            contentResolver,
//            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
//        ) ?: return false
//
//        val colonSplitter = TextUtils.SimpleStringSplitter(':')
//        colonSplitter.setString(enabledServices)
//
//        while (colonSplitter.hasNext()) {
//            val enabledService = colonSplitter.next()
//            if (enabledService.equals(serviceId, ignoreCase = true)) {
//                return true
//            }
//        }
//        return false
//    }
//
//    /**
//     * 检查并引导用户打开无障碍服务设置页面
//     */
//    private fun checkAndRequestAccessibility() {
//        if (!isMyAccessibilityServiceEnabled()) {
//            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
//                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
//            }
//            startActivity(intent)
//        }
//    }
//
//    override fun onResume() {
//        super.onResume()
//
////        // 回到前台时检查权限（包括 App 首次启动）
////        checkAndRequestOverlayPermission()
////        checkAndRequestAccessibility()
//    }



    private fun normalizeLoopCount(rawCount: Int?, loopInfiniteFlag: Boolean?): Int? {
        if (loopInfiniteFlag == true) return 0
        val sanitized = rawCount ?: return null
        return if (sanitized <= 0) 1 else sanitized
    }

    private fun mapToClickStep(map: Map<*, *>): ClickStepConfig? {
        val x = (map["x"] as? Number)?.toInt() ?: (map["posX"] as? Number)?.toInt()
        val y = (map["y"] as? Number)?.toInt() ?: (map["posY"] as? Number)?.toInt()
        val clickCount = (map["clickCount"] as? Number)?.toInt() ?: 1
        val isRandom = map["isRandom"] as? Boolean ?: false
        val fixedInterval = (map["fixedIntervalMs"] as? Number)?.toLong()
        val randomMin = (map["randomMinMs"] as? Number)?.toLong()
        val randomMax = (map["randomMaxMs"] as? Number)?.toLong()
        val stepOrder = (map["stepIndex"] as? Number)?.toInt()
            ?: (map["displayNumber"] as? Number)?.toInt()
            ?: (map["index"] as? Number)?.toInt()

        if (x == null || y == null) return null

        return ClickStepConfig(
            x,
            y,
            clickCount,
            isRandom,
            fixedInterval,
            randomMin,
            randomMax,
            stepOrder,
        )
    }

    private fun ensureOverlayPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return if (Settings.canDrawOverlays(this)) {
            true
        } else {
            Toast.makeText(this, "请开启悬浮窗权限", Toast.LENGTH_LONG).show()
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            false
        }
    }
}
