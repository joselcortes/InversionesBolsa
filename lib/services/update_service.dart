import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/store_catalog.dart';

class UpdateException implements Exception {
  final String message;
  UpdateException(this.message);
  @override
  String toString() => message;
}

/// Versión instalada de esta app.
class InstalledVersion {
  final String version;
  final int build;
  final String packageName;
  const InstalledVersion(this.version, this.build, this.packageName);
}

/// "Mi tienda": revisa si hay una versión nueva publicada en Firebase
/// Hosting, la descarga, verifica su huella SHA-256 y abre el instalador de
/// Android. Android siempre muestra su propia pantalla para confirmar.
class UpdateService {
  static const storeBase = 'https://inversiones-cl-34686.web.app/tienda/';
  static const _channel = MethodChannel('inversiones/instalador');
  static const _skipKey = 'update_skip_build_v1';

  /// La actualización pendiente (para mostrar un punto en el menú).
  static final available = ValueNotifier<StoreRelease?>(null);

  /// En la web la app se actualiza sola al recargar; en Android hay APK.
  static bool get canSelfUpdate => !kIsWeb && Platform.isAndroid;

  static Future<InstalledVersion> installed() async {
    final info = await PackageInfo.fromPlatform();
    return InstalledVersion(info.version, int.tryParse(info.buildNumber) ?? 0, info.packageName);
  }

  static Future<StoreCatalog> fetchCatalog() async {
    try {
      // El parámetro evita que un caché intermedio devuelva una lista vieja.
      final uri = Uri.parse('${storeBase}apps.json?t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw UpdateException('La tienda respondió ${res.statusCode}');
      return StoreCatalog.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
    } on TimeoutException {
      throw UpdateException('La tienda tardó demasiado en responder.');
    } on SocketException {
      throw UpdateException('Sin conexión a internet.');
    } on FormatException {
      throw UpdateException('La lista de la tienda está dañada.');
    }
  }

  /// Devuelve la versión nueva de ESTA app si existe (y no fue omitida
  /// cuando [respectSkip] es true).
  static Future<StoreRelease?> check({bool respectSkip = false}) async {
    if (!canSelfUpdate) return null;
    final inst = await installed();
    final app = (await fetchCatalog()).byPackage(inst.packageName);
    final latest = app?.latest;
    if (latest == null || latest.build <= inst.build || latest.apk == null) {
      available.value = null;
      return null;
    }
    available.value = latest;
    if (respectSkip) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt(_skipKey) == latest.build) return null;
    }
    return latest;
  }

  /// "Ahora no": no volver a mostrar el aviso automático para esta versión.
  static Future<void> skip(StoreRelease r) async {
    await (await SharedPreferences.getInstance()).setInt(_skipKey, r.build);
  }

  /// Descarga el APK, verifica que su huella coincida con la publicada y
  /// devuelve la ruta. [onProgress] recibe 0..1.
  static Future<String> download(StoreRelease r, {void Function(double)? onProgress}) async {
    final apk = r.apk;
    final expected = r.sha256?.toLowerCase();
    if (apk == null || expected == null) {
      throw UpdateException('Esta versión no tiene archivo para descargar.');
    }
    final dir = Directory('${(await getTemporaryDirectory()).path}/actualizaciones');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File('${dir.path}/inversiones-${r.build}.apk');

    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', apkUri(apk)));
      if (res.statusCode != 200) throw UpdateException('No se pudo descargar (${res.statusCode}).');
      final total = res.contentLength ?? r.sizeBytes ?? 0;
      final sink = file.openWrite();
      final hashOut = _DigestSink();
      final hasher = sha256.startChunkedConversion(hashOut);
      var received = 0;
      await for (final chunk in res.stream.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();
      hasher.close();
      if (hashOut.value.toString() != expected) {
        await file.delete();
        throw UpdateException(
            'El archivo descargado no coincide con el publicado. Por seguridad no se instalará.');
      }
      return file.path;
    } on TimeoutException {
      throw UpdateException('La descarga se detuvo. Revisa tu conexión e intenta de nuevo.');
    } on SocketException {
      throw UpdateException('Sin conexión a internet.');
    } finally {
      client.close();
    }
  }

  /// Dirección del APK. Los instaladores viven en GitHub Releases (Firebase
  /// gratis no permite archivos .apk); las rutas relativas apuntan a /tienda.
  /// Solo se aceptan https de GitHub o de la propia tienda: igual se verifica
  /// la huella SHA-256 publicada en el catálogo antes de instalar.
  static Uri apkUri(String apk) {
    if (!apk.startsWith('https://')) return Uri.parse('$storeBase$apk');
    final uri = Uri.parse(apk);
    const allowed = {'github.com', 'inversiones-cl-34686.web.app'};
    if (!allowed.contains(uri.host)) {
      throw UpdateException('Origen de descarga no permitido: ${uri.host}');
    }
    return uri;
  }

  /// true si Android ya permite a esta app instalar actualizaciones.
  static Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('puedeInstalar') ?? false;

  /// Abre el ajuste de Android para permitir instalar desde esta app.
  static Future<void> openInstallPermission() => _channel.invokeMethod('abrirPermiso');

  static Future<void> install(String path) =>
      _channel.invokeMethod('instalarApk', {'ruta': path});
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
