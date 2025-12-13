package com.tlmile.autoclick

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

/**
 * 统一的点击执行器：
 *
 * 需求保证：
 * 1. 工作流执行：从 1 号球到最后一个球，所有点击按各自配置完成才算一次“执行完成”
 * 2. 全局任意时刻只允许有一个任务在执行：
 *    - 新任务开始时会自动 cancel 掉旧任务
 *    - 旧任务被 cancel 后不会把新任务误判为结束
 * 3. 执行期间通过回调隐藏悬浮球，结束/停止后恢复悬浮球；
 *    同时通过 MethodChannel 通知 Flutter 更新主页“停止执行”按钮状态。
 */
object AutoClickExecutor {

    private const val TAG = "AutoClickExecutor"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    // 当前执行的协程任务
    private var executionJob: Job? = null

    // 当前是否有任务在执行
    @Volatile
    private var isExecuting: Boolean = false

    // 当前正在执行的任务 id（来自 Flutter 的 taskId）
    @Volatile
    private var currentTaskId: String? = null

    // 悬浮球显示/隐藏的回调（由 FloatingDotService 注册）
    private var onStartCallback: (() -> Unit)? = null
    private var onFinishCallback: (() -> Unit)? = null

    // ---------------- 对外：注册悬浮球显示/隐藏回调 ----------------

    fun registerVisibilityCallbacks(onStart: (() -> Unit)?, onFinish: (() -> Unit)?) {
        onStartCallback = onStart
        onFinishCallback = onFinish
    }

    // ---------------- 对外：停止执行 ----------------

    /**
     * 停止当前正在执行的任务。
     * - taskId 为 null：无条件停止当前任务
     * - taskId 不为 null：仅当与 currentTaskId 一致时才算这次 stop 生效
     */
    fun stopAll(taskId: String? = null) {
        val service = AutoClickAccessibilityService.instance

        // 取消当前执行协程（单任务或工作流都走这一套）
        executionJob?.cancel()
        service?.cancelCurrentGestureSafely()

        // 主动 stop：把当前任务标记为结束
        // 注意：这里传入的 taskId 是目前的 currentTaskId 或调用者指定的
        if (isExecuting) {
            val reason = "stopped"
            val finalTaskId = taskId ?: currentTaskId
            finishExecution(reason, finalTaskId)
        }
    }

    // ---------------- 对外：执行单任务 ----------------

    /**
     * 执行单个点击任务。
     * 任何情况下调用都会：
     * 1. 先取消旧任务（如果有）
     * 2. 再启动这个新的单任务
     */
    fun executeSingle(context: Context, step: ClickStepConfig, taskId: String?) {
        beginExecution(taskId)

        // 记录“本轮任务”的 id，防止旧任务在被 cancel 后结束时误杀新任务
        val thisTaskId = currentTaskId

        executionJob = scope.launch {
            try {
                runStep(context, step)
                finishExecution("completed", thisTaskId)
            } catch (_: CancellationException) {
                finishExecution("stopped", thisTaskId)
            } catch (e: Exception) {
                Log.e(TAG, "executeSingle error", e)
                finishExecution("error", thisTaskId)
            }
        }
    }

    // ---------------- 对外：执行工作流 ----------------

