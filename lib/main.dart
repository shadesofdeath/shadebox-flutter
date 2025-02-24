import 'package:flutter/material.dart';
import 'pages/sinewix_film_page.dart';
import 'pages/sinewix_dizi_page.dart';
import 'pages/sinewix_anime_page.dart';
import 'pages/hdfilmcehennemi_page.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  MediaKit.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinewix',
      themeMode: ThemeMode.system,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isExtended = true;

  final List<Widget> _pages = const [
    SinewixFilmPage(),
    SinewixDiziPage(),
    SinewixAnimePage(),
    HDFilmCehennemiFilmPage(), // Sınıf adı düzeltildi
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: _isExtended,
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            leading: IconButton(
              icon: AnimatedCrossFade(
                firstChild: const Icon(Icons.menu_rounded),
                secondChild: const Icon(Icons.menu_rounded),
                crossFadeState: _isExtended 
                    ? CrossFadeState.showFirst 
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
              ),
              onPressed: () {
                setState(() {
                  _isExtended = !_isExtended;
                });
              },
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.movie),
                selectedIcon: Icon(Icons.movie),
                label: Text('Sinewix Film'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.movie),
                selectedIcon: Icon(Icons.movie),
                label: Text('Sinewix Dizi'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.movie),
                selectedIcon: Icon(Icons.movie),
                label: Text('Sinewix Anime'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.movie),
                selectedIcon: Icon(Icons.movie),
                label: Text('HD Film Cehennemi'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
