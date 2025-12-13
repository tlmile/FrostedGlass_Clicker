package com.tlmile.autoclick

/**
 * 单个点击步骤的配置：
 * - (x, y)：点击坐标
 * - clickCount：点击次数
 * - isRandom：是否使用随机间隔
 * - fixedIntervalMs：固定间隔（毫秒）
 * - randomMinMs / randomMaxMs：随机间隔范围（毫秒）
 * - stepOrder：工作流步骤顺序（用于排序），单任务可以为 null
 */
data class ClickStepConfig(
    val x: Int,
    val y: Int,
    val clickCount: Int,
    val isRandom: Boolean,
    val fixedIntervalMs: Long?,
    val randomMinMs: Long?,
    val randomMaxMs: Long?,
    val stepOrder: Int? = null,
)
