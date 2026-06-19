import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  // ── Keys ──────────────────────────────────────────────────────────
  static const _kThemeMode       = 'theme_mode';
  static const _kChatBg          = 'chat_bg';
  static const _kFontScale       = 'font_scale';
  static const _kCompactBubbles  = 'compact_bubbles';
  static const _kSendOnEnter     = 'send_on_enter';
  static const _kShowTimestamps  = 'show_timestamps';
  static const _kShowAvatars     = 'show_avatars';

  // ── State ─────────────────────────────────────────────────────────
  ThemeMode _themeMode      = ThemeMode.system;
  int       _chatBgIndex    = 0;          // 0-5 preset backgrounds
  double    _fontScale      = 1.0;        // 0.85 / 1.0 / 1.15 / 1.3
  bool      _compactBubbles = false;
  bool      _sendOnEnter    = true;
  bool      _showTimestamps = true;
  bool      _showAvatars    = true;

  // ── Getters ───────────────────────────────────────────────────────
  ThemeMode get themeMode      => _themeMode;
  int       get chatBgIndex    => _chatBgIndex;
  double    get fontScale      => _fontScale;
  bool      get compactBubbles => _compactBubbles;
  bool      get sendOnEnter    => _sendOnEnter;
  bool      get showTimestamps => _showTimestamps;
  bool      get showAvatars    => _showAvatars;

  // ── Init ──────────────────────────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode      = ThemeMode.values[prefs.getInt(_kThemeMode) ?? 0];
    _chatBgIndex    = prefs.getInt(_kChatBg)         ?? 0;
    _fontScale      = prefs.getDouble(_kFontScale)    ?? 1.0;
    _compactBubbles = prefs.getBool(_kCompactBubbles) ?? false;
    _sendOnEnter    = prefs.getBool(_kSendOnEnter)    ?? true;
    _showTimestamps = prefs.getBool(_kShowTimestamps) ?? true;
    _showAvatars    = prefs.getBool(_kShowAvatars)    ?? true;
    notifyListeners();
  }

  // ── Setters ───────────────────────────────────────────────────────
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, mode.index);
  }

  Future<void> setChatBgIndex(int idx) async {
    _chatBgIndex = idx;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kChatBg, idx);
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontScale, scale);
  }

  Future<void> setCompactBubbles(bool v) async {
    _compactBubbles = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCompactBubbles, v);
  }

  Future<void> setSendOnEnter(bool v) async {
    _sendOnEnter = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSendOnEnter, v);
  }

  Future<void> setShowTimestamps(bool v) async {
    _showTimestamps = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowTimestamps, v);
  }

  Future<void> setShowAvatars(bool v) async {
    _showAvatars = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowAvatars, v);
  }

  // ── Chat background presets ───────────────────────────────────────
  static const List<List<Color>> chatBgPresets = [
    [Color(0xFFF0EAF8), Color(0xFFE8F4FD)],          // 0 – soft lavender-blue (default)
    [Color(0xFFF5F5F5), Color(0xFFEFEFEF)],          // 1 – plain light grey
    [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],          // 2 – fresh mint
    [Color(0xFFFFF3E0), Color(0xFFFFF8E1)],          // 3 – warm amber
    [Color(0xFF1A1A2E), Color(0xFF16213E)],          // 4 – midnight dark
    [Color(0xFF0F2027), Color(0xFF203A43)],          // 5 – deep ocean dark
  ];

  static const List<String> chatBgLabels = [
    'Lavender',
    'Plain',
    'Mint',
    'Amber',
    'Midnight',
    'Ocean',
  ];
}
