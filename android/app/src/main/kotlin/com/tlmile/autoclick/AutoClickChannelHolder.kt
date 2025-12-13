package com.tlmile.autoclick

import io.flutter.plugin.common.MethodChannel

/**
 * 用来在整个 app 范围内共享 MethodChannel，
 * 方便 Service 之类的地方回调到 Flutter。
 */
object AutoClickChannelHolder {
    var channel: MethodChannel? = null
}
