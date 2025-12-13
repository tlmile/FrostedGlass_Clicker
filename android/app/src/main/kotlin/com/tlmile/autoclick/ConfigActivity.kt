package com.tlmile.autoclick

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

class ConfigActivity : AppCompatActivity() {
    private lateinit var tvPosition: TextView
    private lateinit var etCount: EditText
    private lateinit var etInterval: EditText
    private lateinit var btnSave: Button
    private lateinit var btnExecute: Button

    private val storage by lazy { AutoClickConfigStorage(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.config_activity)

        tvPosition = findViewById(R.id.tv_position)
        etCount = findViewById(R.id.et_count)
        etInterval = findViewById(R.id.et_interval)
        btnSave = findViewById(R.id.btn_save)
        btnExecute = findViewById(R.id.btn_execute)

        val x = intent.getIntExtra(EXTRA_X, 0)
        val y = intent.getIntExtra(EXTRA_Y, 0)
        tvPosition.text = "当前位置: ($x, $y)"

        val lastConfig = storage.load() ?: AutoClickConfig(x, y, 1, 100)
        etCount.setText(lastConfig.count.toString())
        etInterval.setText(lastConfig.intervalMs.toString())

        btnSave.setOnClickListener {
            val config = buildConfig(x, y)
            storage.save(config)
            Toast.makeText(this, "已保存", Toast.LENGTH_SHORT).show()
        }

        btnExecute.setOnClickListener {
            val config = buildConfig(x, y)
            storage.save(config)
            lifecycleScope.launch {
                AutoClickEngine.performAutoClick(this@ConfigActivity, config)
                Toast.makeText(this@ConfigActivity, "开始模拟点击", Toast.LENGTH_SHORT).show()
                finish()
            }
        }
    }

    private fun buildConfig(x: Int, y: Int): AutoClickConfig {
        val count = etCount.text.toString().toIntOrNull() ?: 1
        val interval = etInterval.text.toString().toIntOrNull() ?: 100
        return AutoClickConfig(x, y, count, interval)
    }

    companion object {
        const val EXTRA_X = "extra_x"
        const val EXTRA_Y = "extra_y"
    }
}
