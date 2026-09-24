import 'package:flutter_test/flutter_test.dart';

import 'package:inversiones_bolsa/models/ai_agent.dart';

void main() {
  test('Los agentes se encuentran por id y hay uno por defecto', () {
    expect(AiAgent.byId('trader').name, 'Trader');
    expect(AiAgent.byId('inversionista').portfolioId, 'inversionista');
    expect(AiAgent.byId('no-existe').id, 'general');
  });

  test('Un mensaje del chat se guarda y se recupera igual', () {
    final m = AiMessage(fromUser: true, text: '¿Cómo está mi cartera?', at: DateTime(2026, 9, 24, 10), isError: false);
    final back = AiMessage.fromJson(m.toJson());
    expect(back.fromUser, true);
    expect(back.text, m.text);
    expect(back.at, m.at);
    expect(back.isError, false);
  });

  test('Las reglas comunes piden aviso de no asesoría y prohíben órdenes', () {
    expect(AiAgent.commonRules, contains('no es asesoría financiera'));
    expect(AiAgent.commonRules, contains('Nunca ejecutas órdenes'));
  });
}
