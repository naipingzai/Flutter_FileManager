package com.naipingzai.flutter_file_manager

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.naipingzai.flutter_file_manager/permissions"
    private val FILE_CHANNEL = "com.naipingzai.flutter_file_manager/file_picker"

    private val requestCode = AtomicInteger(1000)
    private var pendingPickResult: Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isManageExternalStorageGranted" -> {
                    result.success(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            Environment.isExternalStorageManager()
                        } else {
                            true
                        }
                    )
                }
                "openAllFilesAccessSettings" -> {
                    openAllFilesAccessSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 原生 SAF 选文件，返回拷贝到 app 内部目录的真实路径（不读整个文件到内存，避免 OOM）
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FILE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFiles" -> pickFiles(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun pickFiles(result: Result) {
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        startActivityForResult(intent, requestCode.incrementAndGet())
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val cb = pendingPickResult ?: return
        pendingPickResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            cb.success(emptyList<String>())
            return
        }
        val uris = mutableListOf<Uri>()
        data.data?.let { uris.add(it) }
        data.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) {
                clip.getItemAt(i).uri?.let { uris.add(it) }
            }
        }
        val paths = uris.mapNotNull { copyToAppDir(it) }
        cb.success(paths)
    }

    // 把 content URI 指向的文件拷贝到 app 缓存目录，返回真实路径（不读入内存）
    private fun copyToAppDir(uri: Uri): String? {
        return try {
            var name = "import_${System.currentTimeMillis()}"
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0 && !c.isNull(idx)) name = c.getString(idx)
                }
            }
            val out = File(cacheDir, "imported")
            if (!out.exists()) out.mkdirs()
            val target = File(out, name)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { fos ->
                    input.copyTo(fos)
                }
            }
            target.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun openAllFilesAccessSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val intent = Intent(
                android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:${packageName}")
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } else {
            // Fallback to generic app settings on older Android versions
            val intent = Intent(
                android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${packageName}")
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }
}
