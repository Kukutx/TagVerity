package dev.kukutx.tagverity
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.kukutx.tagverity/share",
        ).setMethodCallHandler { call, result ->
            if (call.method != "shareTextFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val filename = call.argument<String>("filename")
            val content = call.argument<String>("content")
            val mimeType = call.argument<String>("mimeType")
            val subject = call.argument<String>("subject")
            if (filename == null || content == null || mimeType == null || subject == null) {
                result.error("invalid_arguments", "Missing share file arguments.", null)
                return@setMethodCallHandler
            }
            try {
                val exportDirectory = File(cacheDir, "exports").apply { mkdirs() }
                exportDirectory.listFiles()
                    ?.filter { it.isFile && it.name.startsWith("tagverity-") }
                    ?.forEach { it.delete() }
                val safeFilename = filename.replace(Regex("[^A-Za-z0-9._-]"), "_")
                val file = File(exportDirectory, safeFilename)
                file.writeText(content, Charsets.UTF_8)
                val uri = FileProvider.getUriForFile(
                    this,
                    "${packageName}.fileprovider",
                    file,
                )
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = mimeType
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(Intent.createChooser(shareIntent, subject))
                result.success(null)
            } catch (error: Exception) {
                result.error("share_failed", error.message ?: "Unable to share file.", null)
            }
        }
    }
}
