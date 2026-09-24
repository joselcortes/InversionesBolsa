// Publica una versión nueva en "Mi tienda":
//   1. Compila el APK firmado con la llave definitiva.
//   2. Lo sube a GitHub Releases (Firebase gratis no permite archivos .apk).
//   3. Agrega la versión, su enlace y su huella SHA-256 a releases/apps.json.
//   4. Compila la versión web, arma el sitio (web + /tienda) y lo publica en Firebase.
//
// Uso (desde la carpeta del proyecto):
//   dart run tool/publicar.dart --notas "Novedad 1|Novedad 2"
//   dart run tool/publicar.dart --solo-web      (solo actualiza la web/tienda)
//
// Antes de publicar una versión nueva, sube el número en pubspec.yaml
// (ej. version: 1.2.0+3). El número después del "+" debe aumentar siempre.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const proyecto = 'inversiones-cl-34686';
const appId = 'inversiones';
const repoTienda = 'joselcortes/inversiones-tienda';

Future<void> main(List<String> args) async {
  final soloWeb = args.contains('--solo-web');
  final notasIdx = args.indexOf('--notas');
  final notas = notasIdx >= 0 && notasIdx + 1 < args.length
      ? args[notasIdx + 1].split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
      : <String>[];

  final catalogoFile = File('releases/apps.json');
  final catalogo = jsonDecode(await catalogoFile.readAsString()) as Map<String, dynamic>;
  final app = (catalogo['apps'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((a) => a['id'] == appId);
  final releases = (app['releases'] as List).cast<Map<String, dynamic>>();

  if (!soloWeb) {
    final (version, build) = _leerVersion();
    paso('Versión a publicar: $version (build $build)');
    if (releases.any((r) => (r['build'] as num) >= build)) {
      fallar('Ya existe una versión con build >= $build en la tienda. '
          'Sube el número en pubspec.yaml (ej. version: $version+${build + 1}).');
    }
    if (notas.isEmpty) {
      fallar('Faltan las novedades. Ejemplo: --notas "Nuevo gráfico|Arreglo en alertas"');
    }
    final llave = File('${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME']}'
        '/claves-android/inversiones-release.properties');
    if (!llave.existsSync()) {
      fallar('No se encontró la llave de firma (${llave.path}). '
          'Sin ella la actualización no se podría instalar sobre la app actual.');
    }

    paso('Revisando el código…');
    await correr('flutter', ['analyze']);
    await correr('flutter', ['test']);

    paso('Compilando el APK (arm64)…');
    await correr('flutter', ['build', 'apk', '--release', '--target-platform', 'android-arm64']);

    final nombreApk = '$appId-$version.apk';
    Directory('releases/descargas').createSync(recursive: true);
    final apk = File('releases/descargas/$nombreApk');
    await File('build/app/outputs/flutter-apk/app-release.apk').copy(apk.path);
    final bytes = await apk.readAsBytes();
    final huella = sha256.convert(bytes).toString();

    paso('Subiendo el instalador a GitHub Releases ($repoTienda)…');
    final tag = 'v$version';
    final notasMd = notas.map((n) => '- $n').join('\n');
    await correr('gh', [
      'release', 'create', tag, apk.path,
      '--repo', repoTienda,
      '--title', 'Inversiones $version',
      '--notes', '$notasMd\n\nSHA-256: $huella',
    ]);

    releases.insert(0, {
      'version': version,
      'build': build,
      'date': DateTime.now().toUtc().toIso8601String(),
      'notes': notas,
      'apk': 'https://github.com/$repoTienda/releases/download/$tag/$nombreApk',
      'sha256': huella,
      'sizeBytes': bytes.length,
    });
    releases.sort((a, b) => (b['build'] as num).compareTo(a['build'] as num));
    await catalogoFile.writeAsString(const JsonEncoder.withIndent('  ').convert(catalogo));
    paso('Publicado: $nombreApk (${(bytes.length / 1048576).toStringAsFixed(1)} MB, SHA-256 $huella)');
  }

  paso('Compilando la versión web…');
  await correr('flutter', ['build', 'web', '--release', '--no-web-resources-cdn']);

  paso('Armando la tienda…');
  // Se parte de cero: restos de un armado anterior (ej. un APK) harían que
  // Firebase rechace la publicación.
  final tienda = Directory('build/web/tienda');
  if (tienda.existsSync()) tienda.deleteSync(recursive: true);
  tienda.createSync(recursive: true);
  _copiarCarpeta(Directory('tienda'), tienda);
  // Solo el catálogo: los APK viven en GitHub.
  File('releases/apps.json').copySync('${tienda.path}/apps.json');
  Directory('${tienda.path}/icons').createSync(recursive: true);
  File('web/icons/Icon-192.png').copySync('${tienda.path}/icons/inversiones.png');
  File('web/icons/Icon-192.png').copySync('${tienda.path}/icons/tienda.png');

  paso('Publicando en Firebase ($proyecto)…');
  await correr('firebase', ['deploy', '--only', 'hosting', '--project', proyecto]);

  stdout.writeln('\n✅ Listo.');
  stdout.writeln('   App web:    https://$proyecto.web.app/');
  stdout.writeln('   Mi tienda:  https://$proyecto.web.app/tienda/');
}

(String, int) _leerVersion() {
  final linea = File('pubspec.yaml')
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('version:'), orElse: () => '');
  final m = RegExp(r'version:\s*([0-9.]+)\+(\d+)').firstMatch(linea);
  if (m == null) fallar('No se pudo leer "version:" en pubspec.yaml (formato esperado 1.2.0+3).');
  return (m.group(1)!, int.parse(m.group(2)!));
}

void _copiarCarpeta(Directory origen, Directory destino) {
  for (final e in origen.listSync(recursive: true)) {
    final rel = e.path.substring(origen.path.length + 1);
    final ruta = '${destino.path}/$rel';
    if (e is Directory) {
      Directory(ruta).createSync(recursive: true);
    } else if (e is File) {
      File(ruta).parent.createSync(recursive: true);
      e.copySync(ruta);
    }
  }
}

Future<void> correr(String cmd, List<String> args) async {
  final p = await Process.start(cmd, args, runInShell: true, mode: ProcessStartMode.inheritStdio);
  final code = await p.exitCode;
  if (code != 0) fallar('Falló: $cmd ${args.join(' ')} (código $code)');
}

void paso(String msg) => stdout.writeln('\n▶ $msg');

Never fallar(String msg) {
  stderr.writeln('\n❌ $msg');
  exit(1);
}
