package com.homesolindia.crm

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.content.FileProvider
import java.io.File
import java.util.ArrayList

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.homesolindia.crm/whatsapp_share"

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareMultipleFiles") {
                val filePaths = call.argument<List<String>>("filePaths")
                val phoneNumber = call.argument<String>("phoneNumber")
                val text = call.argument<String>("text")

                if (filePaths != null && phoneNumber != null) {
                    val targetPackage = getInstalledWhatsAppPackage()
                    if (targetPackage != null) {
                        shareMultipleFiles(filePaths, phoneNumber, text, targetPackage)
                        result.success(true)
                    } else {
                        result.error("WHATSAPP_NOT_INSTALLED", "WhatsApp or Business not found", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing paths or number", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getInstalledWhatsAppPackage(): String? {
        val pm = packageManager
        val packages = listOf("com.whatsapp.w4b", "com.whatsapp")
        for (pkg in packages) {
            try {
                pm.getPackageInfo(pkg, PackageManager.GET_ACTIVITIES)
                return pkg
            } catch (e: PackageManager.NameNotFoundException) {
                continue
            }
        }
        return null
    }

    private fun shareMultipleFiles(paths: List<String>, phone: String, text: String?, targetPackage: String) {
        val uris = ArrayList<Uri>()
        val authority = "${applicationContext.packageName}.provider"

        for (path in paths) {
            val file = File(path)
            if (file.exists()) {
                uris.add(FileProvider.getUriForFile(this, authority, file))
            }
        }

        if (uris.isEmpty()) return

        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            // Using */* is correct for a mix of PDFs and images
            type = "*/*"

            // Explicitly ensure the ArrayList is passed correctly
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)

            // Ensure text is NEVER empty. If null or empty, use a placeholder.
            val caption = if (text.isNullOrEmpty()) "Project Documents" else text
            putExtra(Intent.EXTRA_TEXT, caption)

            setPackage(targetPackage)
            putExtra("jid", "$phone@s.whatsapp.net")

            // Critical permissions for sharing content:// URIs
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
