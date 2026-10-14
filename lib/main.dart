import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home.dart';
import 'l10n/app_localizations.dart';
import 'market.dart';
import 'sign_in.dart';
import 'state.dart';
import 'vault.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LecaApp(vault: PrefsVault()));
}

class LecaApp extends StatefulWidget {
  const LecaApp({super.key, this.vault});

  /// Where state lives between launches. Null keeps it in memory.
  final Vault? vault;

  @override
  State<LecaApp> createState() => _LecaAppState();
}

class _LecaAppState extends State<LecaApp> {
  late final LecaState _state = LecaState(vault: widget.vault);

  @override
  void initState() {
    super.initState();
    _state.restore();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LecaScope(
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
            theme: lecaTheme,
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
    final state = LecaScope.of(context);
    if (!state.restored) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.session == null) return const SignInScreen();
    return const HomeScreen();
  }
}

const _pepper = Color(0xFFB42318);
const _rice = Color(0xFFF6F0E6);
const _ink = Color(0xFF1A1410);
const _gold = Color(0xFF8A6A2F);

final ThemeData lecaTheme = ThemeData(
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
