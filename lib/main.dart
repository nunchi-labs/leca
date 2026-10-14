import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home.dart';
import 'l10n/app_localizations.dart';
import 'market.dart';
import 'sign_in.dart';
import 'state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChowApp());
}

class ChowApp extends StatefulWidget {
  const ChowApp({super.key});

  @override
  State<ChowApp> createState() => _ChowAppState();
}

class _ChowAppState extends State<ChowApp> {
  final ChowState _state = ChowState();

  @override
  Widget build(BuildContext context) {
    return ChowScope(
      notifier: _state,
      child: AnimatedBuilder(
        animation: _state,
        builder: (context, _) {
          return MaterialApp(
            title: MarketConfig.brand,
            debugShowCheckedModeBanner: false,
            locale: _state.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: chowTheme,
            home: const _SessionGate(),
          );
        },
      ),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    final state = ChowScope.of(context);
    if (state.session == null) return const SignInScreen();
    return const HomeScreen();
  }
}

const _pepper = Color(0xFFB42318);
const _rice = Color(0xFFF6F0E6);
const _ink = Color(0xFF1A1410);
const _gold = Color(0xFF8A6A2F);

final ThemeData chowTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: _pepper,
    onPrimary: Colors.white,
    secondary: _gold,
    onSecondary: Colors.white,
    surface: _rice,
    onSurface: _ink,
    error: Color(0xFF8B1E1E),
    onError: Colors.white,
  ),
  fontFamily: 'KantumruyPro',
  scaffoldBackgroundColor: _rice,
  appBarTheme: const AppBarTheme(
    backgroundColor: _rice,
    foregroundColor: _ink,
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0x1A1A1410)),
    ),
  ),
);
