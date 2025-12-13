package com.tlmile.autoclick

import android.content.Context
import android.widget.Toast
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object AutoClickEngine {
    /**
     * Perform a real tap using the accessibility service. This suspends until the gesture finishes.
     */
    suspend fun performAutoClick(context: Context, config: AutoClickConfig): Boolean {
        val service = AutoClickAccessibilityService.instance
        if (service == null) {
            withContext(Dispatchers.Main) {
                Toast.makeText(context, "请先开启无障碍服务", Toast.LENGTH_SHORT).show()
            }
            return false
        }

        var allSucceeded = true
        repeat(config.count) {
            val success = service.dispatchTap(config.x, config.y)
            allSucceeded = allSucceeded && success
            if (!success) return@repeat
            // Respect interval between taps handled by caller; we only perform taps here.
        }
        return allSucceeded
    }
}
