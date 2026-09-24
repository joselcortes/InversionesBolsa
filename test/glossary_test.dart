import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inversiones_bolsa/content/glossary.dart';

void main() {
  test('los ids del glosario son únicos', () {
    final ids = [
      for (final s in Glossary.sections)
        for (final e in s.entries) e.id,
    ];
    expect(ids.toSet().length, ids.length);
  });

  test('cada ⓘ / "¿Qué es esto?" de la app apunta a una explicación que existe', () {
    // InfoTip('x'), HelpLink('x'), LabelWithTip('...', 'x'), term: 'x',
    // showTermSheet(context, 'x') y mapas tips: {'Etiqueta': 'x'}.
    final patterns = [
      RegExp(r"InfoTip\('([a-z_0-9]+)'"),
      RegExp(r"HelpLink\('([a-z_0-9]+)'"),
      RegExp(r"LabelWithTip\([^,]+,\s*'([a-z_0-9]+)'"),
      RegExp(r"term: '([a-z_0-9]+)'"),
      RegExp(r"showTermSheet\(context, '([a-z_0-9]+)'"),
      RegExp(r"'[^']+':\s*'([a-z_0-9]+)',"),
    ];
    final missing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      final inTipsMap = src.contains('tips:');
      for (final p in patterns) {
        for (final m in p.allMatches(src)) {
          final id = m.group(1)!;
          // El último patrón es genérico: solo vale dentro de archivos con mapas de tips.
          if (p == patterns.last && !inTipsMap) continue;
          if (p == patterns.last && !id.contains('_') && Glossary.byId(id) == null) {
            // Cadenas que no son ids (p. ej. JSON de la API) se ignoran.
            continue;
          }
          if (Glossary.byId(id) == null) missing.add('$id (${f.path})');
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('el buscador encuentra por título y contenido', () {
    expect(Glossary.search('dividendo'), isNotEmpty);
    expect(Glossary.search('xyzxyz'), isEmpty);
  });
}