    /**
     * 执行工作流：
     * - steps：所有悬浮球对应的点击配置
     * - loopCount：
     *      null  → 执行一遍
     *      0     → 无限循环，直到 stopExecution
     *      >0    → 执行指定次数
     */
    fun executeWorkflow(
        context: Context,
        steps: List<ClickStepConfig>,
        loopCount: Int?,
        taskId: String?,
    ) {
        if (steps.isEmpty()) return

        beginExecution(taskId)
        val thisTaskId = currentTaskId

        val sanitizedLoopCount = when {
            loopCount == null -> null
            loopCount < 0 -> 1
            else -> loopCount
        }

        executionJob = scope.launch {
            try {
                // 先按 stepOrder 排序（没有 stepOrder 的按原始顺序）
                val sortedSteps = steps.withIndex()
                    .sortedWith(
                        compareBy(
                            { it.value.stepOrder ?: Int.MAX_VALUE },
                            { it.index }
                        )
                    )
                    .map { it.value }

                val loopDescription = when (loopCount) {
                    null -> "null (single round)"
                    0 -> "0 (infinite)"
                    else -> loopCount.toString()
                }

                Log.i(
                    TAG,
                    """
                    >>> executeWorkflow START
                    TaskId       : $taskId
                    LoopCount    : $loopDescription (null=single, 0=infinite, >0=times)
                    StepCount    : ${sortedSteps.size}
                    StepOrder    : ${sortedSteps.map { it.stepOrder ?: "-" }}
                    Timestamp    : ${System.currentTimeMillis()}
                    """.trimIndent(),
                )

                val totalRounds = when {
                    sanitizedLoopCount == null -> 1
                    sanitizedLoopCount == 0 -> null
                    else -> sanitizedLoopCount
                }

                var roundIndex = 1
                while (totalRounds == null || roundIndex <= totalRounds) {
                    currentCoroutineContext().ensureActive()
                    val isLast = totalRounds != null && roundIndex == totalRounds
                    val totalLabel = totalRounds?.toString() ?: "?"

                    Log.i(
                        TAG,
                        """
                        === LOOP ROUND START round=$roundIndex/$totalLabel
                        RoundIndex : $roundIndex
                        TotalRound : $totalLabel
                        Timestamp  : ${System.currentTimeMillis()}
                        """.trimIndent(),
                    )

                    runStepsOnce(context, sortedSteps, roundIndex, totalRounds)

                    Log.i(
                        TAG,
                        """
                        === LOOP ROUND END round=$roundIndex/$totalLabel
                        RoundIndex : $roundIndex
                        TotalRound : $totalLabel
                        Timestamp  : ${System.currentTimeMillis()}
                        """.trimIndent(),
                    )

                    val hasNextRound = totalRounds == null || !isLast
                    if (hasNextRound) {
                        currentCoroutineContext().ensureActive()
                        val interval = resolveInterval(sortedSteps.last())
                        if (interval > 0) {
                            Log.d(
                                TAG,
                                "INTER-ROUND DELAY fromStep=${sortedSteps.last().stepOrder ?: sortedSteps.size} delayMs=$interval",
                            )
                            delay(interval)
                        }
                    } else {
                        break
                    }

                    roundIndex++
                }

                finishExecution("completed", thisTaskId)
            } catch (_: CancellationException) {
                finishExecution("stopped", thisTaskId)
            } catch (e: Exception) {
                Log.e(TAG, "executeWorkflow error", e)
                finishExecution("error", thisTaskId)
            }
        }
    }

    // ---------------- 内部：开始 / 结束 执行 ----------------

    /**
     * 开始执行一个新任务：
     * 1. cancel 掉旧任务（如果有）
     * 2. 设置 currentTaskId / isExecuting
     * 3. 调用 onStart 回调 + 通知 Flutter onExecutionStarted
     *
     * 注意：旧任务在被 cancel 后 catch 的 CancellationException 中也会调 finishExecution，
     * 但我们在 finishExecution 里做了“taskId 匹配”判断，能避免污染新任务。
     */
    private fun beginExecution(taskId: String?) {
        // 先取消旧任务（不在这里发 onExecutionFinished，由旧任务自己在协程里收尾）
        executionJob?.cancel()

        currentTaskId = taskId
        isExecuting = true

        runOnMainThread {
            onStartCallback?.invoke()
            AutoClickChannelHolder.channel?.invokeMethod(
                "onExecutionStarted",
                mapOf("taskId" to taskId)
            )
        }
    }

    /**
     * 结束某个任务：
     * - 只有当 taskId == currentTaskId 时才真正结束（防止旧任务误结束新任务）
     * - 会调用 onFinish 回调 + 通知 Flutter onExecutionFinished
     */
    private fun finishExecution(reason: String, taskId: String?) {
        if (!isExecuting) return

        // 如果传入的 taskId 和当前的任务不一致，说明这是“旧任务”的结束信号，直接忽略
        if (taskId != null && taskId != currentTaskId) {
            return
        }

        isExecuting = false
        val finalTaskId = taskId ?: currentTaskId

        Log.i(
            TAG,
            "<<< executeWorkflow END reason=$reason taskId=$finalTaskId ts=${System.currentTimeMillis()}",
        )

        runOnMainThread {
            onFinishCallback?.invoke()
            AutoClickChannelHolder.channel?.invokeMethod(
                "onExecutionFinished",
                mapOf(
                    "taskId" to finalTaskId,
                    "reason" to reason,
                )
            )
        }
    }

    // ---------------- 内部：执行步骤 ----------------

