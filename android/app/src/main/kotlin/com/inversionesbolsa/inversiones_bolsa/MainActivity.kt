package com.inversionesbolsa.inversiones_bolsa

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// FlutterFragmentActivity (no FlutterActivity) porque local_auth necesita
// una FragmentActivity para mostrar el diálogo biométrico del sistema.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // FLAG_SECURE: evita capturas de pantalla y que la app aparezca en
        // el selector de apps recientes, ya que muestra saldo y posiciones.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Canal para instalar actualizaciones descargadas desde "Mi tienda".
        // Solo abre el instalador del sistema: Android siempre muestra su
        // propia pantalla y el usuario decide si instalar.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "inversiones/instalador")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "puedeInstalar" -> result.success(canInstall())
                    "abrirPermiso" -> {
                        openInstallPermissionSettings()
                        result.success(null)
                    }
                    "instalarApk" -> {
                        val path = call.argument<String>("ruta")
                        if (path == null) {
                            result.error("sin_ruta", "Falta la ruta del APK", null)
                        } else {
                            try {
                                installApk(File(path))
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("error_instalar", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
            )
        }
    }

    private fun installApk(file: File) {
        // Solo se instalan archivos de la carpeta de actualizaciones propia.
        val updatesDir = File(cacheDir, "actualizaciones").canonicalFile
        require(file.canonicalFile.parentFile == updatesDir) { "Ruta de APK no permitida" }
        val uri = FileProvider.getUriForFile(this, "$packageName.actualizaciones", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
