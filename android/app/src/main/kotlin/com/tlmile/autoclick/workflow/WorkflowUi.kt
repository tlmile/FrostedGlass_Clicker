package com.tlmile.autoclick.workflow

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import com.tlmile.autoclick.FloatingDotView
import com.tlmile.autoclick.R
import java.util.concurrent.atomic.AtomicReference

data class WorkflowStepViewData(
    val workflowId: String,
    val stepIndex: Int,
    val displayNumber: Int,
    val centerX: Int,
    val centerY: Int,
    val diameterPx: Int,
    val themeId: String? = null,
    val clickCount: Int? = null,
    val isRandom: Boolean? = null,
    val fixedIntervalMs: Long? = null,
    val randomMinMs: Long? = null,
    val randomMaxMs: Long? = null,
    val loopCount: Int? = null,
    val loopInfinite: Boolean? = null,
)

class BallHolder(
    context: Context,
    private val windowManager: WindowManager,
) {
    private val inflater = LayoutInflater.from(context)
    private val root: View = inflater.inflate(R.layout.ball, FrameLayout(context), false)
    private val dotView: FloatingDotView = root.findViewById(R.id.dot)
    private val numberView: TextView = root.findViewById(R.id.txtNumber)
    private var layoutParams: WindowManager.LayoutParams? = null
    private var boundStep: WorkflowStepViewData? = null
    private var clickListener: ((WorkflowStepViewData, View) -> Unit)? = null
    private var moveListener: ((WorkflowStepViewData) -> Unit)? = null

    var isAttached: Boolean = false
        private set

    fun bind(
        step: WorkflowStepViewData,
        onClick: ((WorkflowStepViewData, View) -> Unit)?,
        onMove: ((WorkflowStepViewData) -> Unit)?,
    ) {
        boundStep = step
        clickListener = onClick
        moveListener = onMove
        numberView.text = step.displayNumber.toString()
        layoutParams = createLayoutParams(step)
        applyTheme(step.themeId)
        root.setOnTouchListener(createTouchListener())
    }

    private fun applyTheme(themeId: String?) {
        val theme = resolveTheme(themeId)
        dotView.setColors(theme.centerColor, theme.edgeColor)
        numberView.setTextColor(theme.textColor)
    }

    private fun createLayoutParams(step: WorkflowStepViewData): WindowManager.LayoutParams {
        val overlayLayoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        return WindowManager.LayoutParams(
            step.diameterPx,
            step.diameterPx,
            overlayLayoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = step.centerX - step.diameterPx / 2
            y = step.centerY - step.diameterPx / 2
        }
    }

    fun attach() {
        val lp = layoutParams ?: return
        if (isAttached) {
            windowManager.updateViewLayout(root, lp)
            return
        }
        windowManager.addView(root, lp)
        isAttached = true
    }

    fun detach() {
        if (!isAttached) return
        runCatching {
            windowManager.removeViewImmediate(root)
        }
        isAttached = false
    }

    fun rebind(step: WorkflowStepViewData) {
        bind(step, clickListener, moveListener)
        attach()
    }

    fun view(): View = root

    private fun createTouchListener(): View.OnTouchListener {
        return object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            private var isClick = false
            private var downTime = 0L

            override fun onTouch(v: View?, event: MotionEvent?): Boolean {
                val params = layoutParams ?: return false
                when (event?.action) {
                    MotionEvent.ACTION_DOWN -> {
                        isClick = true
                        downTime = System.currentTimeMillis()
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        (v ?: root).animate().scaleX(0.9f).scaleY(0.9f).setDuration(100).start()
                    }

                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        if (dx * dx + dy * dy > 9) {
                            isClick = false
                        }

                        params.x = initialX + dx
                        params.y = initialY + dy
                        windowManager.updateViewLayout(root, params)
                    }

                    MotionEvent.ACTION_UP -> {
                        (v ?: root).animate().scaleX(1f).scaleY(1f).setDuration(100).start()
                        val duration = System.currentTimeMillis() - downTime
                        val centerX = params.x + (boundStep?.diameterPx ?: root.width) / 2
                        val centerY = params.y + (boundStep?.diameterPx ?: root.height) / 2
                        boundStep = boundStep?.copy(centerX = centerX, centerY = centerY)
                        if (!isClick) {
                            boundStep?.let { moveListener?.invoke(it) }
                        }
                        if (isClick && duration < 300) {
                            boundStep?.let { data -> clickListener?.invoke(data, root) }
                        }
                    }

                    MotionEvent.ACTION_CANCEL -> {
                        (v ?: root).animate().scaleX(1f).scaleY(1f).setDuration(100).start()
                    }
                }
                return true
            }
        }
    }
}

private data class BallThemeColors(
    val centerColor: Int,
    val edgeColor: Int,
    val textColor: Int,
)

