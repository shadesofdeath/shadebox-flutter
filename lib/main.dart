import 'dart:ui' show PlatformDispatcher, ImageFilter;
import 'package:ShadeBox/pages/rec_tv_page.dart';
import 'package:ShadeBox/pages/sinewix_tv_page.dart';
import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/sinewix_film_page.dart';
import 'pages/sinewix_dizi_page.dart';
import 'pages/sinewix_anime_page.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(1280, 720),
      center: true,
      title: 'ShadeBox',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  FlexScheme _colorScheme = FlexScheme.blueM3;
  bool _isInitialized = true; // Changed to true since we don't need initialization anymore

  @override
  void initState() {
    super.initState();
    _loadThemePreferences();
  }

  Future<void> _loadThemePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 0];
      _colorScheme = FlexScheme.values[prefs.getInt('colorScheme') ?? 0];
    });
  }

  Future<void> _saveThemePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _themeMode.index);
    await prefs.setInt('colorScheme', _colorScheme.index);
  }

  void _updateSystemChrome(ThemeMode mode, BuildContext? context) {
    final isDark = mode == ThemeMode.dark || 
      (mode == ThemeMode.system && 
        (context != null ? Theme.of(context).brightness == Brightness.dark : false));
        
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ));
  }

  void updateThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
      _updateSystemChrome(mode, context);
      _saveThemePreferences();
    });
  }

  void updateColorScheme(FlexScheme scheme) {
    setState(() {
      _colorScheme = scheme;
      _saveThemePreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    _updateSystemChrome(_themeMode, context);

    return MaterialApp(
      title: 'ShadeBox',
      themeMode: _themeMode,
      darkTheme: FlexThemeData.dark(
        scheme: _colorScheme,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 13,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          defaultRadius: 12.0,
          elevatedButtonSchemeColor: SchemeColor.primary,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        fontFamily: GoogleFonts.roboto().fontFamily,
      ),
      theme: FlexThemeData.light(
        scheme: _colorScheme,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: const FlexSubThemesData(
          defaultRadius: 12.0,
          elevatedButtonSchemeColor: SchemeColor.primary,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        fontFamily: GoogleFonts.roboto().fontFamily,
      ),
      home: HomePage(
        updateThemeMode: updateThemeMode,
        updateColorScheme: updateColorScheme,
        currentThemeMode: _themeMode,
        currentColorScheme: _colorScheme,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Function(ThemeMode) updateThemeMode;
  final Function(FlexScheme) updateColorScheme;
  final ThemeMode currentThemeMode;
  final FlexScheme currentColorScheme;

  const HomePage({
    super.key,
    required this.updateThemeMode,
    required this.updateColorScheme,
    required this.currentThemeMode,
    required this.currentColorScheme,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    SinewixFilmPage(),
    SinewixDiziPage(),
    SinewixAnimePage(),
    SinewixTVPage(),
    RecTVPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'ShadeBox',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 32),
                      ...List.generate(
                        _pages.length,
                        (index) => _buildTabItem(
                          index: index,
                          title: ['Film', 'Dizi', 'Anime', 'Canlı TV', 'RecTV'][index], // Add RecTV title
                          icon: [
                            HugeIcons.strokeRoundedVideo01, 
                            HugeIcons.strokeRoundedVideoReplay,
                            HugeIcons.strokeRoundedTongue,
                            HugeIcons.strokeRoundedPlayCircle, // Add new icon
                            HugeIcons.strokeRoundedTv01,
                            HugeIcons.strokeRoundedPlayCircle, // Add RecTV icon
                          ][index],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      PopupMenuButton<FlexScheme>(
                        tooltip: 'Renk Teması',
                        icon: const Icon(HugeIcons.strokeRoundedColors),
                        initialValue: widget.currentColorScheme,
                        onSelected: widget.updateColorScheme,
                        itemBuilder: (context) => FlexScheme.values
                            .take(20)
                            .map((scheme) => PopupMenuItem(
                                  value: scheme,
                                  child: Text(scheme.toString().split('.').last),
                                ))
                            .toList(),
                      ),
                      PopupMenuButton<ThemeMode>(
                        tooltip: 'Tema Modu',
                        icon: Icon(widget.currentThemeMode == ThemeMode.light
                            ? HugeIcons.strokeRoundedSun02
                            : widget.currentThemeMode == ThemeMode.dark
                                ? HugeIcons.strokeRoundedMoon02
                                : HugeIcons.strokeRoundedSun02),
                        initialValue: widget.currentThemeMode,
                        onSelected: widget.updateThemeMode,
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: ThemeMode.system,
                            child: Text('Otomatik'),
                          ),
                          const PopupMenuItem(
                            value: ThemeMode.light,
                            child: Text('Açık Tema'),
                          ),
                          const PopupMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Koyu Tema'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _pages[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _selectedIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

