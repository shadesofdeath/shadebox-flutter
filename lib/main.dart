import 'dart:ui' show PlatformDispatcher, ImageFilter;
import 'package:ShadeBox/pages/rec_tv_film.dart';
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
import 'package:ShadeBox/pages/rec_tv_series.dart';
import 'package:ShadeBox/pages/rec_tv_live.dart';

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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isMenuExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _menuAnimation;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = const [
    SinewixFilmPage(),
    SinewixDiziPage(),
    SinewixAnimePage(),
    RecTVPage(),
    RecTVSeriesPage(),
    RecTVLivePage(),
    SinewixTVPage(),
  ];

  final List<_MenuItem> _menuItems = [
    _MenuItem('Film', HugeIcons.strokeRoundedVideo01),
    _MenuItem('Dizi', HugeIcons.strokeRoundedVideoReplay),
    _MenuItem('Anime', HugeIcons.strokeRoundedTongue),
    _MenuItem('RecTV Film', HugeIcons.strokeRoundedVideo01),
    _MenuItem('RecTV Dizi', HugeIcons.strokeRoundedVideoReplay),
    _MenuItem('RecTV Canlı', HugeIcons.strokeRoundedTv01),
    _MenuItem('Canlı TV', HugeIcons.strokeRoundedTv01),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _menuAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuExpanded = !_isMenuExpanded;
      if (_isMenuExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  // Tema değişikliğini gösteren snackbar - daha küçük ve ortada
  void _showThemeChangeNotification(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.currentThemeMode == ThemeMode.light
                  ? HugeIcons.strokeRoundedSun02
                  : widget.currentThemeMode == ThemeMode.dark
                      ? HugeIcons.strokeRoundedMoon02
                      : HugeIcons.strokeRoundedSun02,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.only(
          bottom: 20,
          left: MediaQuery.of(context).size.width / 2 - 100,
          right: MediaQuery.of(context).size.width / 2 - 100,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Açık Tema';
      case ThemeMode.dark:
        return 'Koyu Tema';
      case ThemeMode.system:
        return 'Sistem Teması';
    }
  }

  @override
  Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final colorScheme = Theme.of(context).colorScheme;
  
  return Scaffold(
    key: _scaffoldKey,
    body: Row(
      children: [
        // Side Navigation Menu
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: _isMenuExpanded ? 220 : 70,
          color: isDark 
              ? colorScheme.surface.withOpacity(0.8)
              : colorScheme.surfaceVariant.withOpacity(0.8),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Logo and Hamburger
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: _isMenuExpanded 
                        ? MainAxisAlignment.spaceBetween 
                        : MainAxisAlignment.center,
                    children: [
                      if (_isMenuExpanded)
                        Text(
                          'ShadeBox',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          _isMenuExpanded 
                              ? HugeIcons.strokeRoundedMenu01 
                              : HugeIcons.strokeRoundedMenu02,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                        onPressed: _toggleMenu,
                        tooltip: _isMenuExpanded ? 'Menüyü Daralt' : 'Menüyü Genişlet',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1, thickness: 0.5),
                
                // Menu Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) => _buildNavItem(index),
                  ),
                ),
                
                const Divider(height: 1, thickness: 0.5),
                
                // Theme Controls
                _buildThemeControls(),
              ],
            ),
          ),
        ),
        
        // Main Content
        Expanded(
          child: Container(
            color: colorScheme.background,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _pages[_selectedIndex],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildNavItem(int index) {
    final isSelected = _selectedIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? colorScheme.primaryContainer.withOpacity(0.8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Icon(
                  _menuItems[index].icon,
                  size: 20,
                  color: isSelected 
                      ? colorScheme.primary 
                      : colorScheme.onSurfaceVariant.withOpacity(0.8),
                ),
              ),
              if (_isMenuExpanded) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: AnimatedOpacity(
                    opacity: _isMenuExpanded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _menuItems[index].title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected 
                            ? colorScheme.primary 
                            : colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeControls() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isMenuExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Tema',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _isMenuExpanded ? double.infinity : 36,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: _isMenuExpanded 
                  ? MainAxisAlignment.start 
                  : MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      widget.currentThemeMode == ThemeMode.light
                          ? HugeIcons.strokeRoundedSun02
                          : widget.currentThemeMode == ThemeMode.dark
                              ? HugeIcons.strokeRoundedMoon02
                              : HugeIcons.strokeRoundedSun02,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: () {
                      ThemeMode nextMode;
                      if (widget.currentThemeMode == ThemeMode.system) {
                        nextMode = ThemeMode.light;
                      } else if (widget.currentThemeMode == ThemeMode.light) {
                        nextMode = ThemeMode.dark;
                      } else {
                        nextMode = ThemeMode.system;
                      }
                      widget.updateThemeMode(nextMode);
                      _showThemeChangeNotification('${_getThemeModeName(nextMode)} aktif edildi');
                    },
                  ),
                ),
                if (_isMenuExpanded) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        HugeIcons.strokeRoundedColors,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: () => _showColorSchemeSelector(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showColorSchemeSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renk Teması Seçin'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: List.generate(
              20,
              (index) => InkWell(
                onTap: () {
                  widget.updateColorScheme(FlexScheme.values[index]);
                  _showThemeChangeNotification('Yeni renk teması uygulandı');
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: FlexThemeData.light(scheme: FlexScheme.values[index]).primaryColor,
                    borderRadius: BorderRadius.circular(8),
                    border: FlexScheme.values[index] == widget.currentColorScheme
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: FlexScheme.values[index] == widget.currentColorScheme
                      ? const Center(child: Icon(Icons.check, color: Colors.white))
                      : null,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  
  _MenuItem(this.title, this.icon);
}