private fun resolveTheme(themeId: String?): BallThemeColors {
    return when (themeId) {
        "morandi_green" -> BallThemeColors(
            centerColor = 0xFF97C1A9.toInt(),
            edgeColor = 0xFF4E8B6F.toInt(),
            textColor = 0xFF0E3023.toInt(),
        )

        "coral" -> BallThemeColors(
            centerColor = 0xFFFFC3A0.toInt(),
            edgeColor = 0xFFFF6F61.toInt(),
            textColor = 0xFF4A1F1B.toInt(),
        )

        "bright_yellow" -> BallThemeColors(
            centerColor = 0xFFFFF176.toInt(),
            edgeColor = 0xFFFFD600.toInt(),
            textColor = 0xFF4A3B00.toInt(),
        )

        "dark_gray" -> BallThemeColors(
            centerColor = 0xFFCBD5E1.toInt(),
            edgeColor = 0xFF334155.toInt(),
            textColor = 0xFF0F172A.toInt(),
        )

        "neon_purple" -> BallThemeColors(
            centerColor = 0xFFE0BBFF.toInt(),
            edgeColor = 0xFF7C3AED.toInt(),
            textColor = 0xFF2D0F5F.toInt(),
        )

        "cyan" -> BallThemeColors(
            centerColor = 0xFF7BDFF2.toInt(),
            edgeColor = 0xFF38BDF8.toInt(),
            textColor = 0xFF0B3045.toInt(),
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

class FloatingBallManager(
    private val context: Context,
    private val windowManager: WindowManager,
) {
    companion object {
        const val MAX_BALLS = 8
    }

    private val holders: List<BallHolder> = List(MAX_BALLS) { BallHolder(context, windowManager) }
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentSteps: List<WorkflowStepViewData> = emptyList()
    private var onBallClick: ((WorkflowStepViewData, View) -> Unit)? = null
    private var onBallMoved: ((WorkflowStepViewData) -> Unit)? = null
    private var currentWorkflowId: String? = null

    fun bindWorkflow(
        workflowId: String,
        steps: List<WorkflowStepViewData>,
        onBallClick: ((WorkflowStepViewData, View) -> Unit)? = null,
        onBallMoved: ((WorkflowStepViewData) -> Unit)? = null,
    ) {
        runOnMain {
            currentWorkflowId = workflowId
            this.onBallClick = onBallClick
            this.onBallMoved = onBallMoved
            currentSteps = steps.take(MAX_BALLS)
            detachAllInternal()
            currentSteps.forEachIndexed { index, step ->
                val holder = holders[index]
                holder.bind(step, this.onBallClick, this.onBallMoved)
                holder.attach()
            }
            for (i in currentSteps.size until MAX_BALLS) {
                holders[i].detach()
            }
        }
    }

    fun updateStep(step: WorkflowStepViewData) {
        runOnMain {
            val index = currentSteps.indexOfFirst { it.stepIndex == step.stepIndex }
            if (index < 0) return@runOnMain
            currentSteps = currentSteps.toMutableList().apply { this[index] = step }
            holders[index].rebind(step)
        }
    }

    fun hideAll() {
        runOnMain {
            detachAllInternal()
        }
    }

    fun restore() {
        runOnMain {
            if (currentWorkflowId == null || currentSteps.isEmpty()) return@runOnMain
            bindWorkflow(currentWorkflowId!!, currentSteps, onBallClick, onBallMoved)
        }
    }

    private fun detachAllInternal() {
        holders.forEach { it.detach() }
    }

    private fun runOnMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            mainHandler.post(action)
        }
    }
}

class WorkflowController(
    private val context: Context,
    private val windowManager: WindowManager,
    private val diameterProvider: () -> Int,
) {
    var currentWorkflowId: String? = null
        private set

    var onBallMoved: ((WorkflowStepViewData) -> Unit)? = null
    var onEditRequested: ((WorkflowStepViewData) -> Unit)? = null
    var onExecuteRequested: ((WorkflowStepViewData) -> Unit)? = null
    var onAddStepRequested: ((WorkflowStepViewData) -> Unit)? = null
    var allowAddingSteps: Boolean = true

    private val manager = FloatingBallManager(context, windowManager)
    private val popup = EditBallPopup(context, windowManager)
    private var cachedSteps: List<WorkflowStepViewData> = emptyList()

    fun showWorkflow(workflowId: String, steps: List<WorkflowStepViewData>) {
        currentWorkflowId = workflowId
        val diameter = diameterProvider()
        cachedSteps = steps.take(FloatingBallManager.MAX_BALLS).map { step ->
            if (step.diameterPx > 0) step else step.copy(diameterPx = diameter)
        }
        manager.bindWorkflow(workflowId, cachedSteps, ::onBallSelected, ::onBallMovedInternal)
    }

    fun hideAll() {
        popup.dismiss()
        manager.hideAll()
    }

    fun restoreVisible() {
        manager.restore()
    }

    fun clear() {
        popup.dismiss()
        cachedSteps = emptyList()
        currentWorkflowId = null
        manager.hideAll()
    }

    fun updateStep(step: WorkflowStepViewData) {
        cachedSteps = cachedSteps.map { if (it.stepIndex == step.stepIndex) step else it }
        manager.updateStep(step)
    }

    private fun onBallSelected(step: WorkflowStepViewData, anchor: View) {
        popup.show(
            step,
            anchor,
            cachedSteps,
            allowAddingSteps,
            onEdit = {
                onEditRequested?.invoke(step)
            },
            onExecute = {
                onExecuteRequested?.invoke(step)
            },
            onAddNext = {
                onAddStepRequested?.invoke(step)
            },
            onDismiss = { updated ->
                updateStep(updated)
            }
        )
    }

    private fun onBallMovedInternal(step: WorkflowStepViewData) {
        cachedSteps = cachedSteps.map { if (it.stepIndex == step.stepIndex) step else it }
        onBallMoved?.invoke(step)
    }
}

class EditBallPopup(
    private val context: Context,
    private val windowManager: WindowManager,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val currentPopup = AtomicReference<PopupContent?>(null)

    private data class PopupContent(
        val view: View,
        val params: WindowManager.LayoutParams,
    )

    fun show(
        step: WorkflowStepViewData,
        anchor: View? = null,
        allSteps: List<WorkflowStepViewData> = emptyList(),
        allowAdd: Boolean = true,
        onEdit: (() -> Unit)? = null,
        onExecute: (() -> Unit)? = null,
        onAddNext: (() -> Unit)? = null,
        onDismiss: (WorkflowStepViewData) -> Unit,
    ) {
        runOnMain {
            val existing = currentPopup.get()
            if (existing != null) {
                val newParams = createLayoutParams(anchor)
                bind(existing.view, step, allSteps, allowAdd, onEdit, onExecute, onAddNext, onDismiss)
                windowManager.updateViewLayout(existing.view, newParams)
                currentPopup.set(existing.copy(params = newParams))
                return@runOnMain
            }

            val view = LayoutInflater.from(context)
                .inflate(R.layout.view_floating_config_panel, FrameLayout(context), false)
            val params = createLayoutParams(anchor)
            bind(view, step, allSteps, allowAdd, onEdit, onExecute, onAddNext, onDismiss)
            val content = PopupContent(view, params)
            if (currentPopup.compareAndSet(null, content)) {
                windowManager.addView(view, params)
            } else {
                dismiss()
            }
        }
    }

    fun dismiss() {
        runOnMain {
            currentPopup.getAndSet(null)?.let { content ->
                runCatching { windowManager.removeViewImmediate(content.view) }
            }
        }
    }

    private fun bind(
        view: View,
        step: WorkflowStepViewData,
        allSteps: List<WorkflowStepViewData>,
        allowAdd: Boolean,
        onEdit: (() -> Unit)?,
        onExecute: (() -> Unit)?,
        onAddNext: (() -> Unit)?,
        onDismiss: (WorkflowStepViewData) -> Unit,
    ) {
        val editButton = view.findViewById<TextView>(R.id.btnEditTask)
        val executeButton = view.findViewById<TextView>(R.id.btnExecuteTask)
        val nextButton = view.findViewById<TextView>(R.id.btnNextStep)
        val totalSteps = allSteps.size.coerceAtLeast(1)
        val maxDisplayNumber =
            allSteps.maxOfOrNull { it.displayNumber } ?: step.displayNumber
        val isFirst = step.displayNumber == 1
        val isLast = step.displayNumber >= maxDisplayNumber
        val canAddMore = allowAdd && totalSteps < FloatingBallManager.MAX_BALLS

        editButton?.visibility = View.VISIBLE
        executeButton?.visibility = if (isFirst || totalSteps == 1) View.VISIBLE else View.GONE
        nextButton?.visibility = if (canAddMore && isLast) View.VISIBLE else View.GONE

        editButton?.setOnClickListener {
            onEdit?.invoke()
            onDismiss(step)
            dismiss()
        }
        executeButton?.setOnClickListener {
            onExecute?.invoke()
            onDismiss(step)
            dismiss()
        }
        nextButton?.setOnClickListener {
            onAddNext?.invoke()
            onDismiss(step)
            dismiss()
        }
        view.setOnClickListener { dismiss() }
    }

    private fun createLayoutParams(anchor: View?): WindowManager.LayoutParams {
        val overlayLayoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayLayoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        params.gravity = Gravity.TOP or Gravity.START
        if (anchor != null) {
            val location = IntArray(2)
            anchor.getLocationOnScreen(location)
            params.x = location[0]
            params.y = location[1] + anchor.height
        }
        return params
    }

    private fun runOnMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            mainHandler.post(action)
        }
    }
}