    /**
     * 执行整个工作流的一遍（从第 1 步到最后一步）。
     * 每一步会跑完它自己的 clickCount 和间隔后才去下一步。
     */
    private suspend fun runStepsOnce(
        context: Context,
        steps: List<ClickStepConfig>,
        roundIndex: Int,
        totalRounds: Int?,
    ) {
        steps.forEachIndexed { index, step ->
            currentCoroutineContext().ensureActive()

            val (minInterval, maxInterval) = resolveIntervalBounds(step)
            val intervalDescription = if (step.isRandom) {
                "random[$minInterval-$maxInterval]"
            } else {
                minInterval.toString()
            }
            val totalLabel = totalRounds?.toString() ?: "?"

            Log.i(
                TAG,
                """
                >>> STEP START
                Round        : $roundIndex/$totalLabel
                StepIndex    : ${index + 1}
                StepOrder    : ${step.stepOrder ?: "-"}
                Position     : (${step.x}, ${step.y})
                ClickCount   : ${step.clickCount}
                Mode         : ${if (step.isRandom) "random" else "fixed"}
                Interval     : $intervalDescription
                Timestamp    : ${System.currentTimeMillis()}
                """.trimIndent(),
            )

            runStep(context, step)

            Log.i(
                TAG,
                """
                <<< STEP END
                Round        : $roundIndex/$totalLabel
                StepIndex    : ${index + 1}
                StepOrder    : ${step.stepOrder ?: "-"}
                Position     : (${step.x}, ${step.y})
                ClickCount   : ${step.clickCount}
                Mode         : ${if (step.isRandom) "random" else "fixed"}
                Interval     : $intervalDescription
                Timestamp    : ${System.currentTimeMillis()}
                """.trimIndent(),
            )

            val isLastStep = index == steps.lastIndex
            if (!isLastStep) {
                val interval = resolveInterval(step)
                if (interval > 0) {
                    currentCoroutineContext().ensureActive()
                    Log.d(
                        TAG,
                        "INTER-STEP DELAY fromStep=${step.stepOrder ?: index + 1} delayMs=$interval round=$roundIndex",
                    )
                    delay(interval)
                }
            }
        }
    }

    /**
     * 执行单个 step 的所有点击：
     * - 根据 step.clickCount 循环
     * - 每次点击使用固定 or 随机间隔
     */
    private suspend fun runStep(context: Context, step: ClickStepConfig) {
        val (minInterval, maxInterval) = resolveIntervalBounds(step)
        val fixedInterval = if (step.isRandom) null else minInterval

        Log.i(
            TAG,
            """
            ---- AutoClick Step Start ----
            Position      : (${step.x}, ${step.y})
            StepOrder     : ${step.stepOrder ?: "-"}
            ClickCount    : ${step.clickCount}
            IsRandom      : ${step.isRandom}
            Interval(ms)  : ${
                if (step.isRandom) "RANDOM [$minInterval-$maxInterval] (per click)"
                else fixedInterval
            }
            Timestamp     : ${System.currentTimeMillis()}
            --------------------------------
            """.trimIndent()
        )

        repeat(step.clickCount) { index ->
            currentCoroutineContext().ensureActive()

            val intervalForThisClick: Long = if (step.isRandom) {
                resolveInterval(step)
            } else {
                fixedInterval ?: 1L
            }

            val timestamp = System.currentTimeMillis()

            Log.d(
                TAG,
                """
                >>> Click ${index + 1}/${step.clickCount}
                StepOrder     : ${step.stepOrder ?: "-"}
                Position      : (${step.x}, ${step.y})
                IsRandom      : ${step.isRandom}
                Interval(ms)  : $intervalForThisClick
                Timestamp     : $timestamp
                """.trimIndent(),
            )

            val success = AutoClickEngine.performAutoClick(
                context,
                AutoClickConfig(step.x, step.y, 1, intervalForThisClick.toInt()),
            )

            if (!success) {
                Log.w(
                    TAG,
                    "!!! Click FAILED at (${step.x}, ${step.y}) | Time: $timestamp",
                )
            }

            if (index < step.clickCount - 1 && intervalForThisClick > 0) {
                delay(intervalForThisClick)
            }
        }

        Log.i(TAG, "---- AutoClick Step End ----")
    }

    /**
     * 计算间隔时间：
     * - 随机模式：从 [randomMinMs, randomMaxMs] 区间随机取
     * - 固定模式：用 fixedIntervalMs
     */
    private fun resolveInterval(step: ClickStepConfig): Long {
        val (minInterval, maxInterval) = resolveIntervalBounds(step)
        return if (step.isRandom) {
            Random.nextLong(minInterval, maxInterval + 1)
        } else {
            minInterval
        }
    }

    private fun resolveIntervalBounds(step: ClickStepConfig): Pair<Long, Long> {
        return if (step.isRandom) {
            val rawMin = step.randomMinMs ?: 1L
            val rawMax = step.randomMaxMs ?: rawMin
            val safeMin = max(1L, rawMin)
            val safeMax = max(1L, rawMax)
            val orderedMin = min(safeMin, safeMax)
            val orderedMax = max(safeMin, safeMax)
            orderedMin to orderedMax
        } else {
            val fixed = max(1L, step.fixedIntervalMs ?: 1L)
            fixed to fixed
        }
    }

    // ---------------- 工具：主线程调度 ----------------

    private fun runOnMainThread(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            Handler(Looper.getMainLooper()).post(action)
        }
    }
}
