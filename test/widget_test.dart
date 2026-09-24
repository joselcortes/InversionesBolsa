import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inversiones_bolsa/main.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await initializeDateFormatting('es');
  });

  Future<void> start(WidgetTester tester) async {
    // Tamaño de un celular (360x800 lógicos).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const InversionesBolsaApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Desplaza hasta que el widget quede completamente visible (no tapado por
  // la barra de navegación) usando la lista que está en pantalla.
  Future<void> reveal(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).hitTestable().first);
    await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -150));
    await tester.pumpAndSettle();
  }

  testWidgets('Sin cuenta, Inicio da la bienvenida y explica cómo empezar', (tester) async {
    await start(tester);

    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Más'), findsOneWidget);
    expect(find.text('¡Hola! 👋'), findsOneWidget);
    await reveal(tester, find.text('Conectar mi cuenta'));
    expect(find.text('Conectar mi cuenta'), findsOneWidget);
  });

  testWidgets('Aprende muestra la guía y abre una explicación', (tester) async {
    await start(tester);

    await reveal(tester, find.text('Aprender lo básico primero'));
    await tester.tap(find.text('Aprender lo básico primero'));
    await tester.pumpAndSettle();
    expect(find.text('Empieza aquí'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'stop');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop-loss').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Es un "freno"'), findsOneWidget);
  });

  testWidgets('Ajustes (desde Más) muestra moneda y privacidad', (tester) async {
    await start(tester);

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Ajustes'));
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    expect(find.text('Apariencia y moneda'), findsOneWidget);
    expect(find.text('Mostrar montos en pesos chilenos'), findsOneWidget);
    await reveal(tester, find.text('Pesos como moneda principal'));
    expect(find.text('Pesos como moneda principal'), findsOneWidget);
  });
}
