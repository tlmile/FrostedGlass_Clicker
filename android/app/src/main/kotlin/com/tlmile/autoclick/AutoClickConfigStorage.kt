package com.tlmile.autoclick

import android.content.Context
import androidx.core.content.edit

class AutoClickConfigStorage(context: Context) {
    private val prefs = context.getSharedPreferences("auto_click_prefs", Context.MODE_PRIVATE)

    fun save(config: AutoClickConfig) {
        prefs.edit {
            putInt(KEY_X, config.x)
            putInt(KEY_Y, config.y)
            putInt(KEY_COUNT, config.count)
            putInt(KEY_INTERVAL, config.intervalMs)
        }
    }

    fun load(): AutoClickConfig? {
        if (!prefs.contains(KEY_COUNT)) return null
        return AutoClickConfig(
            prefs.getInt(KEY_X, 0),
            prefs.getInt(KEY_Y, 0),
            prefs.getInt(KEY_COUNT, 1),
            prefs.getInt(KEY_INTERVAL, 100)
        )
    }

    companion object {
        private const val KEY_X = "key_x"
        private const val KEY_Y = "key_y"
        private const val KEY_COUNT = "key_count"
        private const val KEY_INTERVAL = "key_interval"
    }
}
