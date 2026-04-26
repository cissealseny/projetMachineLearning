import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/public_landing_screen.dart';
import 'screens/signup_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const EcoSmartApp());
}

enum AppView { public, login, signup, private }

class EcoSmartApp extends StatefulWidget {
  const EcoSmartApp({super.key});

  @override
  State<EcoSmartApp> createState() => _EcoSmartAppState();
}

class _EcoSmartAppState extends State<EcoSmartApp> {
  final ApiService _api = ApiService();
  AppView _view = AppView.public;

  String _asReadableError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    return raw;
  }

  Future<String?> _login(String username, String password) async {
    try {
      await _api.login(username: username, password: password);
      if (!mounted) return null;
      setState(() => _view = AppView.private);
      return null;
    } catch (error) {
      return _asReadableError(error);
    }
  }

  Future<String?> _quickAccess() async {
    try {
      await _api.quickLogin();
      if (!mounted) return null;
      setState(() => _view = AppView.private);
      return null;
    } catch (error) {
      return _asReadableError(error);
    }
  }

  Future<String?> _signup(
    String fullName,
    String email,
    String username,
    String password,
  ) async {
    return 'Inscription API bientôt disponible. Utilisez Accès démo ou un compte existant.';
  }

  void _logout() {
    _api.logout();
    setState(() => _view = AppView.public);
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF000091);
    const nightBlue = Color(0xFF02124C);
    const softBlue = Color(0xFFE8EDFF);

    final Widget currentScreen;
    switch (_view) {
      case AppView.public:
        currentScreen = PublicLandingScreen(
          api: _api,
          onLoginPressed: () => setState(() => _view = AppView.login),
          onSignupPressed: () => setState(() => _view = AppView.signup),
          onQuickAccess: _quickAccess,
        );
      case AppView.login:
        currentScreen = LoginScreen(
          onBack: () => setState(() => _view = AppView.public),
          onSignupPressed: () => setState(() => _view = AppView.signup),
          onLogin: _login,
          onQuickAccess: _quickAccess,
        );
      case AppView.signup:
        currentScreen = SignupScreen(
          onBack: () => setState(() => _view = AppView.public),
          onLoginPressed: () => setState(() => _view = AppView.login),
          onSignup: _signup,
        );
      case AppView.private:
        currentScreen = HomeScreen(api: _api, onLogout: _logout);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eco-Smart',
      theme: ThemeData(
        fontFamily: 'Segoe UI',
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: nightBlue,
          ),
          headlineMedium: TextStyle(
            fontWeight: FontWeight.w800,
            color: nightBlue,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.w700,
            color: nightBlue,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Color(0xFFDCE2F6)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryBlue, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryBlue,
            side: const BorderSide(color: primaryBlue),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: softBlue,
          selectedColor: softBlue,
          disabledColor: softBlue,
          labelStyle:
              const TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
          side: BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        useMaterial3: true,
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(_view),
          child: currentScreen,
        ),
      ),
    );
  }
}
