/// Palabras clave típicas de coberturas de analistas (price targets, ratings,
/// upgrades/downgrades) en vez de simples notas de prensa. No hay forma de
/// garantizar que una especulación "acierte más" — esto solo prioriza
/// contenido que viene de casas de análisis en vez de comunicados genéricos.
final _analystKeywords = RegExp(
  r'(price target|upgrade|downgrade|rating|outperform|underperform|overweight|'
  r'underweight|initiates coverage|reiterates|buy rating|sell rating|hold rating|'
  r'analyst|forecast|price objective|maintains)',
  caseSensitive: false,
);

class NewsItem {
  final String headline;
  final String summary;
  final String source;
  final String url;
  final DateTime createdAt;
  final List<String> symbols;

  const NewsItem({
    required this.headline,
    required this.summary,
    required this.source,
    required this.url,
    required this.createdAt,
    required this.symbols,
  });

  /// true si el titular/resumen parece cobertura de analistas (ratings,
  /// price targets) en vez de una noticia genérica.
  bool get isAnalystCoverage =>
      _analystKeywords.hasMatch(headline) || _analystKeywords.hasMatch(summary);

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        headline: json['headline'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        source: json['source'] as String? ?? '',
        url: json['url'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        symbols: ((json['symbols'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}
