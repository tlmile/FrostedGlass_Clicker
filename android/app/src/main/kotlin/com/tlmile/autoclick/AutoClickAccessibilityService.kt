package com.tlmile.autoclick

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.util.Log
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * AccessibilityService used to dispatch real tap gestures.
 * The service keeps a static reference so other components can ask it to send gestures.
 */
class AutoClickAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AutoClickAccessibility"
        var instance: AutoClickAccessibilityService? = null
            private set

        fun isServiceEnabled(): Boolean = instance != null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: android.view.accessibility.AccessibilityEvent?) {
        // No-op: we only use this service for gesture dispatching.
    }

    override fun onInterrupt() {
        // No-op
    }

    /**
     * Dispatches a single tap gesture centered on the provided coordinates using dispatchGesture.
     * The call suspends until the system reports completion or cancellation.
     */
    suspend fun dispatchTap(x: Int, y: Int): Boolean = suspendCancellableCoroutine { cont ->
        val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
        // Keep the stroke short; only a tap is needed.
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 50))
            .build()

        val callback = object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                super.onCompleted(gestureDescription)
                if (cont.isActive) cont.resume(true)
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                super.onCancelled(gestureDescription)
                if (cont.isActive) cont.resume(false)
            }
        }

        val dispatched = dispatchGesture(gesture, callback, null)
        if (!dispatched && cont.isActive) {
            Log.w(TAG, "Failed to dispatch gesture")
            cont.resume(false)
        }

        cont.invokeOnCancellation {
            // No direct cancelGesture API is available; allow the system to handle cancellation.
        }
    }

    /** Placeholder kept for API compatibility; currently there is no explicit cancel call. */
    fun cancelCurrentGestureSafely() {}
}
