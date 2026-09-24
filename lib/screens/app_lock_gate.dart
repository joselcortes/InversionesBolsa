import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../services/auth_gate_service.dart';

/// Si el bloqueo de app está activo, pide huella/PIN al abrir la app y al
/// volver después de más de 1 minuto en segundo plano.
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  static const _relockAfter = Duration(minutes: 1);
  final _auth = AuthGateService();
  bool _unlocked = false;
  bool _authenticating = false;
  bool _checkedInitial = false;
  String? _message;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      final enabled = context.read<PortfolioProvider>().settings.appLock;
      if (enabled &&
          _unlocked &&
          pausedAt != null &&
          DateTime.now().difference(pausedAt) > _relockAfter) {
        setState(() => _unlocked = false);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });
    final r = await _auth.confirmIdentity(reason: 'Desbloquea tus inversiones', strict: true);
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _unlocked = r == AuthResult.ok;
      _message = r == AuthResult.ok ? null : AuthGateService.failureMessage(r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    if (!provider.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!provider.settings.appLock) {
      // Si el bloqueo se activa con la app ya abierta (desde Ajustes, tras
      // autenticarse), no hay que volver a pedirlo en ese momento.
      _unlocked = true;
      return widget.child;
    }
    // La app queda montada debajo para no perder la navegación al bloquear.
    return Stack(
      children: [
        widget.child,
        if (!_unlocked) _lockScreen(context),
      ],
    );
  }

  Widget _lockScreen(BuildContext context) {
    if (!_checkedInitial) {
      _checkedInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 56, color: scheme.primary),
                const SizedBox(height: 16),
                const Text('App bloqueada',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  _message ?? 'Usa tu huella, rostro o PIN para entrar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _authenticating ? null : _unlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Desbloquear'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
