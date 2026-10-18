import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'account.dart';
import 'auth.dart';
import 'auth_api.dart';
import 'home.dart';
import 'l10n/app_localizations.dart';
import 'market.dart';
import 'pay.dart';
import 'phone.dart';
import 'phone_gear.dart' if (dart.library.io) 'phone_gear_io.dart';
import 'phone_link.dart' if (dart.library.io) 'phone_link_io.dart';
import 'phone_screen.dart';
import 'sign_in.dart';
import 'state.dart';
import 'swarm.dart';
import 'talk_screen.dart';
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

class _LecaAppState extends State<LecaApp> with WidgetsBindingObserver {
  late final LecaState _state = LecaState(vault: widget.vault);
  late final Handset _handset = Handset(
    link: openPhoneLink(),
    gear: openPhoneGear(),
    onRecord: _state.logPhone,
    onLive: _state.rememberPhone,
    onListed: (endpoint, addr) => unawaited(_listPhone(endpoint, addr)),
  );
  var _phoneWanted = false;
  var _phoneGen = 0;
  String _listed = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state.addListener(_syncPhone);
    unawaited(_state.restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.removeListener(_syncPhone);
    _phoneGen += 1;
    unawaited(_handset.close());
    _state.dispose();
    super.dispose();
  }

  void _syncPhone() {
    final signedIn = _state.restored && _state.session != null;
    if (signedIn == _phoneWanted) return;
    _phoneWanted = signedIn;
    if (signedIn) {
      unawaited(_bootPhone());
      return;
    }
    _phoneGen += 1;
    unawaited(_handset.close());
  }

  Future<void> _bootPhone() async {
    final gen = ++_phoneGen;
    final key = await _state.ensureDeviceKey();
    if (!mounted || gen != _phoneGen || !_phoneWanted) return;
    await _handset.open(secret: key.seed, fallback: z32Encode(key.publicKey));
  }

  Future<void> _listPhone(String endpoint, String addr) async {
    final card = '$endpoint $addr';
    if (card == _listed || !AuthConfig.apiLive) return;
    final token = _state.session?.token;
    if (token == null || token.isEmpty) return;
    _listed = card;
    try {
      await AuthApi.post('/v1/phone/here', {
        'endpoint': endpoint,
        'addr': addr,
      }, token: token);
    } on Object catch (_) {
      if (_listed == card) _listed = '';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _state.flushSave();
    }
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
            builder: (context, child) {
              return PhoneScope(
                handset: _handset,
                child: PhoneShell(child: child ?? const SizedBox.shrink()),
              );
            },
            home: const _FrontGate(),
          );
        },
      ),
    );
  }
}

class _FrontGate extends StatelessWidget {
  const _FrontGate();

  @override
  Widget build(BuildContext context) {
    final state = LecaScope.of(context);
    if (!state.restored) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final l10n = AppLocalizations.of(context);
    return TalkScreen(
      room: frontRoom,
      title: l10n.chat,
      fareKey: frontFare,
      onMarket: () {
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
      },
      onSignIn: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SignInScreen()));
      },
      onAccount: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));
      },
      onCheckout: () {
        final live = LecaScope.of(context);
        final usd = live.payable(frontFare, 0);
        if (usd <= 0) return;
        live.setBooking(
          Booking(
            kind: BookKind.goods,
            title: l10n.chat,
            amountUsd: usd,
            detail: frontRoom,
          ),
        );
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const PayScreen()));
      },
    );
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
