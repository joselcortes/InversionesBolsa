import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/portfolio_provider.dart';
import 'screens/app_lock_gate.dart';
import 'screens/root_scaffold.dart';
import 'services/background_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  try {
    await BackgroundService.initialize();
  } catch (_) {
    // Si Workmanager no está disponible la app funciona igual, solo sin
    // tareas en segundo plano.
  }
  runApp(const InversionesBolsaApp());
}

class InversionesBolsaApp extends StatelessWidget {
  final PortfolioProvider Function()? providerFactory;

  const InversionesBolsaApp({super.key, this.providerFactory});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory ?? PortfolioProvider.new)()..init(),
      child: Selector<PortfolioProvider, ThemeMode>(
        selector: (_, p) => p.settings.themeMode,
        builder: (context, themeMode, _) => MaterialApp(
          title: 'Inversiones',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          locale: const Locale('es', 'CL'),
          supportedLocales: const [Locale('es', 'CL'), Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppLockGate(child: RootScaffold()),
        ),
      ),
    );
  }
}
