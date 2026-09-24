import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/store_catalog.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// "Mi tienda": tus apps con su versión, novedades y botón para
/// actualizar, al estilo de Play Store.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  StoreCatalog? _catalog;
  InstalledVersion? _installed;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        UpdateService.fetchCatalog(),
        UpdateService.installed(),
      ]);
      _catalog = results[0] as StoreCatalog;
      _installed = results[1] as InstalledVersion;
      if (UpdateService.canSelfUpdate) await UpdateService.check();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final apps = _catalog?.apps ?? const <StoreApp>[];
    final mine = _installed == null ? null : _catalog?.byPackage(_installed!.packageName);
    final others = apps.where((a) => a != mine).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi tienda')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'No pudimos abrir la tienda',
                message: _error!,
                actionLabel: 'Reintentar',
                onAction: _load,
              )
            else ...[
              if (mine != null) _AppCard(app: mine, installed: _installed, isThisApp: true),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionTitle('Otras apps'),
                ...others.map((a) => _AppCard(app: a, installed: null, isThisApp: false)),
              ],
              if (apps.isEmpty)
                const EmptyState(
                  icon: Icons.storefront_rounded,
                  title: 'La tienda está vacía',
                  message: 'Todavía no hay apps publicadas.',
                ),
              const SizedBox(height: 16),
              Text(
                'La tienda vive en tu Firebase y los instaladores en tu GitHub. Cada descarga se verifica '
                'con su huella SHA-256 antes de instalarse.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppCard extends StatefulWidget {
  final StoreApp app;
  final InstalledVersion? installed;
  final bool isThisApp;
  const _AppCard({required this.app, required this.installed, required this.isThisApp});

  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard> {
  double? _progress;
  String? _status;
  bool _busy = false;

  StoreRelease? get _latest => widget.app.latest;

  bool get _hasUpdate {
    final l = _latest;
    final i = widget.installed;
    return l != null && i != null && l.build > i.build && l.apk != null;
  }

  Future<void> _update() async {
    final r = _latest!;
    setState(() {
      _busy = true;
      _status = 'Revisando permisos…';
      _progress = null;
    });
    try {
      if (!await UpdateService.canInstall()) {
        if (!mounted) return;
        final go = await confirmDialog(
          context,
          title: 'Falta un permiso',
          message: 'Para actualizar, Android necesita que permitas a "Inversiones" instalar apps. '
              'Se abrirá el ajuste: activa "Permitir de esta fuente" y vuelve aquí.',
          confirmLabel: 'Abrir ajuste',
        );
        if (go) await UpdateService.openInstallPermission();
        setState(() {
          _busy = false;
          _status = go ? 'Cuando lo actives, vuelve a tocar Actualizar.' : null;
        });
        return;
      }
      setState(() => _status = 'Descargando…');
      final path = await UpdateService.download(r, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      setState(() {
        _status = 'Verificado ✓ Abriendo el instalador…';
        _progress = 1;
      });
      await UpdateService.install(path);
      setState(() {
        _busy = false;
        _status = 'Confirma en la pantalla de Android. La app se reiniciará con la versión nueva.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _status = null;
      });
      showSnack(context, 'No se pudo actualizar: $e');
    }
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _size(int? bytes) => bytes == null ? '' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = widget.app;
    final l = _latest;
    final i = widget.installed;
    final dateFmt = DateFormat("d 'de' MMMM yyyy", 'es');
    final upToDate = widget.isThisApp && i != null && l != null && !_hasUpdate;

    Widget action;
    if (!UpdateService.canSelfUpdate && widget.isThisApp) {
      action = const _Pill(text: 'La versión web se actualiza sola', color: AppTheme.up);
    } else if (_hasUpdate) {
      action = FilledButton.icon(
        onPressed: _busy ? null : _update,
        icon: const Icon(Icons.system_update_rounded),
        label: Text('Actualizar a ${l!.version}'),
      );
    } else if (upToDate) {
      action = const _Pill(text: 'Al día ✓', color: AppTheme.up);
    } else {
      action = OutlinedButton.icon(
        onPressed: l?.apk == null ? null : () => _openInBrowser(UpdateService.apkUri(l!.apk!).toString()),
        icon: const Icon(Icons.download_rounded),
        label: const Text('Descargar'),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: app.icon.isEmpty
                      ? Container(width: 56, height: 56, color: scheme.primaryContainer)
                      : Image.network('${UpdateService.storeBase}${app.icon}',
                          width: 56,
                          height: 56,
                          errorBuilder: (_, _, _) =>
                              Container(width: 56, height: 56, color: scheme.primaryContainer)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(app.description,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (l != null) _Meta(label: 'Última versión', value: l.version),
                if (widget.isThisApp && i != null) _Meta(label: 'Tienes', value: i.version),
                if (l?.sizeBytes != null) _Meta(label: 'Tamaño', value: _size(l!.sizeBytes)),
                if (l != null) _Meta(label: 'Publicada', value: dateFmt.format(l.date.toLocal())),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: action),
            if (_progress != null || _status != null) ...[
              const SizedBox(height: 10),
              if (_progress != null)
                LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _progress != null && _progress! < 1
                        ? '$_status ${(_progress! * 100).toStringAsFixed(0)}%'
                        : _status!,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
            if (l != null && l.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Novedades', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ...l.notes.map((n) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(n)),
                      ],
                    ),
                  )),
            ],
            if (app.releases.length > 1)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Versiones anteriores', style: TextStyle(fontSize: 14)),
                  children: app.releases.skip(1).map((r) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('${r.version} · ${dateFmt.format(r.date.toLocal())}'),
                      subtitle: Text(r.notes.join('\n')),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final String label;
  final String value;
  const _Meta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      );
}

/// Aviso al abrir la app cuando hay una versión nueva (solo Android).
Future<void> maybeShowUpdatePrompt(BuildContext context) async {
  if (!UpdateService.canSelfUpdate) return;
  StoreRelease? r;
  try {
    r = await UpdateService.check(respectSkip: true);
  } catch (_) {
    return; // Sin red: se intentará la próxima vez.
  }
  if (r == null || !context.mounted) return;
  final release = r;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.system_update_rounded, size: 36),
      title: Text('Nueva versión ${release.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Novedades:', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...release.notes.take(5).map((n) => Text('• $n')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ver en Mi tienda')),
      ],
    ),
  );
  if (!context.mounted) return;
  if (go == true) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoreScreen()));
  } else {
    await UpdateService.skip(release);
  }
}
