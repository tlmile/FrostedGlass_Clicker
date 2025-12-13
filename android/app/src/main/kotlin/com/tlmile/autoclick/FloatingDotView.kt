package com.tlmile.autoclick

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.util.AttributeSet
import android.view.View
import kotlin.math.min

class FloatingDotView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var radius: Float = 0f

    private var centerColor = Color.parseColor("#FF9AE6FF")
    private var edgeColor = Color.parseColor("#FF1C73E8")

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        radius = min(w, h) / 2f
        updateShader(w, h)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        canvas.drawCircle(width / 2f, height / 2f, radius, paint)
    }

    fun setColors(center: Int, edge: Int) {
        if (centerColor == center && edgeColor == edge) return
        centerColor = center
        edgeColor = edge
        updateShader()
    }

    private fun updateShader(w: Int = width, h: Int = height) {
        if (w == 0 || h == 0) return
        val shader = RadialGradient(
            w / 2f,
            h / 2f,
            radius,
            intArrayOf(centerColor, edgeColor),
            floatArrayOf(0f, 1f),
            Shader.TileMode.CLAMP
        )
        paint.shader = shader
        invalidate()
    }
}
