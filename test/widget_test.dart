import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment_opname/main.dart';
import 'package:moment_opname/providers/profile_provider.dart';
import 'package:moment_opname/providers/theme_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App starts and shows create profile button', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => ProfileProvider()),
          ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that the title is shown
    expect(find.text('Mijn'), findsOneWidget);
    expect(find.text('eerste stapjes'), findsOneWidget);

    // Verify that the "Profiel toevoegen" text is shown
    expect(find.text('Profiel toevoegen'), findsOneWidget);

    // Verify that the add icon is shown
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
