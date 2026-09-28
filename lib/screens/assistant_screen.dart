import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ai_agent.dart';
import '../providers/portfolio_provider.dart';
import '../services/ai_context.dart';
import '../services/ai_service.dart';
import '../widgets/common_widgets.dart';

/// Chat con los agentes de finanzas (Gemini, plan gratuito). Los agentes ven
/// tu cuenta de Alpaca y sus carteras simuladas, opinan y responden
/// preguntas; nunca envían órdenes.
class AssistantScreen extends StatefulWidget {
  final String initialAgentId;
  const AssistantScreen({super.key, this.initialAgentId = 'general'});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _ai = AiService();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  late AiAgent _agent = AiAgent.byId(widget.initialAgentId);
  List<AiMessage> _messages = [];
  bool _hasKey = false;
  bool _loadingKey = true;
  bool _thinking = false;
  AgentsData? _agentsData;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final key = await _ai.loadKey();
    final history = await AiService.loadHistory(_agent.id);
    if (!mounted) return;
    setState(() {
      _hasKey = key != null;
      _loadingKey = false;
      _messages = history;
    });
    _scrollToEnd();
    AgentsData.fetch().then((d) {
      if (mounted) setState(() => _agentsData = d);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _switchAgent(AiAgent a) async {
    if (a.id == _agent.id || _thinking) return;
    final history = await AiService.loadHistory(a.id);
    if (!mounted) return;
    setState(() {
      _agent = a;
      _messages = history;
    });
    _scrollToEnd();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();
    final agent = _agent;
    setState(() {
      _messages = [..._messages, AiMessage(fromUser: true, text: text, at: DateTime.now())];
      _thinking = true;
    });
    _scrollToEnd();

    final provider = context.read<PortfolioProvider>();
    _agentsData ??= await AgentsData.fetch();
    final contextText = AiContextBuilder.build(agent: agent, provider: provider, agents: _agentsData);

    AiMessage reply;
    try {
      final answer = await _ai.ask(agent: agent, history: _messages, context: contextText);
      reply = AiMessage(fromUser: false, text: answer, at: DateTime.now());
    } on AiException catch (e) {
      reply = AiMessage(fromUser: false, text: e.message, at: DateTime.now(), isError: true);
    } catch (e) {
      reply = AiMessage(fromUser: false, text: 'Error inesperado: $e', at: DateTime.now(), isError: true);
    }
    if (!mounted) return;
    // Si el usuario cambió de agente mientras esperaba, la respuesta se
    // guarda igual en la conversación correcta.
    if (agent.id == _agent.id) {
      setState(() {
        _messages = [..._messages, reply];
        _thinking = false;
      });
      await AiService.saveHistory(agent.id, _messages);
    } else {
      final h = await AiService.loadHistory(agent.id);
      await AiService.saveHistory(agent.id, [...h, reply]);
      if (mounted) setState(() => _thinking = false);
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _clearChat() async {
    final ok = await confirmDialog(context,
        title: 'Borrar conversación',
        message: 'Se borra el historial con ${_agent.name} en este teléfono.',
        confirmLabel: 'Borrar',
        destructive: true);
    if (!ok) return;
    await AiService.clearHistory(_agent.id);
    if (mounted) setState(() => _messages = []);
  }

  Future<void> _removeKey() async {
    final ok = await confirmDialog(context,
        title: 'Quitar clave de Gemini',
        message: 'El asistente dejará de funcionar hasta que ingreses una clave nueva.',
        confirmLabel: 'Quitar',
        destructive: true);
    if (!ok) return;
    await _ai.clearKey();
    if (mounted) setState(() => _hasKey = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente IA'),
        actions: [
          if (_hasKey)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'clear') _clearChat();
                if (v == 'key') _removeKey();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'clear', child: Text('Borrar esta conversación')),
                PopupMenuItem(value: 'key', child: Text('Quitar clave de Gemini')),
              ],
            ),
        ],
      ),
      body: _loadingKey
          ? const Center(child: CircularProgressIndicator())
          : !_hasKey
              ? _KeySetup(ai: _ai, onSaved: () => setState(() => _hasKey = true))
              : SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      _AgentSelector(selected: _agent, onSelected: _switchAgent),
                      Expanded(child: _messages.isEmpty ? _emptyChat() : _chatList()),
                      if (_thinking) _thinkingRow(),
                      _inputBar(),
                    ],
                  ),
                ),
    );
  }

  Widget _emptyChat() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: _agent.color.withValues(alpha: 0.15),
            child: Icon(_agent.icon, color: _agent.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_agent.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text(_agent.description, style: TextStyle(color: scheme.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.insights_rounded),
          label: const Text('Pedir opinión de mi cartera'),
          onPressed: () => _send('Revisa mi cartera y los datos disponibles y dame tu opinión: '
              'qué está bien, qué riesgos ves y qué harías tú, con números.'),
        ),
        const SizedBox(height: 16),
        Text('O pregúntale algo:', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _agent.suggestions) ActionChip(label: Text(s), onPressed: () => _send(s)),
          ],
        ),
        const SizedBox(height: 20),
        const InfoBanner('Los agentes ven tu cuenta y sus carteras simuladas, pero nunca envían '
            'órdenes. Sus respuestas son referenciales, no asesoría financiera.'),
      ],
    );
  }

  Widget _chatList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _Bubble(message: _messages[i], agent: _agent),
    );
  }

  Widget _thinkingRow() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Text('${_agent.name} está analizando…', style: TextStyle(color: scheme.onSurfaceVariant)),
      ]),
    );
  }

  Widget _inputBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: 'Pregúntale a ${_agent.name}…',
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        IconButton.filled(
          onPressed: _thinking ? null : () => _send(),
          icon: const Icon(Icons.send_rounded),
          tooltip: 'Enviar',
        ),
      ]),
    );
  }
}

