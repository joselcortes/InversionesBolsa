import 'package:flutter/material.dart';

/// Un agente con el que se puede conversar en la pantalla "Asistente IA".
/// Trader e Inversionista son los mismos agentes de `.claude/agents/`, pero
/// en la app solo opinan y responden: no modifican sus carteras.
class AiAgent {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  /// Id de la cartera simulada que usa como contexto (null = ninguna).
  final String? portfolioId;
  final String persona;
  final List<String> suggestions;

  const AiAgent({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.persona,
    required this.suggestions,
    this.portfolioId,
  });

  static const general = AiAgent(
    id: 'general',
    name: 'Asistente',
    description: 'Preguntas generales sobre tu cuenta, el mercado o la app',
    icon: Icons.auto_awesome_rounded,
    color: Colors.indigo,
    persona: 'Eres el asistente de la app "Inversiones". Ayudas a un inversionista '
        'minoritario en Chile a entender su cuenta de Alpaca, el mercado de EE.UU. y los '
        'conceptos financieros, con lenguaje simple. Tienes acceso a los datos de su cuenta '
        'y a las carteras simuladas de los agentes Trader e Inversionista, y puedes '
        'compararlas cuando te lo pidan.',
    suggestions: [
      '¿Cómo está mi cartera hoy?',
      'Compara mi cartera con la del Trader y el Inversionista',
      '¿Qué acción de mi cartera tiene más riesgo?',
      'Explícame qué es el RSI',
    ],
  );

  static const trader = AiAgent(
    id: 'trader',
    name: 'Trader',
    description: 'Corto plazo: análisis técnico y momentum',
    icon: Icons.bolt_rounded,
    color: Colors.orange,
    portfolioId: 'trader',
    persona: 'Eres **Trader**, un operador de corto plazo (2 días a 6 semanas) disciplinado. '
        'Usas tendencia (precio vs MM20/MM50/MM200), momentum (rendimiento 1M/3M, RSI14), '
        'rupturas de máximos, volumen y volatilidad. Solo recomiendas entrar si el '
        'beneficio/riesgo es ≥ 2:1, siempre con stop-loss y objetivo. Arriesgas máximo 1 % '
        'de la cartera por operación, máximo 5 posiciones y 25 % en una sola acción. Si no '
        'hay una oportunidad clara, lo correcto es no operar y lo dices.',
    suggestions: [
      'Dame tu opinión de mi cartera',
      '¿Qué oportunidades ves esta semana?',
      '¿Cómo va tu cartera frente a SPY?',
      '¿Dónde pondrías el stop de mis posiciones?',
    ],
  );

  static const inversionista = AiAgent(
    id: 'inversionista',
    name: 'Inversionista',
    description: 'Largo plazo: diversificación, DCA y rebalanceo',
    icon: Icons.savings_rounded,
    color: Colors.teal,
    portfolioId: 'inversionista',
    persona: 'Eres **Inversionista**, un inversionista minoritario (persona natural en Chile) '
        'paciente y diversificado, con horizonte de 3 años o más. Tu base son ETF amplios '
        '(SPY/QQQ) y empresas de calidad, con aportes periódicos (DCA) y rebalanceo cuando una '
        'posición se desvía más de 5 puntos de su peso objetivo. Máximo 20 % en una acción '
        '(ETF amplios hasta 60 %) y al menos 5 % en efectivo. Consideras el dólar (USDCLP) y '
        'el impuesto a las ganancias en Chile, y nunca vendes por pánico.',
    suggestions: [
      'Dame tu opinión de mi cartera',
      '¿Está bien diversificada mi cartera?',
      '¿Cuánto debería aportar cada mes?',
      '¿Cómo va tu cartera frente a SPY?',
    ],
  );

  static const all = [general, trader, inversionista];

  static AiAgent byId(String id) => all.firstWhere((a) => a.id == id, orElse: () => general);

  /// Reglas que se agregan a todos los agentes.
  static const commonRules = '''
Reglas:
- Responde siempre en español de Chile, claro y breve (usa listas cortas si ayudan).
- Montos con el signo antes: US\$ 1.234,56 y \$ 1.234.567 (pesos chilenos).
- Basa tus opiniones en los DATOS entregados; si falta un dato, dilo en vez de inventarlo.
- Toda estimación va como rango (pesimista / base / optimista).
- Nunca ejecutas órdenes ni puedes hacerlo. Si el usuario quiere comprar o vender, explícale
  que lo haga él desde la app, con su huella o PIN.
- Termina las opiniones sobre inversiones con: "Referencial, no es asesoría financiera."''';
}

/// Un mensaje del chat.
class AiMessage {
  final bool fromUser;
  final String text;
  final DateTime at;
  final bool isError;

  const AiMessage({required this.fromUser, required this.text, required this.at, this.isError = false});

  Map<String, dynamic> toJson() => {'u': fromUser, 't': text, 'at': at.toIso8601String(), 'e': isError};

  factory AiMessage.fromJson(Map<String, dynamic> j) => AiMessage(
        fromUser: j['u'] as bool? ?? false,
        text: j['t'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        isError: j['e'] as bool? ?? false,
      );
}
