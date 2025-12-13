package com.tlmile.autoclick

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Resources
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.View.MeasureSpec
import android.view.ViewGroup
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import kotlin.math.roundToInt

class FloatingDotService : Service() {

    companion object {
        const val EXTRA_THEME_ID = "extra_theme_id"

        // 和 MainActivity / Flutter 约定的 key
        const val EXTRA_TASK_ID = "extra_taskId"
        const val EXTRA_TASK_NAME = "extra_taskName"
        const val EXTRA_X = "extra_x"
        const val EXTRA_Y = "extra_y"
        const val EXTRA_CLICK_COUNT = "extra_clickCount"
        const val EXTRA_IS_RANDOM = "extra_isRandom"
        const val EXTRA_FIXED_INTERVAL = "extra_fixedIntervalMs"
        const val EXTRA_RANDOM_MIN = "extra_randomMinMs"
        const val EXTRA_RANDOM_MAX = "extra_randomMaxMs"

        const val EXTRA_POPUP_ANCHOR_X = "extra_popupAnchorX"
        const val EXTRA_POPUP_ANCHOR_Y = "extra_popupAnchorY"

        const val EXTRA_IS_WORKFLOW = "extra_isWorkflow"
        const val EXTRA_SHOW_NEXT_STEP = "extra_showNextStep"
        const val EXTRA_STEP_INDEX = "extra_stepIndex"
        const val EXTRA_DISPLAY_NUMBER = "extra_displayNumber"

        const val EXTRA_WORKFLOW_STEPS = "extra_workflowSteps"

        private const val MAX_WORKFLOW_STEPS = 8

        // 循环相关（可选）
        const val EXTRA_LOOP_COUNT = "extra_loopCount"
        const val EXTRA_LOOP_INFINITE = "extra_loopInfinite"

        // 当前最新一步（最后一颗工作流悬浮球）的配置，用来防止被前面步骤编辑“串改”
        private var latestConfigInitialized: Boolean = false
        private var latestClickCount: Int = 1
        private var latestIsRandom: Boolean = false
        private var latestFixedIntervalMs: Long = 50L
        private var latestRandomMinMs: Long = 50L
        private var latestRandomMaxMs: Long = 200L
        private var latestLoopCount: Int? = null
        private var latestLoopInfinite: Boolean = false

        // 用于执行时临时隐藏/恢复悬浮球
        var instance: FloatingDotService? = null
    }

    private val notificationChannelId = "floating_dot_channel"
    private val notificationId = 1

    private var windowManager: WindowManager? = null

    // 当前“可编辑”的悬浮球（最新的那颗）
    private var floatingDot: View? = null
    private lateinit var layoutParams: WindowManager.LayoutParams

    // 工作流下，之前步骤的悬浮球（预览 + 可再次打开配置）
    private data class WorkflowDotHolder(
        val view: View,
        val lp: WindowManager.LayoutParams,
        val stepIndex: Int,
        val displayNumber: Int,
        val themeId: String,
        var clickCount: Int?,
        var isRandom: Boolean?,
        var fixedIntervalMs: Long?,
        var randomMinMs: Long?,
        var randomMaxMs: Long?,
        var loopCount: Int?,
        var loopInfinite: Boolean?,
    )

    private val workflowPreviewDots = mutableListOf<WorkflowDotHolder>()

    // 当前这次弹框是不是从“预览球”点出来的
    private var editingFromPreview: Boolean = false

    // 配置面板相关
    private var configView: View? = null
    private lateinit var configLayoutParams: WindowManager.LayoutParams
    private var configPanelView: View? = null

    // 当前这个配置面板是给哪一个悬浮球开的
    private var configForDot: View? = null

    // 当前悬浮球使用的主题 & 任务 id & 名称（由 Flutter 传入或保存）
    private var currentThemeId: String? = null
    private var currentTaskId: String? = null
    private var currentTaskName: String? = null

    // 是否是工作流任务 / 当前步骤索引 / 显示的数字 / 是否显示「下一步」按钮
    private var isWorkflowTask: Boolean = false
    private var stepIndex: Int = 1
    private var displayNumber: Int = 1
    private var showNextStepButton: Boolean = false

    // 弹框锚点（来自 Flutter，尽量让弹窗贴着悬浮球）
    private var popupAnchorX: Int? = null
    private var popupAnchorY: Int? = null

    // 如果从任务启动，可能会传入指定坐标
    private var overrideX: Int? = null
    private var overrideY: Int? = null

    // 点击配置（会被 Intent 覆盖，然后用于弹窗初始值 & 保存回调）
    private var clickCount: Int = 10
    private var isRandomMode: Boolean = false
    private var fixedIntervalMs: Long = 1000
    private var randomMinMs: Long = 500
    private var randomMaxMs: Long = 1500

    // 悬浮球尺寸（px，来自 SharedPreferences 的 dp 值换算）
    private var floatingBallDiameterPx: Int = 0

    // 工作流循环配置（目前只有“第 1 步”用）
    private var loopCount: Int? = null
    private var loopInfinite: Boolean = false

    // 执行时隐藏悬浮球的标记
    private var dotsHiddenForExecution: Boolean = false

    override fun onBind(intent: Intent?): IBinder? = null

    // ===== 通用工具：悬浮窗类型 & 权限 & 尺寸 =====

    // 统一获取悬浮窗类型
    private val overlayLayoutType: Int
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