class _AgentSelector extends StatelessWidget {
  final AiAgent selected;
  final ValueChanged<AiAgent> onSelected;
  const _AgentSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(children: [
        for (final a in AiAgent.all)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(a.icon, size: 18, color: a.color),
              label: Text(a.name),
              selected: a.id == selected.id,
              onSelected: (_) => onSelected(a),
            ),
          ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final AiMessage message;
  final AiAgent agent;
  const _Bubble({required this.message, required this.agent});

  /// Gemini responde en Markdown; aquí se simplifica para texto plano.
  static String _plain(String s) => s
      .replaceAll('**', '')
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[*-]\s+', multiLine: true), '• ');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.fromUser;
    final bg = message.isError
        ? scheme.errorContainer
        : mine
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh;
    final fg = message.isError
        ? scheme.onErrorContainer
        : mine
            ? scheme.onPrimaryContainer
            : scheme.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!mine && !message.isError)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(agent.icon, size: 14, color: agent.color),
                  const SizedBox(width: 4),
                  Text(agent.name,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: agent.color)),
                ]),
              ),
            SelectableText(mine ? message.text : _plain(message.text), style: TextStyle(color: fg, height: 1.35)),
          ]),
        ),
      ),
    );
  }
}

/// Primera vez: explica cómo obtener la clave gratuita y la guarda.
class _KeySetup extends StatefulWidget {
  final AiService ai;
  final VoidCallback onSaved;
  const _KeySetup({required this.ai, required this.onSaved});

  @override
  State<_KeySetup> createState() => _KeySetupState();
}

class _KeySetupState extends State<_KeySetup> {
  final _key = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final k = _key.text.trim();
    if (k.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.ai.testKey(k);
      await widget.ai.saveKey(k);
      if (mounted) widget.onSaved();
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo verificar la clave: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(Icons.auto_awesome_rounded, size: 48, color: scheme.primary),
        const SizedBox(height: 12),
        const Text('Activa tus agentes de finanzas',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'El asistente usa Gemini de Google con su plan gratuito. Solo necesitas una clave '
          '(gratis, sin tarjeta):',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        const Text('1. Abre Google AI Studio e inicia sesión con tu cuenta de Google.'),
        const SizedBox(height: 6),
        const Text('2. Toca "Create API key" y copia la clave.'),
        const SizedBox(height: 6),
        const Text('3. Pégala aquí abajo.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Abrir Google AI Studio'),
          onPressed: () => launchUrl(Uri.parse(AiService.keysUrl), mode: LaunchMode.externalApplication),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Clave de Gemini (API key)',
            border: const OutlineInputBorder(),
            errorText: _error,
            errorMaxLines: 3,
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verificar y guardar'),
        ),
        const SizedBox(height: 20),
        const InfoBanner(
          'La clave se guarda cifrada solo en este dispositivo. En el plan gratuito, Google puede '
          'usar lo que envías para mejorar sus productos: los agentes reciben tus posiciones y '
          'saldos, pero nunca tus claves de Alpaca.',
          icon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }
}
