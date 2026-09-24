import 'dart:async';

import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/update_service.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'market_screen.dart';
import 'more_screen.dart';
import 'portfolio_screen.dart';
import 'store_screen.dart';

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;
  StreamSubscription<String>? _messages;

  @override
  void initState() {
    super.initState();
    // Versión web: los avisos (alertas, órdenes ejecutadas) llegan aquí.
    _messages = NotificationService.inAppMessages.stream.listen((m) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
      ));
    });
    // Revisa si hay una versión nueva unos segundos después de abrir, para
    // no competir con la carga de la cuenta.
    if (UpdateService.canSelfUpdate) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) maybeShowUpdatePrompt(context);
      });
    }
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onGoToTab: _goTo),
          const MarketScreen(),
          const PortfolioScreen(),
          const AlertsScreen(),
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.show_chart_rounded), label: 'Mercado'),
          NavigationDestination(icon: Icon(Icons.pie_chart_rounded), label: 'Portafolio'),
          NavigationDestination(icon: Icon(Icons.notifications_rounded), label: 'Alertas'),
          NavigationDestination(icon: Icon(Icons.menu_rounded), label: 'Más'),
        ],
      ),
    );
  }
}