    // 校验悬浮窗权限，不通过时申请并结束服务，返回 false 表示已经 stopSelf
    private fun ensureOverlayPermissionOrStop(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            requestOverlayPermission()
            stopSelf()
            return false
        }
        return true
    }

    // 确保 floatingBallDiameterPx 有值（px），没有则从偏好中加载
    private fun ensureBallDiameterPx(): Int {
        if (floatingBallDiameterPx <= 0) {
            floatingBallDiameterPx = loadSavedBallDiameterPx()
        }
        return floatingBallDiameterPx
    }

    // 通用创建悬浮球 LayoutParams 的方法（统一 flags / format / gravity）
    private fun createBallLayoutParams(
        width: Int,
        height: Int,
        x: Int,
        y: Int
    ): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            width,
            height,
            overlayLayoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            this.x = x
            this.y = y
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForegroundWithNotification(createNotification())
        windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        instance = this

        // 初始加载悬浮球尺寸（dp 持久化，展示时换算为 px）
        floatingBallDiameterPx = loadSavedBallDiameterPx()

        // 注册执行回调：开始执行时隐藏悬浮球，结束/停止时再恢复
        AutoClickExecutor.registerVisibilityCallbacks(
            onStart = { hideAllDotsForExecution() },
            onFinish = { showDotsAfterExecution() },
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        editingFromPreview = false

        // 先把上一次的所有球都清掉（包括未保存的）
        clearAllDots()
        removeConfigPanel()

        // ✅ 每次启动都先重置点击配置为默认值，避免新任务继承上一个任务的次数/间隔
        resetClickConfigToDefault()

        val themeId = intent?.getStringExtra(EXTRA_THEME_ID) ?: "tech_blue"
        currentThemeId = themeId

        // 从 Flutter 传入的任务信息
        currentTaskId = intent?.getStringExtra(EXTRA_TASK_ID)
        currentTaskName = intent?.getStringExtra(EXTRA_TASK_NAME)

        // 工作流信息
        isWorkflowTask = intent?.getBooleanExtra(EXTRA_IS_WORKFLOW, false) ?: false
        showNextStepButton = intent?.getBooleanExtra(EXTRA_SHOW_NEXT_STEP, false) ?: false

        stepIndex = if (intent?.hasExtra(EXTRA_STEP_INDEX) == true) {
            intent.getIntExtra(EXTRA_STEP_INDEX, 1).coerceAtLeast(1)
        } else {
            1
        }
        displayNumber = if (intent?.hasExtra(EXTRA_DISPLAY_NUMBER) == true) {
            intent.getIntExtra(EXTRA_DISPLAY_NUMBER, stepIndex).coerceAtLeast(1)
        } else {
            stepIndex.coerceAtLeast(1)
        }

        // 先根据是否工作流设置默认值
        if (isWorkflowTask) {
            setWorkflowClickDefaults()
        } else {
            setSingleClickDefaults()
        }
        loopCount = null
        loopInfinite = false

        // 坐标
        overrideX = if (intent?.hasExtra(EXTRA_X) == true) {
            intent.getIntExtra(EXTRA_X, 0)
        } else null
        overrideY = if (intent?.hasExtra(EXTRA_Y) == true) {
            intent.getIntExtra(EXTRA_Y, 0)
        } else null

        // 弹框锚点（可选）
        popupAnchorX = if (intent?.hasExtra(EXTRA_POPUP_ANCHOR_X) == true) {
            intent.getIntExtra(EXTRA_POPUP_ANCHOR_X, 0)
        } else null
        popupAnchorY = if (intent?.hasExtra(EXTRA_POPUP_ANCHOR_Y) == true) {
            intent.getIntExtra(EXTRA_POPUP_ANCHOR_Y, 0)
        } else null

        // 覆盖点击配置
        val clickCountExtra = if (intent?.hasExtra(EXTRA_CLICK_COUNT) == true) {
            intent.getIntExtra(EXTRA_CLICK_COUNT, -1)
        } else null
        if (clickCountExtra != null && clickCountExtra > 0) {
            clickCount = clickCountExtra
        }

        if (intent?.hasExtra(EXTRA_IS_RANDOM) == true) {
            isRandomMode = intent.getBooleanExtra(EXTRA_IS_RANDOM, isRandomMode)
        }

        val fixedIntervalExtra = if (intent?.hasExtra(EXTRA_FIXED_INTERVAL) == true) {
            intent.getLongExtra(EXTRA_FIXED_INTERVAL, -1L)
        } else null
        if (fixedIntervalExtra != null && fixedIntervalExtra > 0) {
            fixedIntervalMs = fixedIntervalExtra
        }

        val randomMinExtra = if (intent?.hasExtra(EXTRA_RANDOM_MIN) == true) {
            intent.getLongExtra(EXTRA_RANDOM_MIN, -1L)
        } else null
        if (randomMinExtra != null && randomMinExtra > 0) {
            randomMinMs = randomMinExtra
        }

        val randomMaxExtra = if (intent?.hasExtra(EXTRA_RANDOM_MAX) == true) {
            intent.getLongExtra(EXTRA_RANDOM_MAX, -1L)
        } else null
        if (randomMaxExtra != null && randomMaxExtra > 0) {
            randomMaxMs = randomMaxExtra
        }

        // 循环配置（如果 Flutter 有传）
        val loopCountExtra = if (intent?.hasExtra(EXTRA_LOOP_COUNT) == true) {
            intent.getIntExtra(EXTRA_LOOP_COUNT, -1)
        } else null
        if (loopCountExtra != null && loopCountExtra > 0) {
            loopCount = loopCountExtra
        }
        if (intent?.hasExtra(EXTRA_LOOP_INFINITE) == true) {
            loopInfinite = intent.getBooleanExtra(EXTRA_LOOP_INFINITE, false)
        }

        // 清空旧的预览球
        clearWorkflowPreviewDots()

        // 如果是工作流，从 workflowSteps 里恢复每一步的配置 + 悬浮球
        if (isWorkflowTask) {
            val stepsAny = intent?.getSerializableExtra(EXTRA_WORKFLOW_STEPS)
            val stepsList = stepsAny as? List<*>

            stepsList?.forEach { stepObj ->
                val stepMap = stepObj as? Map<*, *> ?: return@forEach

                // 坐标：兼容 x / posX, y / posY
                val sx = (stepMap["x"] as? Number)?.toInt()
                    ?: (stepMap["posX"] as? Number)?.toInt()
                val sy = (stepMap["y"] as? Number)?.toInt()
                    ?: (stepMap["posY"] as? Number)?.toInt()

                // 逻辑步骤 ID：用于内部标识（可以是 generateStepId 的大数字）
                val sIndex = (stepMap["index"] as? Number)?.toInt()
                    ?: (stepMap["stepIndex"] as? Number)?.toInt()
                    ?: 1

                // 展示用数字：显示在悬浮球上的 1 / 2 / 3...
                val displayNumber = (stepMap["displayNumber"] as? Number)?.toInt()
                    ?: sIndex

                if (sx != null && sy != null) {
                    val sClickCount = (stepMap["clickCount"] as? Number)?.toInt()
                    val sIsRandom = stepMap["isRandom"] as? Boolean
                    val sFixed = (stepMap["fixedIntervalMs"] as? Number)?.toLong()
                    val sRandomMin = (stepMap["randomMinMs"] as? Number)?.toLong()
                    val sRandomMax = (stepMap["randomMaxMs"] as? Number)?.toLong()
                    val sLoopCount = (stepMap["loopCount"] as? Number)?.toInt()
                    val sLoopInfinite = stepMap["loopInfinite"] as? Boolean

                    addPreviewDotAt(
                        centerX = sx,
                        centerY = sy,
                        stepIndex = sIndex,
                        displayNumber = displayNumber,
                        themeId = currentThemeId ?: "tech_blue",
                        clickCount = sClickCount,
                        isRandom = sIsRandom,
                        fixedIntervalMs = sFixed,
                        randomMinMs = sRandomMin,
                        randomMaxMs = sRandomMax,
                        loopCount = sLoopCount,
                        loopInfinite = sLoopInfinite,
                    )
                }
            }

            // 如果当前 stepIndex 在这些步骤中，应用对应配置
            val currentHolder = workflowPreviewDots.find { it.stepIndex == stepIndex }
            if (currentHolder != null) {
                applyHolderConfigToCurrent(currentHolder)
            }
        }

        // 关掉旧弹框
        removeConfigPanel()

        // ✅ 工作流：如果已有步骤（从列表点进来），不要再生成一个新的第 N+1 步。
        //    取 stepIndex 最大的那颗作为“当前可编辑”的最新一步，它的弹框会有“下一步”按钮。
        if (isWorkflowTask && workflowPreviewDots.isNotEmpty()) {
            val latestHolder = workflowPreviewDots.maxWithOrNull(
                compareBy<WorkflowDotHolder> { it.displayNumber }.thenBy { it.stepIndex }
            )!!

            workflowPreviewDots.remove(latestHolder)

            floatingDot = latestHolder.view
            layoutParams = latestHolder.lp
            isWorkflowTask = true
            stepIndex = latestHolder.stepIndex
            displayNumber = latestHolder.displayNumber

            // 缓存“最新一步”的配置
            latestConfigInitialized = true
            latestClickCount = latestHolder.clickCount ?: 1
            latestIsRandom = latestHolder.isRandom ?: false
            latestFixedIntervalMs = latestHolder.fixedIntervalMs ?: 50L
            latestRandomMinMs = latestHolder.randomMinMs ?: 50L
            latestRandomMaxMs = latestHolder.randomMaxMs ?: 200L
            latestLoopCount = latestHolder.loopCount
            latestLoopInfinite = latestHolder.loopInfinite ?: false

            // 应用到当前配置变量（用于弹窗初始值）
            applyHolderConfigToCurrent(latestHolder)

            val latestRoot = latestHolder.view.findViewById<FrameLayout>(R.id.rootBall)
            latestRoot.setOnTouchListener(
                createTouchListener(
                    latestHolder.view,
                    latestHolder.stepIndex,
                    latestHolder.displayNumber
                )
            )

            editingFromPreview = false

            return START_STICKY
        }

        // 否则：单击任务，或者“新建工作流第一步”（workflowPreviewDots 为空）→ 创建一个新球
        addFloatingDot(themeId)

        return START_STICKY
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        AutoClickExecutor.stopAll()
        clearAllDots()
        removeConfigPanel()
        AutoClickExecutor.registerVisibilityCallbacks(null, null)
        instance = null
        super.onDestroy()
    }

    private fun clearWorkflowPreviewDots() {
        val wm = windowManager ?: return
        workflowPreviewDots.forEach { holder ->
            try {
                wm.removeView(holder.view)
            } catch (_: Exception) {
            }
        }
        workflowPreviewDots.clear()
    }

    // ---------------- 前台服务 & 通知 ----------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                notificationChannelId,
                "AutoClick Foreground",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundWithNotification(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MANIFEST
            )
        } else {
            startForeground(notificationId, notification)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, notificationChannelId)
            .setContentTitle("悬浮球正在运行")
            .setContentText("可在其他应用上拖动和配置自动点击")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()
    }

    // ---------------- 悬浮球本体 ----------------

    private fun addFloatingDot(themeId: String) {
        val wm = windowManager ?: return

        if (!ensureOverlayPermissionOrStop()) return

        // 移除当前可编辑球（不影响预览球）
        removeFloatingDot()

        val dotSize = ensureBallDiameterPx()

        val hasValidSavedPosition =
            (currentTaskId != null &&
                    overrideX != null && overrideY != null &&
                    !(overrideX == 0 && overrideY == 0))

        val displayMetrics = Resources.getSystem().displayMetrics
        val fullWidth = displayMetrics.widthPixels
        val fullHeight = displayMetrics.heightPixels

        val statusBarHeight = getStatusBarHeight()
        val navBarHeight = getNavigationBarHeight()
        val usableHeight = fullHeight - statusBarHeight - navBarHeight

        val (targetCenterX, targetCenterY) = if (hasValidSavedPosition) {
            overrideX!! to overrideY!!
        } else {
            val centerX = fullWidth / 2
            val centerY = statusBarHeight + usableHeight / 2
            centerX to centerY
        }

        val (targetX, targetY) = centerToLayoutPosition(targetCenterX, targetCenterY, dotSize)

        layoutParams = createBallLayoutParams(dotSize, dotSize, targetX, targetY)

        val inflater = LayoutInflater.from(this)
        val view = inflater.inflate(R.layout.view_floating_dot, null)

        val root = view.findViewById<FrameLayout>(R.id.rootBall)
        val txtNumber = view.findViewById<TextView>(R.id.txtNumber)

        if (isWorkflowTask) {
            txtNumber.text = displayNumber.coerceAtLeast(1).toString()
        } else {
            if (!hasValidSavedPosition) {
                txtNumber.text = "1"
            }
        }

        updateDotAppearance(view, dotSize, themeId)

        root.setOnTouchListener(
            createTouchListener(
                view,
                if (isWorkflowTask) stepIndex else 1,
                if (isWorkflowTask) displayNumber else 1
            )
        )

        val (centerX, centerY) = layoutToCenter(layoutParams)
        Log.d(
            "FloatingDot",
            "screen=($fullWidth,$fullHeight), usableHeight=$usableHeight, " +
                    "statusBar=$statusBarHeight, navBar=$navBarHeight, " +
                    "override=($overrideX,$overrideY), finalCenter=($centerX,$centerY), " +
                    "hasValidSaved=$hasValidSavedPosition, isWorkflow=$isWorkflowTask, stepIndex=$stepIndex"
        )

        wm.addView(view, layoutParams)
        floatingDot = view
    }

    private fun addNewWorkflowEditableDot(
        stepIndex: Int,
        displayNumber: Int,
        centerX: Int,
        centerY: Int
    ) {
        val wm = windowManager ?: return

        if (!ensureOverlayPermissionOrStop()) return

        val dotSize = ensureBallDiameterPx()

        val (layoutX, layoutY) = centerToLayoutPosition(centerX, centerY, dotSize)

        layoutParams = createBallLayoutParams(dotSize, dotSize, layoutX, layoutY)

        val inflater = LayoutInflater.from(this)
        val view = inflater.inflate(R.layout.view_floating_dot, null)
        val root = view.findViewById<FrameLayout>(R.id.rootBall)
        val txtNumber = view.findViewById<TextView>(R.id.txtNumber)

        txtNumber.text = displayNumber.coerceAtLeast(1).toString()

        updateDotAppearance(view, dotSize, currentThemeId)

        root.setOnTouchListener(
            createTouchListener(
                view,
                stepIndex,
                displayNumber
            )
        )

        wm.addView(view, layoutParams)

        this.floatingDot = view
        this.configForDot = view
        this.isWorkflowTask = true
        this.stepIndex = stepIndex
        this.displayNumber = displayNumber

        setWorkflowClickDefaults()

        commitConfigToFlutter(
            isWorkflow = true,
            stepIndex = stepIndex,
            name = currentTaskName,
        )
    }

    private fun removeFloatingDot() {
        floatingDot?.let { view ->
            runCatching {
                windowManager?.removeView(view)
            }
        }
        floatingDot = null
    }

    // ---------------- 悬浮球触摸 ----------------

    private fun createTouchListener(
        view: View,
        stepIndexForDot: Int?,
        displayNumberForDot: Int?
    ): View.OnTouchListener {
        return object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            private var isClick = false
            private var downTime = 0L

            override fun onTouch(v: View?, event: MotionEvent?): Boolean {
                when (event?.action) {
                    MotionEvent.ACTION_DOWN -> {
                        isClick = true
                        downTime = System.currentTimeMillis()
                        initialX = layoutParams.x
                        initialY = layoutParams.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY

                        val target = v ?: view
                        target.animate()
                            .scaleX(0.9f)
                            .scaleY(0.9f)
                            .setDuration(100)
                            .start()
                    }

                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()

                        if (dx * dx + dy * dy > 9) {
                            isClick = false
                        }

                        val dm = resources.displayMetrics
                        val screenWidth = dm.widthPixels
                        val screenHeight = dm.heightPixels

                        val ballSize = layoutParams.width

                        val visibleAreaX = (ballSize * 0.85f).toInt()
                        val topSafe = 24.dpToPx()
                        val bottomSafe = 24.dpToPx()

                        var newX = initialX + dx
                        var newY = initialY + dy

                        newX = newX.coerceIn(-ballSize + visibleAreaX, screenWidth - visibleAreaX)
                        newY = newY.coerceIn(
                            topSafe,
                            screenHeight - ballSize - bottomSafe
                        )

                        layoutParams.x = newX
                        layoutParams.y = newY
                        windowManager?.updateViewLayout(view, layoutParams)

                        if (configView != null && this@FloatingDotService::configLayoutParams.isInitialized) {
                            configPanelView?.let { placeConfigPanelSmart(it) }
                            windowManager?.updateViewLayout(configView, configLayoutParams)
                        }
                    }

                    MotionEvent.ACTION_UP -> {
                        val target = v ?: view
                        target.animate()
                            .scaleX(1f)
                            .scaleY(1f)
                            .setDuration(100)
                            .start()

                        val loc = IntArray(2)
                        view.getLocationOnScreen(loc)
                        layoutParams.x = loc[0]
                        layoutParams.y = loc[1]

                        val movedCenter = layoutToCenter(layoutParams)
                        notifyDotMoved(
                            movedCenter.first,
                            movedCenter.second,
                            stepIndexForDot,
                            displayNumberForDot
                        )

                        val duration = System.currentTimeMillis() - downTime

                        if (isClick && duration < 300) {
                            floatingDot = view
                            editingFromPreview = false

                            if (isWorkflowTask && stepIndexForDot != null && displayNumberForDot != null) {
                                stepIndex = stepIndexForDot
                                displayNumber = displayNumberForDot
                            }

                            onDotClicked()
                        }
                    }

                    MotionEvent.ACTION_CANCEL -> {
                        val target = v ?: view
                        target.animate()
                            .scaleX(1f)
                            .scaleY(1f)
                            .setDuration(100)
                            .start()
                    }
                }
                return true
            }
        }
    }

    private fun createWorkflowPreviewTouchListener(holder: WorkflowDotHolder): View.OnTouchListener {
        return object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            private var isClick = false
            private var downTime = 0L

            override fun onTouch(v: View?, event: MotionEvent?): Boolean {
                val view = holder.view
                when (event?.action) {
                    MotionEvent.ACTION_DOWN -> {
                        isClick = true
                        downTime = System.currentTimeMillis()
                        initialX = holder.lp.x
                        initialY = holder.lp.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY

                        val target = v ?: view
                        target.animate()
                            .scaleX(0.9f)
                            .scaleY(0.9f)
                            .setDuration(100)
                            .start()
                    }

                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()

                        if (dx * dx + dy * dy > 9) {
                            isClick = false
                        }

                        val dm = resources.displayMetrics
                        val screenWidth = dm.widthPixels
                        val screenHeight = dm.heightPixels
                        val ballSize = holder.lp.width

                        val visibleAreaX = (ballSize * 0.85f).toInt()
                        val topSafe = 24.dpToPx()
                        val bottomSafe = 24.dpToPx()

                        var newX = initialX + dx
                        var newY = initialY + dy

                        newX = newX.coerceIn(-ballSize + visibleAreaX, screenWidth - visibleAreaX)
                        newY = newY.coerceIn(topSafe, screenHeight - ballSize - bottomSafe)

                        holder.lp.x = newX
                        holder.lp.y = newY
                        windowManager?.updateViewLayout(view, holder.lp)

                        if (floatingDot === view) {
                            layoutParams = holder.lp
                            if (configView != null && this@FloatingDotService::configLayoutParams.isInitialized) {
                                configPanelView?.let { placeConfigPanelSmart(it) }
                                windowManager?.updateViewLayout(configView, configLayoutParams)
                            }
                        }
                    }

                    MotionEvent.ACTION_UP -> {
                        val target = v ?: view
                        target.animate()
                            .scaleX(1f)
                            .scaleY(1f)
                            .setDuration(100)
                            .start()

                        val movedCenter = layoutToCenter(holder.lp)
                        notifyDotMoved(
                            movedCenter.first,
                            movedCenter.second,
                            holder.stepIndex,
                            holder.displayNumber
                        )

                        val duration = System.currentTimeMillis() - downTime
                        if (isClick && duration < 300) {
                            moveCurrentEditableDotToPreview(excludeView = view)

                            val maxDisplayNumber =
                                (workflowPreviewDots.map { it.displayNumber } + holder.displayNumber)
                                    .maxOrNull() ?: holder.displayNumber

                            workflowPreviewDots.remove(holder)
                            floatingDot = view
                            layoutParams = holder.lp
                            isWorkflowTask = true
                            stepIndex = holder.stepIndex
                            displayNumber = holder.displayNumber
                            editingFromPreview = holder.displayNumber < maxDisplayNumber

                            applyHolderConfigToCurrent(holder)

                            onDotClicked()
                        }
                    }

                    MotionEvent.ACTION_CANCEL -> {
                        val target = v ?: view
                        target.animate()
                            .scaleX(1f)
                            .scaleY(1f)
                            .setDuration(100)
                            .start()
                    }
                }
                return true
            }
        }
    }

    private fun moveCurrentEditableDotToPreview(excludeView: View? = null) {
        val currentView = floatingDot ?: return
        if (currentView === excludeView) return

        if (!isWorkflowTask || !this::layoutParams.isInitialized) return

        val existingIndex = workflowPreviewDots.indexOfFirst { it.stepIndex == stepIndex }

        if (existingIndex >= 0) {
            val h = workflowPreviewDots[existingIndex]
            h.lp.x = layoutParams.x
            h.lp.y = layoutParams.y
            h.clickCount = clickCount
            h.isRandom = isRandomMode
            h.fixedIntervalMs = fixedIntervalMs
            h.randomMinMs = randomMinMs
            h.randomMaxMs = randomMaxMs
            h.loopCount = loopCount
            h.loopInfinite = loopInfinite
        } else {
            val copyLp = WindowManager.LayoutParams(
                layoutParams.width,
                layoutParams.height,
                layoutParams.type,
                layoutParams.flags,
                layoutParams.format
            ).apply {
                gravity = layoutParams.gravity
                x = layoutParams.x
                y = layoutParams.y
            }

            val holder = WorkflowDotHolder(
                view = currentView,
                lp = copyLp,
                stepIndex = stepIndex,
                displayNumber = displayNumber,
                themeId = currentThemeId ?: "tech_blue",
                clickCount = clickCount,
                isRandom = isRandomMode,
                fixedIntervalMs = fixedIntervalMs,
                randomMinMs = randomMinMs,
                randomMaxMs = randomMaxMs,
                loopCount = loopCount,
                loopInfinite = loopInfinite,
            )
            workflowPreviewDots.add(holder)
        }

        val root = currentView.findViewById<FrameLayout>(R.id.rootBall)
        root.setOnTouchListener(createWorkflowPreviewTouchListener(workflowPreviewDots.last()))
    }

    private fun onDotClicked() {
        Log.d(
            "FloatingDotService",
            "Floating dot tapped -> toggle/switch config panel (workflow=$isWorkflowTask, step=$stepIndex, display=$displayNumber)"
        )
        toggleConfigPanel()
    }

    private fun restoreLatestWorkflowDefaultsIfEditingPreview() {
        if (isWorkflowTask && editingFromPreview) {
            if (latestConfigInitialized) {
                clickCount = latestClickCount
                isRandomMode = latestIsRandom
                fixedIntervalMs = latestFixedIntervalMs
                randomMinMs = latestRandomMinMs
                randomMaxMs = latestRandomMaxMs
                loopCount = latestLoopCount
                loopInfinite = latestLoopInfinite
            } else {
                setWorkflowClickDefaults()
            }
        }
    }

    fun applyExternalConfigUpdate(
        taskId: String?,
        isWorkflow: Boolean?,
        stepIndex: Int?,
        clickCount: Int?,
        isRandom: Boolean?,
        fixedIntervalMs: Long?,
        randomMinMs: Long?,
        randomMaxMs: Long?,
        loopCount: Int?,
        loopInfinite: Boolean?,
    ) {
        if (taskId != null) {
            if (currentTaskId == null) {
                currentTaskId = taskId
            } else if (taskId != currentTaskId) {
                return
            }
        }

        val shouldUpdateLatest = isWorkflow == true && !editingFromPreview

        clickCount?.let {
            this.clickCount = it
            if (shouldUpdateLatest) latestClickCount = it
        }
        isRandom?.let {
            isRandomMode = it
            if (shouldUpdateLatest) latestIsRandom = it
        }
        fixedIntervalMs?.let {
            this.fixedIntervalMs = it
            if (shouldUpdateLatest) latestFixedIntervalMs = it
        }
        randomMinMs?.let {
            this.randomMinMs = it
            if (shouldUpdateLatest) latestRandomMinMs = it
        }
        randomMaxMs?.let {
            this.randomMaxMs = it
            if (shouldUpdateLatest) latestRandomMaxMs = it
        }
        val allowLoopUpdate = isWorkflow == true && stepIndex == 1

        if (allowLoopUpdate) {
            loopCount?.let {
                this.loopCount = it
                if (shouldUpdateLatest) latestLoopCount = it
            }
            loopInfinite?.let {
                this.loopInfinite = it
                if (shouldUpdateLatest) latestLoopInfinite = it
            }
        }

        if (isWorkflow == true) {
            if (shouldUpdateLatest) {
                latestConfigInitialized = true
            }
            stepIndex?.let { idx ->
                workflowPreviewDots.find { it.stepIndex == idx }?.let { holder ->
                    clickCount?.let { holder.clickCount = it }
                    isRandom?.let { holder.isRandom = it }
                    fixedIntervalMs?.let { holder.fixedIntervalMs = it }
                    randomMinMs?.let { holder.randomMinMs = it }
                    randomMaxMs?.let { holder.randomMaxMs = it }
                    if (allowLoopUpdate) {
                        loopCount?.let { holder.loopCount = it }
                        loopInfinite?.let { holder.loopInfinite = it }
                    }
                }
            }
        }
    }

    // ---------------- 配置面板：显示 / 隐藏 ----------------

    private fun toggleConfigPanel() {
        val currentDot = floatingDot ?: return

        if (configView == null) {
            showConfigPanel(currentDot)
        } else {
            if (configForDot === currentDot) {
                removeConfigPanel()
            } else {
                removeConfigPanel()
                showConfigPanel(currentDot)
            }
        }
    }

    private fun showConfigPanel(sourceDot: View? = floatingDot) {
        val wm = windowManager ?: return
        if (floatingDot == null) return

        removeConfigPanel()

        val dotView = sourceDot ?: floatingDot
        if (dotView != null && this::layoutParams.isInitialized) {
            val loc = IntArray(2)
            dotView.getLocationOnScreen(loc)
            layoutParams.x = loc[0]
            layoutParams.y = loc[1]
        }

        val type = overlayLayoutType

        configLayoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN or
                    WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        }

        val inflater = LayoutInflater.from(this)
        val rootView =
            inflater.inflate(R.layout.view_floating_config_panel, null) as FrameLayout
        val panelView = rootView.findViewById<ViewGroup>(R.id.configPanel)

        val btnEdit: TextView? = rootView.findViewById(R.id.btnEditTask)
        val btnExecute: TextView? = rootView.findViewById(R.id.btnExecuteTask)
        val btnNext: TextView? = rootView.findViewById(R.id.btnNextStep)

        if (!isWorkflowTask) {
            btnExecute?.visibility = View.VISIBLE
            btnEdit?.visibility = View.VISIBLE
            btnNext?.visibility = View.GONE
        } else {
            val totalSteps = workflowPreviewDots.size + 1
            val isLast = !editingFromPreview
            val isFirst = (displayNumber == 1)
            val canAddMore = totalSteps < MAX_WORKFLOW_STEPS

            btnEdit?.visibility = View.VISIBLE

            when {
                totalSteps == 1 -> {
                    btnExecute?.visibility = View.VISIBLE
                    btnNext?.visibility = if (canAddMore) View.VISIBLE else View.GONE
                }

                totalSteps >= MAX_WORKFLOW_STEPS -> {
                    btnExecute?.visibility = if (isFirst) View.VISIBLE else View.GONE
                    btnNext?.visibility = View.GONE
                }

                else -> {
                    btnExecute?.visibility = if (isFirst) View.VISIBLE else View.GONE
                    btnNext?.visibility = if (isLast) View.VISIBLE else View.GONE
                }
            }
        }

        rootView.setOnTouchListener { _, event ->
            if (event?.action == MotionEvent.ACTION_DOWN) {
                val rect = Rect()
                panelView.getGlobalVisibleRect(rect)
                val inside = rect.contains(event.rawX.toInt(), event.rawY.toInt())
                if (!inside) {
                    removeConfigPanel()
                    return@setOnTouchListener true
                }
            }
            false
        }

        btnEdit?.setOnClickListener {
            val (centerX, centerY) = layoutToCenter(layoutParams)
            val payload = mutableMapOf<String, Any?>(
                "taskId" to currentTaskId,
                "isWorkflow" to isWorkflowTask,
                "stepIndex" to stepIndex,
                "displayNumber" to displayNumber,
                "x" to centerX,
                "y" to centerY,
                "ballDiameter" to floatingBallDiameterPx.pxToDp(),
            )
            AutoClickChannelHolder.channel?.invokeMethod("onFloatingEditRequested", payload)

            val intent = Intent(applicationContext, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                )
            }
            startActivity(intent)

            removeConfigPanel()
        }

        // ⭐ 统一：执行按钮只负责把当前配置同步回 Flutter + 触发 executeAfterSave
        //     真正的执行（单任务 / 工作流）都交给 Flutter / Hive 那条稳定逻辑
        btnExecute?.setOnClickListener {
            ensureAccessibilityOrShowSettings {
                hideAllDotsForExecution()

                commitConfigToFlutter(
                    isWorkflow = isWorkflowTask,
                    stepIndex = if (isWorkflowTask) stepIndex else 1,
                    name = currentTaskName,
                    executeAfterSave = true,
                )

                removeConfigPanel()
            }
        }

        btnNext?.setOnClickListener {
            btnNext.isEnabled = false
            btnNext.visibility = View.GONE

            if (!isWorkflowTask) {
                removeConfigPanel()
                return@setOnClickListener
            }
            val currentStep = stepIndex.coerceAtLeast(1)

            commitConfigToFlutter(
                isWorkflow = true,
                stepIndex = currentStep,
                name = currentTaskName,
            )

            val allSteps = (workflowPreviewDots.map { it.stepIndex } + currentStep).distinct()
            val stepCount = allSteps.size
            if (stepCount >= MAX_WORKFLOW_STEPS) {
                removeConfigPanel()
                return@setOnClickListener
            }

            val newStepIndex = (allSteps.maxOrNull() ?: currentStep) + 1
            val newDisplayNumber = stepCount + 1

            floatingDot?.let { currentView ->
                val existingIndex = workflowPreviewDots.indexOfFirst { it.stepIndex == currentStep }

                val holder = if (existingIndex >= 0) {
                    val h = workflowPreviewDots[existingIndex]
                    h.lp.x = layoutParams.x
                    h.lp.y = layoutParams.y
                    h.clickCount = clickCount
                    h.isRandom = isRandomMode
                    h.fixedIntervalMs = fixedIntervalMs
                    h.randomMinMs = randomMinMs
                    h.randomMaxMs = randomMaxMs
                    h.loopCount = loopCount
                    h.loopInfinite = loopInfinite
                    h
                } else {
                    val copyLp = WindowManager.LayoutParams(
                        layoutParams.width,
                        layoutParams.height,
                        layoutParams.type,
                        layoutParams.flags,
                        layoutParams.format
                    ).apply {
                        gravity = layoutParams.gravity
                        x = layoutParams.x
                        y = layoutParams.y
                    }

                    WorkflowDotHolder(
                        view = currentView,
                        lp = copyLp,
                        stepIndex = currentStep,
                        displayNumber = this.displayNumber.coerceAtLeast(1),
                        themeId = currentThemeId ?: "tech_blue",
                        clickCount = clickCount,
                        isRandom = isRandomMode,
                        fixedIntervalMs = fixedIntervalMs,
                        randomMinMs = randomMinMs,
                        randomMaxMs = randomMaxMs,
                        loopCount = loopCount,
                        loopInfinite = loopInfinite,
                    ).also { newHolder ->
                        workflowPreviewDots.add(newHolder)
                    }
                }

                val root = currentView.findViewById<FrameLayout>(R.id.rootBall)
                root.setOnTouchListener(createWorkflowPreviewTouchListener(holder))
            }

            val dm = resources.displayMetrics
            val newCenterX = dm.widthPixels / 2
            val newCenterY = dm.heightPixels / 2

            addNewWorkflowEditableDot(newStepIndex, newDisplayNumber, newCenterX, newCenterY)
            removeConfigPanel()
        }

        placeConfigPanelSmart(panelView)

        wm.addView(rootView, configLayoutParams)
        configView = rootView
        configPanelView = panelView

        // Popover show animation (subtle)
        panelView.alpha = 0f
        panelView.scaleX = 0.96f
        panelView.scaleY = 0.96f
        panelView.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(140)
            .start()

        configForDot = sourceDot
    }

    private fun removeConfigPanel() {
        configView?.let { v ->
            windowManager?.removeView(v)
        }
        configView = null
        configPanelView = null
        configForDot = null
    }

    private fun placeConfigPanelSmart(panelView: View) {
        val dm = resources.displayMetrics
        val screenW = dm.widthPixels
        val screenH = dm.heightPixels
        val margin = 10.dpToPx()

        // measure panel
        panelView.measure(
            View.MeasureSpec.makeMeasureSpec(screenW, View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(screenH, View.MeasureSpec.AT_MOST)
        )
        val panelW = panelView.measuredWidth
        val panelH = panelView.measuredHeight

        // ball position
        val dotSize = layoutParams.width
        val (ballX, ballY) =
            (configForDot ?: floatingDot)?.let { dot ->
                val loc = IntArray(2)
                dot.getLocationOnScreen(loc)
                loc[0] to loc[1]
            } ?: (layoutParams.x to layoutParams.y)

        val ballCenterY = ballY + dotSize / 2
        val ballRight = ballX + dotSize

        // ===============================
        // 1️⃣ 只决定左右（不允许上下）
        // ===============================
        val canPlaceRight = ballRight + margin + panelW <= screenW
        val canPlaceLeft = ballX - margin - panelW >= 0

        val targetLeft = when {
            canPlaceRight -> ballRight + margin
            canPlaceLeft -> ballX - panelW - margin
            else -> {
                // 两边都放不下 → 强制贴屏幕边
                (screenW - panelW) / 2
            }
        }

        // ===============================
        // 2️⃣ Y 永远对齐球中心
        // ===============================
        var targetTop = ballCenterY - panelH / 2

        // 只做“最小限度”的 Y 保护，不允许漂移
        val minTop = margin
        val maxTop = screenH - panelH - margin
        targetTop = targetTop.coerceIn(minTop, maxTop)

        // ===============================
        // apply
        // ===============================
        val lp = panelView.layoutParams as FrameLayout.LayoutParams
        lp.leftMargin = targetLeft
        lp.topMargin = targetTop
        panelView.layoutParams = lp
    }


    private fun focusAndShowKeyboard(target: EditText) {
        target.post {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            if (!target.isAttachedToWindow || target.windowToken == null || imm == null) return@post

            target.requestFocus()
            target.setSelection(target.text?.length ?: 0)

            if (!target.hasWindowFocus()) {
                target.viewTreeObserver.addOnWindowFocusChangeListener(
                    object : android.view.ViewTreeObserver.OnWindowFocusChangeListener {
                        override fun onWindowFocusChanged(hasFocus: Boolean) {
                            if (!hasFocus || target.windowToken == null) return

                            target.viewTreeObserver.removeOnWindowFocusChangeListener(this)
                            imm.showSoftInput(target, InputMethodManager.SHOW_IMPLICIT)
                        }
                    },
                )
                return@post
            }

            if (imm.isActive(target)) {
                imm.showSoftInput(target, InputMethodManager.SHOW_IMPLICIT)
            } else if (target.hasWindowFocus()) {
                imm.showSoftInput(target, InputMethodManager.SHOW_IMPLICIT)
            }
        }
    }

    private fun notifyDotMoved(
        centerX: Int,
        centerY: Int,
        stepIndexForDot: Int?,
        displayNumberForDot: Int?
    ) {
        val payload = mutableMapOf<String, Any?>(
            "taskId" to currentTaskId,
            "isWorkflow" to isWorkflowTask,
            "x" to centerX,
            "y" to centerY,
            "ballDiameter" to floatingBallDiameterPx.pxToDp(),
        )
        stepIndexForDot?.let {
            payload["stepIndex"] = it
            payload["index"] = it
        }
        displayNumberForDot?.let { payload["displayNumber"] = it }

        AutoClickChannelHolder.channel?.invokeMethod("onFloatingDotMoved", payload)
    }

    private fun commitConfigToFlutter(
        isWorkflow: Boolean,
        stepIndex: Int,
        name: String?,
        executeAfterSave: Boolean = false
    ) {
        val (centerX, centerY) = layoutToCenter(layoutParams)

        val includeLoop = stepIndex == 1 || displayNumber == 1
        val loopValue = if (includeLoop) {
            if (loopInfinite) 0 else loopCount
        } else {
            null
        }

        val config = mutableMapOf<String, Any?>(
            "taskId" to currentTaskId,
            "isWorkflow" to isWorkflow,
            "stepIndex" to stepIndex,
            "index" to stepIndex,
            "name" to name,
            "description" to "来自悬浮球配置保存",
            "themeId" to currentThemeId,
            "x" to centerX,
            "y" to centerY,
            "clickCount" to clickCount,
            "isRandom" to isRandomMode,
            "fixedIntervalMs" to fixedIntervalMs,
            "randomMinMs" to randomMinMs,
            "randomMaxMs" to randomMaxMs,
            "executeAfterSave" to executeAfterSave,
            "ballDiameter" to floatingBallDiameterPx.pxToDp(),
        )

        config["displayNumber"] = displayNumber
        if (includeLoop) {
            config["loopCount"] = loopValue
            config["loopInfinite"] = loopInfinite
        }

        Log.i(
            "FloatingDotService",
            "commitConfigToFlutter stepIndex=$stepIndex displayNumber=$displayNumber includeLoop=$includeLoop loopCount=$loopValue loopInfinite=$loopInfinite executeAfterSave=$executeAfterSave"
        )

        AutoClickChannelHolder.channel?.invokeMethod(
            "onFloatingConfigSaved",
            config
        )
    }

    fun hideAllDotsForExecution() {
        if (dotsHiddenForExecution) return
        dotsHiddenForExecution = true

        removeConfigPanel()
        floatingDot?.let { view ->
            runCatching { windowManager?.removeView(view) }
        }
        workflowPreviewDots.forEach { holder ->
            runCatching { windowManager?.removeView(holder.view) }
        }
    }

    fun showDotsAfterExecution() {
        if (!dotsHiddenForExecution) return
        dotsHiddenForExecution = false

        val wm = windowManager ?: return
        floatingDot?.let { view ->
            runCatching { wm.addView(view, layoutParams) }
        }
        workflowPreviewDots.forEach { holder ->
            runCatching { wm.addView(holder.view, holder.lp) }
        }
    }

    // ---------------- 工具 & 主题颜色 ----------------

    private fun loadSavedBallDiameterPx(): Int {
        return FloatingBallPreferences.loadDiameterDp(this).dpToPx()
    }

    private fun saveBallDiameterDp(dp: Int) {
        val clamped = FloatingBallPreferences.saveDiameterDp(this, dp)
        floatingBallDiameterPx = clamped.dpToPx()
        applyDiameterToAllDots(floatingBallDiameterPx)
    }

    private fun applyDiameterToAllDots(diameterPx: Int) {
        floatingDot?.let { view ->
            val currentCenter = layoutToCenter(layoutParams)
            layoutParams.width = diameterPx
            layoutParams.height = diameterPx
            val (layoutX, layoutY) = centerToLayoutPosition(
                currentCenter.first,
                currentCenter.second,
                diameterPx
            )
            layoutParams.x = layoutX
            layoutParams.y = layoutY
            updateDotAppearance(view, diameterPx, currentThemeId)
            windowManager?.updateViewLayout(view, layoutParams)
        }

        workflowPreviewDots.forEach { holder ->
            val center = layoutToCenter(holder.lp)
            holder.lp.width = diameterPx
            holder.lp.height = diameterPx
            val (layoutX, layoutY) = centerToLayoutPosition(center.first, center.second, diameterPx)
            holder.lp.x = layoutX
            holder.lp.y = layoutY
            updateDotAppearance(holder.view, diameterPx, holder.themeId)
            windowManager?.updateViewLayout(holder.view, holder.lp)
        }

        if (configView != null && this::configLayoutParams.isInitialized) {
            configPanelView?.let { placeConfigPanelSmart(it) }
            windowManager?.updateViewLayout(configView, configLayoutParams)
        }
    }

    private fun updateDotBackground(view: View, sizePx: Int, themeId: String?) {
        val root = view.findViewById<FrameLayout>(R.id.rootBall)
        val themeColors = resolveTheme(themeId ?: currentThemeId ?: "tech_blue")
        val drawable = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            gradientType = GradientDrawable.RADIAL_GRADIENT
            val radius = (sizePx * 0.8f)
            setGradientRadius(radius)
            colors = intArrayOf(themeColors.centerColor, themeColors.edgeColor)
        }
        root.background = drawable
    }

    private fun calculateNumberTextSizeSp(diameterPx: Int): Float {
        val diameterDp = diameterPx.pxToDp().toFloat()
        val defaultDp = FloatingBallPreferences.DEFAULT_BALL_DIAMETER_DP.toFloat()
        val baseTextSizeSp = 24f

        return if (diameterDp >= defaultDp) {
            baseTextSizeSp
        } else {
            baseTextSizeSp * (diameterDp / defaultDp)
        }
    }

    private fun updateDotAppearance(view: View, sizePx: Int, themeId: String?) {
        val txtNumber = view.findViewById<TextView>(R.id.txtNumber)
        val themeColors = resolveTheme(themeId ?: currentThemeId ?: "tech_blue")
        updateDotBackground(view, sizePx, themeId)
        txtNumber.setTextColor(themeColors.textColor)
        txtNumber.setTextSize(TypedValue.COMPLEX_UNIT_SP, calculateNumberTextSizeSp(sizePx))
    }

    private fun layoutToCenter(lp: WindowManager.LayoutParams): Pair<Int, Int> {
        val centerX = lp.x + lp.width / 2
        val centerY = lp.y + lp.height / 2
        return centerX to centerY
    }

    private fun centerToLayoutPosition(centerX: Int, centerY: Int, size: Int): Pair<Int, Int> {
        val layoutX = centerX - size / 2
        val layoutY = centerY - size / 2
        return layoutX to layoutY
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }

    // ====== 无障碍服务检查（执行前提示） ======

    private fun isMyAccessibilityServiceEnabled(): Boolean {
        val serviceComponent = ComponentName(this, AutoClickAccessibilityService::class.java)
        val serviceId = serviceComponent.flattenToString()

        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)

        while (colonSplitter.hasNext()) {
            val enabledService = colonSplitter.next()
            if (enabledService.equals(serviceId, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    /**
     * 确保无障碍服务已开启：
     * - 已开启：执行 onGranted()
     * - 未开启：弹 Toast + 打开系统无障碍设置
     */
    private fun ensureAccessibilityOrShowSettings(onGranted: () -> Unit) {
        if (isMyAccessibilityServiceEnabled()) {
            onGranted()
        } else {
            Toast.makeText(
                this,
                "请先在系统设置中开启「AutoClick 无障碍服务」",
                Toast.LENGTH_LONG
            ).show()
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }

    private fun Int.dpToPx(): Int = (this * resources.displayMetrics.density).roundToInt()
    private fun Int.pxToDp(): Int = (this / resources.displayMetrics.density).roundToInt()

    private fun getStatusBarHeight(): Int {
        val resId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resId > 0) resources.getDimensionPixelSize(resId) else 0
    }

    private fun getNavigationBarHeight(): Int {
        val resId = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (resId > 0) resources.getDimensionPixelSize(resId) else 0
    }

    private fun resolveTheme(themeId: String): BallThemeColors {
        return when (themeId) {
            "morandi_green" -> BallThemeColors(
                centerColor = 0xFFD8E6D3.toInt(),
                edgeColor = 0xFF6C8A73.toInt(),
                textColor = 0xFF2B2A2A.toInt(),
            )

            "coral" -> BallThemeColors(
                centerColor = 0xFFFFD6D6.toInt(),
                edgeColor = 0xFFFF6F6F.toInt(),
                textColor = 0xFFFFFFFF.toInt(),
            )

            "bright_yellow" -> BallThemeColors(
                centerColor = 0xFFFFF7B2.toInt(),
                edgeColor = 0xFFFFD600.toInt(),
                textColor = 0xFF2B2A2A.toInt(),
            )

            "dark_gray" -> BallThemeColors(
                centerColor = 0xFF4A4A4A.toInt(),
                edgeColor = 0xFF1E1E1E.toInt(),
                textColor = 0xFFFFFFFF.toInt(),
            )

            "neon_purple" -> BallThemeColors(
                centerColor = 0xFFE0C3FC.toInt(),
                edgeColor = 0xFF8E2DE2.toInt(),
                textColor = 0xFFFFFFFF.toInt(),
            )

            "cyan" -> BallThemeColors(
                centerColor = 0xFFB2FEFA.toInt(),
                edgeColor = 0xFF0ED2F7.toInt(),
                textColor = 0xFF034057.toInt(),
            )

            "soft_orange" -> BallThemeColors(
                centerColor = 0xFFFFE0B2.toInt(),
                edgeColor = 0xFFFF9800.toInt(),
                textColor = 0xFF4A2C00.toInt(),
            )

            else -> BallThemeColors(
                centerColor = 0xFF4DA8FF.toInt(),
                edgeColor = 0xFF0052CC.toInt(),
                textColor = 0xFFFFFFFF.toInt(),
            )
        }
    }

    data class BallThemeColors(
        val centerColor: Int,
        val edgeColor: Int,
        val textColor: Int,
    )

    private fun resetClickConfigToDefault() {
        setSingleClickDefaults()
        loopCount = null
        loopInfinite = false
    }

    private fun setSingleClickDefaults() {
        clickCount = 10
        isRandomMode = false
        fixedIntervalMs = 1000L
        randomMinMs = 500L
        randomMaxMs = 1500L
    }

    private fun setWorkflowClickDefaults() {
        clickCount = 1
        isRandomMode = false
        fixedIntervalMs = 50L
        randomMinMs = 50L
        randomMaxMs = 200L

        latestConfigInitialized = true
        latestClickCount = clickCount
        latestIsRandom = isRandomMode
        latestFixedIntervalMs = fixedIntervalMs
        latestRandomMinMs = randomMinMs
        latestRandomMaxMs = randomMaxMs
        latestLoopCount = loopCount
        latestLoopInfinite = loopInfinite
    }

    private fun applyHolderConfigToCurrent(holder: WorkflowDotHolder) {
        setWorkflowClickDefaults()
        holder.clickCount?.let { clickCount = it }
        holder.isRandom?.let { isRandomMode = it }
        holder.fixedIntervalMs?.let { fixedIntervalMs = it }
        holder.randomMinMs?.let { randomMinMs = it }
        holder.randomMaxMs?.let { randomMaxMs = it }
        loopCount = holder.loopCount
        loopInfinite = holder.loopInfinite ?: false
    }

    private fun addPreviewDotAt(
        centerX: Int,
        centerY: Int,
        stepIndex: Int,
        displayNumber: Int,
        themeId: String,
        clickCount: Int?,
        isRandom: Boolean?,
        fixedIntervalMs: Long?,
        randomMinMs: Long?,
        randomMaxMs: Long?,
        loopCount: Int?,
        loopInfinite: Boolean?,
    ) {
        val wm = windowManager ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            return
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        if (floatingBallDiameterPx == 0) {
            floatingBallDiameterPx = loadSavedBallDiameterPx()
        }
        val dotSize = floatingBallDiameterPx

        val (layoutX, layoutY) = centerToLayoutPosition(centerX, centerY, dotSize)

        val lp = WindowManager.LayoutParams(
            dotSize,
            dotSize,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = layoutX
            y = layoutY
        }

        val inflater = LayoutInflater.from(this)
        val view = inflater.inflate(R.layout.view_floating_dot, null)
        val root = view.findViewById<FrameLayout>(R.id.rootBall)
        val txtNumber = view.findViewById<TextView>(R.id.txtNumber)

        updateDotAppearance(view, dotSize, themeId)
        txtNumber.text = displayNumber.coerceAtLeast(1).toString()

        wm.addView(view, lp)

        val holder = WorkflowDotHolder(
            view = view,
            lp = lp,
            stepIndex = stepIndex,
            displayNumber = displayNumber,
            themeId = themeId,
            clickCount = clickCount,
            isRandom = isRandom,
            fixedIntervalMs = fixedIntervalMs,
            randomMinMs = randomMinMs,
            randomMaxMs = randomMaxMs,
            loopCount = loopCount,
            loopInfinite = loopInfinite,
        )

        root.setOnTouchListener(createWorkflowPreviewTouchListener(holder))

        workflowPreviewDots.add(holder)
    }

    private fun clearAllDots() {
        removeFloatingDot()
        clearWorkflowPreviewDots()
        dotsHiddenForExecution = false
    }
    // 删除指定步骤的工作流悬浮球（从 Flutter 调过来）
    fun removeWorkflowSteps(stepIndexes: List<Int>) {
        if (stepIndexes.isEmpty()) return
        val wm = windowManager ?: return

        // 1. 先删掉预览球里的对应步骤
        val iterator = workflowPreviewDots.iterator()
        while (iterator.hasNext()) {
            val holder = iterator.next()
            if (stepIndexes.contains(holder.stepIndex)) {
                runCatching { wm.removeView(holder.view) }
                iterator.remove()
            }
        }

        // 2. 如果当前“可编辑球”也在删除列表里，一并删掉
        if (isWorkflowTask && this::layoutParams.isInitialized) {
            if (stepIndexes.contains(stepIndex)) {
                floatingDot?.let { runCatching { wm.removeView(it) } }
                floatingDot = null

                // 可选：把剩下的最后一颗球提升为“可编辑球”
                val last = workflowPreviewDots.maxByOrNull { it.displayNumber }
                if (last != null) {
                    floatingDot = last.view
                    layoutParams = last.lp
                    stepIndex = last.stepIndex
                    displayNumber = last.displayNumber

                    val root = last.view.findViewById<FrameLayout>(R.id.rootBall)
                    root.setOnTouchListener(
                        createTouchListener(last.view, last.stepIndex, last.displayNumber)
                    )

                    // 从预览列表里移除，因为它现在是“可编辑球”
                    workflowPreviewDots.remove(last)
                }
            }
        }

        // 注意：这里 **不做重新编号**，保持 displayNumber 和 Flutter 那边保存的一致
    }

}
