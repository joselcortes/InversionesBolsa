import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_agent.dart';

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

/// Habla con Gemini usando el plan gratuito de Google AI Studio.
///
/// La API key la crea el usuario en https://aistudio.google.com/apikey y se
/// guarda cifrada en el teléfono (igual que las claves de Alpaca). No pasa por
/// ningún servidor propio: la app llama directo a Google.
class AiService {
  static const keysUrl = 'https://aistudio.google.com/apikey';
  static const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// Se prueban en orden; si uno no existe (404) se usa el siguiente. Los
  /// alias "-latest" apuntan siempre al Flash vigente, así la app no se rompe
  /// cuando Google retira un modelo.
  static const models = ['gemini-flash-latest', 'gemini-flash-lite-latest'];

  static const _keyName = 'gemini_api_key';
  static const _historyPrefix = 'ai_chat_v1_';
  static const _maxStored = 40;

  final http.Client _client;
  final FlutterSecureStorage _storage;

  AiService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  // ------------------------------------------------------------ API key

  Future<String?> loadKey() async {
    final k = await _storage.read(key: _keyName);
    return (k == null || k.trim().isEmpty) ? null : k.trim();
  }

  Future<void> saveKey(String key) => _storage.write(key: _keyName, value: key.trim());

  Future<void> clearKey() => _storage.delete(key: _keyName);

  /// Verifica que la clave funcione con una consulta mínima.
  Future<void> testKey(String key) async {
    await _generate(
      key: key.trim(),
      system: 'Responde solo "ok".',
      history: [AiMessage(fromUser: true, text: 'ping', at: DateTime.now())],
      maxTokens: 16,
    );
  }

  // ------------------------------------------------------------ Chat

  /// Envía la conversación y devuelve la respuesta del agente.
  Future<String> ask({
    required AiAgent agent,
    required List<AiMessage> history,
    required String context,
  }) async {
    final key = await loadKey();
    if (key == null) throw AiException('Falta configurar la clave de Gemini.');
    final system = '${agent.persona}\n\n${AiAgent.commonRules}\n\n'
        'Fecha de hoy: ${DateTime.now().toIso8601String().substring(0, 10)}.\n\n'
        'DATOS (actualizados al abrir el chat):\n$context';
    return _generate(key: key, system: system, history: history, maxTokens: 2048);
  }

  Future<String> _generate({
    required String key,
    required String system,
    required List<AiMessage> history,
    required int maxTokens,
  }) async {
    // Solo los últimos mensajes, para no gastar la cuota gratuita.
    final recent = history.where((m) => !m.isError).toList();
    final trimmed = recent.length > 16 ? recent.sublist(recent.length - 16) : recent;
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': [
        for (final m in trimmed)
          {
            'role': m.fromUser ? 'user' : 'model',
            'parts': [
              {'text': m.text}
            ]
          }
      ],
      'generationConfig': {'temperature': 0.4, 'maxOutputTokens': maxTokens},
    });

    AiException? last;
    for (final model in models) {
      final http.Response res;
      try {
        res = await _client
            .post(
              Uri.parse('$_base/$model:generateContent'),
              headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
              body: body,
            )
            .timeout(const Duration(seconds: 60));
      } on TimeoutException {
        throw AiException('Gemini tardó demasiado en responder. Intenta de nuevo.');
      } catch (_) {
        throw AiException('Sin conexión a internet.');
      }

      if (res.statusCode == 200) return _extractText(utf8.decode(res.bodyBytes));
      if (res.statusCode == 404) {
        last = AiException('El modelo $model no está disponible.');
        continue;
      }
      throw AiException(_friendlyError(res.statusCode, utf8.decode(res.bodyBytes, allowMalformed: true)));
    }
    throw last ?? AiException('No hay un modelo de Gemini disponible.');
  }

  static String _extractText(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final candidates = (data['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) {
      final reason = (data['promptFeedback'] as Map?)?['blockReason'];
      throw AiException(reason != null
          ? 'Gemini no quiso responder esa pregunta ($reason).'
          : 'Gemini no devolvió respuesta.');
    }
    final parts = ((candidates.first as Map)['content'] as Map?)?['parts'] as List? ?? const [];
    final text = parts
        .whereType<Map>()
        .where((p) => p['thought'] != true)
        .map((p) => p['text'] as String? ?? '')
        .join()
        .trim();
    if (text.isEmpty) throw AiException('Gemini devolvió una respuesta vacía.');
    return text;
  }

  static String _friendlyError(int status, String body) {
    String detail = '';
    try {
      detail = ((jsonDecode(body) as Map)['error'] as Map?)?['message'] as String? ?? '';
    } catch (_) {
      // Respuesta sin JSON: se muestra solo el código.
    }
    switch (status) {
      case 400:
        if (detail.contains('API key')) return 'La clave de Gemini no es válida. Revísala en Ajustes del asistente.';
        if (detail.toLowerCase().contains('location')) {
          return 'El plan gratuito de Gemini no está disponible desde tu ubicación.';
        }
        return 'Gemini rechazó la consulta. $detail';
      case 401:
      case 403:
        return 'La clave de Gemini no tiene permiso. Crea una nueva en aistudio.google.com/apikey.';
      case 429:
        return 'Se alcanzó el límite gratuito de Gemini (por minuto o por día). '
            'Espera un momento y vuelve a intentar.';
      default:
        if (status >= 500) return 'Gemini está con problemas ($status). Intenta en unos minutos.';
        return 'Error de Gemini ($status). $detail';
    }
  }

  // ------------------------------------------------------------ Historial

  static Future<List<AiMessage>> loadHistory(String agentId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_historyPrefix$agentId');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => AiMessage.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveHistory(String agentId, List<AiMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final keep = messages.length > _maxStored ? messages.sublist(messages.length - _maxStored) : messages;
    await prefs.setString('$_historyPrefix$agentId', jsonEncode(keep.map((m) => m.toJson()).toList()));
  }

  static Future<void> clearHistory(String agentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_historyPrefix$agentId');
  }
}
