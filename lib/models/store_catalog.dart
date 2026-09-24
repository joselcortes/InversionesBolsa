/// Catálogo de "Mi tienda" (`/tienda/apps.json` en Firebase Hosting).
class StoreRelease {
  final String version;
  final int build;
  final DateTime date;
  final List<String> notes;

  /// Ruta relativa del APK dentro de /tienda/, o null si ya no se ofrece.
  final String? apk;
  final String? sha256;
  final int? sizeBytes;

  const StoreRelease({
    required this.version,
    required this.build,
    required this.date,
    required this.notes,
    this.apk,
    this.sha256,
    this.sizeBytes,
  });

  factory StoreRelease.fromJson(Map<String, dynamic> j) => StoreRelease(
        version: j['version'] as String,
        build: (j['build'] as num).toInt(),
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime(2000),
        notes: ((j['notes'] as List?) ?? const []).map((e) => e.toString()).toList(),
        apk: j['apk'] as String?,
        sha256: j['sha256'] as String?,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
      );
}

class StoreApp {
  final String id;
  final String name;
  final String packageName;
  final String description;
  final String icon;
  final String? webUrl;

  /// De la más nueva a la más antigua. La primera es la actual.
  final List<StoreRelease> releases;

  const StoreApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.description,
    required this.icon,
    required this.releases,
    this.webUrl,
  });

  StoreRelease? get latest => releases.isEmpty ? null : releases.first;

  factory StoreApp.fromJson(Map<String, dynamic> j) {
    final releases = ((j['releases'] as List?) ?? const [])
        .map((e) => StoreRelease.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.build.compareTo(a.build));
    return StoreApp(
      id: j['id'] as String,
      name: j['name'] as String,
      packageName: j['package'] as String? ?? '',
      description: j['description'] as String? ?? '',
      icon: j['icon'] as String? ?? '',
      webUrl: j['webUrl'] as String?,
      releases: releases,
    );
  }
}

class StoreCatalog {
  final List<StoreApp> apps;
  const StoreCatalog(this.apps);

  factory StoreCatalog.fromJson(Map<String, dynamic> j) => StoreCatalog(
        ((j['apps'] as List?) ?? const [])
            .map((e) => StoreApp.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  StoreApp? byPackage(String packageName) {
    for (final a in apps) {
      if (a.packageName == packageName) return a;
    }
    return null;
  }
}
