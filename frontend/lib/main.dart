import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );
  final appState = AppState();
  await appState.load();
  await NotificationService.instance.initialize();
  runApp(PadmaMangalApp(appState: appState));
}

class PadmaMangalApp extends StatefulWidget {
  final AppState appState;
  const PadmaMangalApp({super.key, required this.appState});

  @override
  State<PadmaMangalApp> createState() => _PadmaMangalAppState();
}

class _PadmaMangalAppState extends State<PadmaMangalApp> {
  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  ThemeData _buildTheme(Brightness brightness) {
    const primary   = Color(0xFF7C3AED); // deep violet
    const secondary = Color(0xFF9B59B6);
    final isDark    = brightness == Brightness.dark;

    final cs = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary:   primary,
      secondary: secondary,
      surface:   isDark ? const Color(0xFF1C1B2E) : Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: isDark ? const Color(0xFF111020) : const Color(0xFFF8F7FF),

      // ── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor:           isDark ? const Color(0xFF1C1B2E) : Colors.white,
        foregroundColor:           isDark ? Colors.white : const Color(0xFF1A1A2E),
        elevation:                 0,
        scrolledUnderElevation:    0.5,
        shadowColor:               Colors.black.withValues(alpha: 0.06),
        centerTitle:               false,
        titleTextStyle: TextStyle(
          fontSize:     20,
          fontWeight:   FontWeight.bold,
          color:        isDark ? Colors.white : const Color(0xFF1A1A2E),
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:          Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),

      // ── Cards ──────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color:     isDark ? const Color(0xFF1C1B2E) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ── Drawer ─────────────────────────────────────────────────────────
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? const Color(0xFF1C1B2E) : Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(0))),
      ),

      // ── Inputs ─────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:         true,
        fillColor:      isDark ? const Color(0xFF2A2740) : const Color(0xFFF5F3FF),
        border:         OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder:  OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Bottom nav ─────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:      isDark ? const Color(0xFF1C1B2E) : Colors.white,
        indicatorColor:       primary.withValues(alpha: 0.14),
        labelTextStyle:       WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize:     11,
          fontWeight:   s.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
          color:        s.contains(WidgetState.selected) ? primary
              : (isDark ? Colors.white60 : Colors.grey.shade500),
        )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? primary
              : (isDark ? Colors.white60 : Colors.grey.shade400),
          size: 24,
        )),
        elevation: 0,
        height: 72,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.08),
      ),

      // ── FAB ────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: StadiumBorder(),
      ),

      // ── Chips ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor:   isDark ? const Color(0xFF2A2740) : const Color(0xFFF5F3FF),
        selectedColor:     primary.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ── Dialogs ────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF1C1B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
      ),

      // ── Snackbar ───────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2A2740) : const Color(0xFF1A1A2E),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      state: widget.appState,
      child: MaterialApp(
        title: 'Padma Mangal',
        debugShowCheckedModeBanner: false,
        themeMode: widget.appState.themeMode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const AuthGate(),
      ),
    );
  }
}

// ─── InheritedWidget to access AppState anywhere ─────────────────────────────
class AppStateProvider extends InheritedWidget {
  final AppState state;
  const AppStateProvider({super.key, required this.state, required super.child});

  static AppState of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppStateProvider>();
    assert(provider != null, 'No AppStateProvider found in tree');
    return provider!.state;
  }

  @override
  bool updateShouldNotify(AppStateProvider oldWidget) => oldWidget.state != state;
}

// ─── Auth Gate ───────────────────────────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final loggedIn = await _authService.hasSession();
    if (mounted) {
      setState(() {
        _loggedIn = loggedIn;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _loggedIn ? const HomeScreen() : const LoginScreen();
  }
}
