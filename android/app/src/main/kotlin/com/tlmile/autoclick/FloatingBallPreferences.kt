package com.tlmile.autoclick

import android.content.Context

object FloatingBallPreferences {
    const val PREFS_NAME = "auto_click_prefs"
    const val KEY_BALL_DIAMETER_DP = "floating_ball_diameter"

    const val DEFAULT_BALL_DIAMETER_DP = 45
    const val MIN_BALL_DIAMETER_DP = 30
    const val MAX_BALL_DIAMETER_DP = 60

    fun loadDiameterDp(context: Context): Int {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getInt(KEY_BALL_DIAMETER_DP, DEFAULT_BALL_DIAMETER_DP)
            .coerceIn(MIN_BALL_DIAMETER_DP, MAX_BALL_DIAMETER_DP)
    }

    fun saveDiameterDp(context: Context, dp: Int): Int {
        val clamped = dp.coerceIn(MIN_BALL_DIAMETER_DP, MAX_BALL_DIAMETER_DP)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putInt(KEY_BALL_DIAMETER_DP, clamped).apply()
        return clamped
    }
}
