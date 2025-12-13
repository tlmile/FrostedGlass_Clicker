import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import android.app.AlertDialog
import android.content.Context

class UpdateChecker(private val context: Context) {

    private val updateUrl = "https://github.com/tlmile/FrostedGlass_Clicker/blob/main/doc/update.json"

    fun checkForUpdate() {
        val client = OkHttpClient()
        val request = Request.Builder()
            .url(updateUrl)
            .build()

        // 在子线程中发起 HTTP 请求
        Thread {
            try {
                val response = client.newCall(request).execute()
                if (response.isSuccessful) {
                    val responseBody = response.body?.string()
                    val jsonObject = JSONObject(responseBody)

                    val latestVersion = jsonObject.getString("version")
                    val currentVersion = getCurrentVersion() // 获取当前应用版本

                    if (latestVersion != currentVersion) {
                        val apkUrl = jsonObject.getString("apk_url")
                        val changelog = jsonObject.getString("changelog")
                        val forceUpdate = jsonObject.getBoolean("force_update")

                        // 如果有新版本，提示用户更新
                        showUpdateDialog(apkUrl, changelog, forceUpdate)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun getCurrentVersion(): String {
        val packageManager = context.packageManager
        val packageInfo = packageManager.getPackageInfo(context.packageName, 0)
        return packageInfo.versionName ?: ""
    }

    private fun showUpdateDialog(apkUrl: String, changelog: String, forceUpdate: Boolean) {
        val builder = AlertDialog.Builder(context)
        builder.setTitle("更新版本")
            .setMessage(changelog)
            .setCancelable(!forceUpdate)
            .setPositiveButton("更新") { _, _ ->
                // 启动 APK 下载与安装
                downloadAndInstall(apkUrl)
            }

        if (!forceUpdate) {
            builder.setNegativeButton("稍后") { dialog, _ -> dialog.dismiss() }
        }

        builder.show()
    }

    private fun downloadAndInstall(apkUrl: String) {
        // 下载 APK 并安装的逻辑
    }
}
