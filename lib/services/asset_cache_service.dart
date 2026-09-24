import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset_info.dart';
import 'alpaca_service.dart';

/// Lista de todas las acciones negociables, descargada una vez por semana y
/// guardada en un archivo local para buscar por nombre o símbolo sin red.
class AssetCacheService {
  static const _fileName = 'assets_cache_v1.json';
  static const _maxAge = Duration(days: 7);

  Map<String, AssetInfo> _bySymbol = {};
  bool get isLoaded => _bySymbol.isNotEmpty;

  AssetInfo? get(String symbol) => _bySymbol[symbol];

  // En el celular se guarda en un archivo; en la versión web (sin sistema
  // de archivos) en el almacenamiento del navegador.
  Future<String?> _read() async {
    if (kIsWeb) return (await SharedPreferences.getInstance()).getString(_fileName);
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_fileName');
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> _write(String data) async {
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).setString(_fileName, data);
      return;
    }
    final dir = await getApplicationSupportDirectory();
    await File('${dir.path}/$_fileName').writeAsString(data);
  }

  Future<void> ensureLoaded(AlpacaService service) async {
    if (isLoaded) return;
    DateTime? savedAt;
    try {
      final raw = await _read();
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        savedAt = DateTime.tryParse(json['at'] as String? ?? '');
        final items = (json['items'] as List)
            .map((e) => AssetInfo.fromCompact(e as List<dynamic>));
        _bySymbol = {for (final a in items) a.symbol: a};
      }
    } catch (_) {
      _bySymbol = {};
    }
    final stale = savedAt == null || DateTime.now().difference(savedAt) > _maxAge;
    if (!stale && isLoaded) return;
    try {
      final assets = await service.getAllAssets();
      _bySymbol = {
        for (final a in assets.where((a) => a.tradable)) a.symbol: a,
      };
      await _write(jsonEncode({
        'at': DateTime.now().toIso8601String(),
        'items': _bySymbol.values.map((a) => a.toCompact()).toList(),
      }));
    } catch (_) {
      // Sin red o sin espacio: seguimos con lo que haya en memoria.
    }
  }

  /// Coincidencias exactas de símbolo primero, luego símbolos que empiezan
  /// con el texto y al final nombres que lo contienen.
  List<AssetInfo> search(String query, {int limit = 30}) {
    final q = query.trim().toUpperCase();
    if (q.isEmpty) return [];
    final exact = <AssetInfo>[];
    final prefix = <AssetInfo>[];
    final byName = <AssetInfo>[];
    for (final a in _bySymbol.values) {
      if (a.symbol == q) {
        exact.add(a);
      } else if (a.symbol.startsWith(q)) {
        prefix.add(a);
      } else if (q.length >= 3 && a.name.toUpperCase().contains(q)) {
        byName.add(a);
      }
    }
    prefix.sort((a, b) => a.symbol.length.compareTo(b.symbol.length));
    return [...exact, ...prefix, ...byName].take(limit).toList();
  }
}
