import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shadebox/pages/filmmakinesi_page.dart' as player;

class Film {
  final String title;
  final String posterUrl;
  final String href;
  String? description;
  String? imdbRating;
  List<String>? actors;
  String? trailerUrl;
  String? m3uLink;

  Film({
    required this.title, 
    required this.posterUrl, 
    required this.href,
    this.description,
    this.imdbRating,
    this.actors,
    this.trailerUrl,
    this.m3uLink
  });
}

class Category {
  final String id;
  final String name;
  final String url;

  Category({required this.id, required this.name, required this.url});
}

class FilmmakinesiPage extends StatefulWidget {
  const FilmmakinesiPage({super.key});

  @override
  State<FilmmakinesiPage> createState() => _FilmmakinesiPageState();
}

class CloseLoadExtractor {
  static final RegExp packedExtractRegex = RegExp(
    r"\}\('(.*)',\s*(\d+),\s*(\d+),\s*'(.*?)'\.split\('\|'\)",
    multiLine: true,
    caseSensitive: false,
  );

  static final RegExp unpackReplaceRegex = RegExp(
    r"\b\w+\b",
    multiLine: true,
    caseSensitive: false,
  );

  static String unpack(String scriptBlock) {
    final match = packedExtractRegex.firstMatch(scriptBlock);
    if (match == null) throw Exception("Invalid script block");

    final payload = match.group(1)!;
    final radix = int.parse(match.group(2)!);
    final count = int.parse(match.group(3)!);
    final symtab = match.group(4)!.split('|');

    if (symtab.length != count) {
      throw Exception("Symbol table size mismatch");
    }

    final unbaser = Unbaser(radix);
    return payload.replaceAllMapped(unpackReplaceRegex, (match) {
      final word = match.group(0)!;
      final index = unbaser.unbase(word);
      return symtab[index].isEmpty ? word : symtab[index];
    });
  }
}

class Unbaser {
  final int base;
  late final int selector;
  late final Map<String, int> dict;

  Unbaser(this.base) {
    selector = base > 62 ? 95 : base > 54 ? 62 : base > 52 ? 54 : 52;
    dict = _buildDict();
  }

  static const Map<int, String> ALPHABET = {
    52: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP",
    54: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQR",
    62: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
    95: " !\"#\$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
  };

  Map<String, int> _buildDict() {
    final alphabet = ALPHABET[selector]!;
    final dict = <String, int>{};
    for (var i = 0; i < alphabet.length; i++) {
      dict[alphabet[i]] = i;
    }
    return dict;
  }

  int unbase(String value) {
    if (base >= 2 && base <= 36) {
      return int.tryParse(value, radix: base) ?? 0;
    }

    var result = 0;
    for (var i = 0; i < value.length; i++) {
      result += (dict[value[i]] ?? 0) * math.pow(base, value.length - 1 - i).toInt();
    }
    return result;
  }
}

class _FilmmakinesiPageState extends State<FilmmakinesiPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  List<Film> _films = [];
  List<Film> _filteredFilms = [];
  int _page = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _selectedCategory;

  final List<Category> _categories = [
    Category(id: "all", name: "Son Filmler", url: "/page/"),
    Category(id: "top", name: "Ölmeden İzle", url: "/film-izle/olmeden-izlenmesi-gerekenler/page/"),
    Category(id: "aksiyon", name: "Aksiyon", url: "/film-izle/aksiyon-filmleri-izle/page/"),
    Category(id: "bilimkurgu", name: "Bilim Kurgu", url: "/film-izle/bilim-kurgu-filmi-izle/page/"),
    Category(id: "macera", name: "Macera", url: "/film-izle/macera-filmleri/page/"),
    Category(id: "komedi", name: "Komedi", url: "/film-izle/komedi-filmi-izle/page/"),
    Category(id: "romantik", name: "Romantik", url: "/film-izle/romantik-filmler-izle/page/"),
    Category(id: "belgesel", name: "Belgesel", url: "/film-izle/belgesel/page/"),
    Category(id: "fantastik", name: "Fantastik", url: "/film-izle/fantastik-filmler-izle/page/"),
    Category(id: "polisiye", name: "Polisiye Suç", url: "/film-izle/polisiye-filmleri-izle/page/"),
    Category(id: "korku", name: "Korku", url: "/film-izle/korku-filmleri-izle-hd/page/"),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categories.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFilms(refresh: true);
    });
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 500 && 
        !_isLoadingMore) {
      _loadMoreFilms();
    }
  }

  Future<String?> _getM3uLink(String data) async {
    try {
      debugPrint('Input data: $data');
      
      final firstDecoded = base64.decode(data);
      final firstReversed = String.fromCharCodes(firstDecoded.reversed);
      final secondDecoded = base64.decode(firstReversed);
      final resultString = utf8.decode(secondDecoded);
      
      final parts = resultString.split('|');
      if (parts.length < 2) {
        throw Exception('Invalid format: URL not found in decoded string');
      }
      
      var url = parts[1].trim();
      if (!url.startsWith('http')) {
        throw Exception('Invalid URL format');
      }

      // URL'nin .txt uzantısı varsa m3u8'e çevirelim
      if (url.endsWith('.txt')) {
        url = url.replaceAll('/txt/master.txt', '/master.m3u8');
      }
      
      // URL'nin geçerli olduğunu kontrol edelim
      try {
        final response = await http.head(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://filmmakinesi.de/',
            'Origin': 'https://filmmakinesi.de',
          },
        );
        
        if (response.statusCode != 200) {
          throw Exception('Video URL is not accessible');
        }
      } catch (e) {
        debugPrint('URL check error: $e');
      }

      return url;
    } catch (e) {
      debugPrint('M3U link extraction error: $e');
      return null;
    }
  }

  Future<void> _loadFilms({bool refresh = false}) async {
    if (_isLoading || _isLoadingMore) return;
    
    if (refresh) {
      setState(() {
        _films.clear();
        _filteredFilms.clear();
        _page = 1;
        _isLoading = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final category = _categories.firstWhere((c) => c.id == _selectedCategory);
      final url = 'https://filmmakinesi.de${category.url}$_page';
      
      debugPrint('Loading URL: $url (Page: $_page)');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://filmmakinesi.de/',
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final List<Film> newFilms = [];

        // Film kartlarını doğru selector ile topla
        final articles = category.id == 'all'
            ? document.querySelectorAll('section#film_posts div.tooltip')
            : document.querySelectorAll('section#film_posts article');

        for (var article in articles) {
          final titleElement = category.id == 'all'
              ? article.querySelector('h2 a') ?? article.querySelector('h6 a')
              : article.querySelector('h6 a');
              
          final title = titleElement?.text?.trim() ?? '';
          final href = titleElement?.attributes['href']?.trim() ?? '';
          final posterUrl = article.querySelector('img')?.attributes['data-src']?.trim() ?? 
                           article.querySelector('img')?.attributes['src']?.trim() ?? '';
          
          if (title.isNotEmpty && href.isNotEmpty && posterUrl.isNotEmpty) {
            newFilms.add(Film(title: title, posterUrl: posterUrl, href: href));
          }
        }

        if (mounted && newFilms.isNotEmpty) {
          setState(() {
            if (refresh) {
              _films = newFilms;
            } else {
              _films.addAll(newFilms);
            }
            _filteredFilms = List.from(_films);
            _page++;
            _isLoadingMore = false;
          });
        } else {
          _isLoadingMore = false;
        }
      }
    } catch (e) {
      debugPrint('Film yükleme hatası: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreFilms() async {
    if (!_isLoadingMore) {
      setState(() => _isLoadingMore = true);
      await _loadFilms();
    }
  }

  Future<void> _loadFilmDetail(Film film) async {
    try {
      final response = await http.get(
        Uri.parse(film.href),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://filmmakinesi.de/',
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        // Film detaylarını çek
        film.description = document.querySelector('section#film_single article p')?.text?.trim();
        
        final imdbElement = document.querySelectorAll('dt')
            .firstWhere((e) => e.text.contains('IMDB'), orElse: () => document.createElement('dt'));
        film.imdbRating = imdbElement.nextElementSibling?.text?.trim();
        
        final actorsElement = document.querySelectorAll('dt')
            .firstWhere((e) => e.text.contains('Oyuncular'), orElse: () => document.createElement('dt'));
        film.actors = actorsElement.nextElementSibling?.text?.split(',').map((e) => e.trim()).toList();

        // iframe ve video kaynağını çek
        final iframeElement = document.querySelector('div.player-div iframe');
        final iframeSrc = iframeElement?.attributes['src'] ?? iframeElement?.attributes['data-src'];
        
        if (iframeSrc != null) {
          final iframeResponse = await http.get(
            Uri.parse(iframeSrc),
            headers: {'Referer': film.href},
          );

          if (iframeResponse.statusCode == 200) {
            // JavaScript kodunu çıkar
            final scripts = parser.parse(iframeResponse.body)
                .querySelectorAll('script[type="text/javascript"]');
            
            if (scripts.length > 1) {
              final obfuscatedScript = scripts[1].text.trim();
              try {
                final rawScript = CloseLoadExtractor.unpack(obfuscatedScript);
                final dataMatch = RegExp(r'return result\}var .*?=.*?\("(.*?)"\)')
                    .firstMatch(rawScript);
                
                if (dataMatch != null) {
                  film.m3uLink = await _getM3uLink(dataMatch.group(1)!);
                  debugPrint('Found m3u link: ${film.m3uLink}');
                }
              } catch (e) {
                debugPrint('Script unpack error: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Film detail loading error: $e');
    }
  }

  Future<void> _searchFilms(String query) async {
    if (query.isEmpty) {
      setState(() => _filteredFilms = _films);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('https://filmmakinesi.de/?s=${Uri.encodeComponent(query)}'),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://filmmakinesi.de/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'tr,en-US;q=0.7,en;q=0.3',
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final searchResults = document.querySelectorAll('section#film_posts article');
        
        final searchedFilms = searchResults.map((article) {
          final titleElement = article.querySelector('h6 a');
          final title = titleElement?.text ?? '';
          final href = titleElement?.attributes['href'] ?? '';
          final posterUrl = article.querySelector('img')?.attributes['data-src'] ?? 
                           article.querySelector('img')?.attributes['src'] ?? '';
          
          return Film(title: title, posterUrl: posterUrl, href: href);
        }).where((film) => film.title.isNotEmpty && film.href.isNotEmpty).toList();

        setState(() {
          _filteredFilms = searchedFilms;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Film arama hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  void _handleCategoryChange(String? newValue) {
    if (newValue != null && newValue != _selectedCategory) {
      setState(() {
        _selectedCategory = newValue;
        _searchController.clear();
        _films.clear();
        _filteredFilms.clear();
        _page = 1;
      });
      
      // Kategori değişiminden sonra yeni filmleri yükle
      Future.microtask(() => _loadFilms(refresh: true));
    }
  }

  Future<void> _showMovieDetails(Film film) async {
    try {
      await _loadFilmDetail(film);
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: FractionallySizedBox(
            widthFactor: 0.75,
            heightFactor: 0.85,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 400,
                          pinned: true,
                          flexibleSpace: FlexibleSpaceBar(
                            background: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  film.posterUrl,
                                  fit: BoxFit.cover,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                    ),
                                  ),
                                ),
                                if (film.m3uLink != null)
                                  Center(
                                    child: CircleAvatar(
                                      radius: 35,
                                      backgroundColor: Colors.black45,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.play_arrow,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          showDialog(
                                            context: context,
                                            builder: (context) => VideoPlayerDialog(
                                              videoUrl: film.m3uLink!,
                                              title: film.title,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 20,
                                  bottom: 20,
                                  right: 20,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        film.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (film.imdbRating != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star, size: 16),
                                              const SizedBox(width: 4),
                                              Text(
                                                film.imdbRating!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        if (film.description != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Özet',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    film.description!,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (film.actors != null && film.actors!.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Oyuncular',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: film.actors!.map((actor) => Chip(
                                      label: Text(actor),
                                    )).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Film detay gösterme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Film Ara...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onSubmitted: (value) => _searchFilms(value),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  items: _categories.map((Category category) {
                    return DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    );
                  }).toList(),
                  onChanged: _handleCategoryChange,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading && _filteredFilms.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _filteredFilms.isEmpty
                  ? const Center(child: Text('Film bulunamadı'))
                  : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredFilms.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _filteredFilms.length) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final film = _filteredFilms[index];
                    return Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _showMovieDetails(film),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                child: Image.network(
                                  film.posterUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.error),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                film.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerDialog({
    Key? key,
    required this.videoUrl,
    required this.title,
  }) : super(key: key);

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  Player? _player;
  VideoController? _controller;
  bool _isLoading = true;
  String? _error;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (_disposed) return;

    try {
      setState(() => _isLoading = true);
      
      _player = Player();
      _controller = VideoController(_player!);
      
      var url = widget.videoUrl;
      if (url.endsWith('.txt')) {
        url = url.replaceAll('/txt/master.txt', '/master.m3u8');
      }

      await _player?.open(
        Media(
          url,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://filmmakinesi.de/',
            'Origin': 'https://filmmakinesi.de',
            'Accept': '*/*',
            'Accept-Language': 'tr-TR,tr;q=0.9',
            'Connection': 'keep-alive',
          },
          extras: {
            'http-referrer': 'https://filmmakinesi.de/',
            'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
      );

      if (_disposed) {
        await _cleanupResources();
        return;
      }

      // Video yüklenene kadar bekle
      bool playbackStarted = false;
      await for (final playing in _player!.stream.playing) {
        if (playing) {
          playbackStarted = true;
          break;
        }
        if (_disposed) break;
      }

      if (_disposed) {
        await _cleanupResources();
        return;
      }

      if (!playbackStarted) {
        throw Exception('Video playback failed to start');
      }

      if (mounted && !_disposed) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Player initialization error: $e');
      if (mounted && !_disposed) {
        setState(() {
          _isLoading = false;
          _error = 'Video yüklenirken bir hata oluştu: $e';
        });
      }
    }
  }

  Future<void> _cleanupResources() async {
    try {
      await _player?.dispose();
    } catch (e) {
      debugPrint('Player dispose error: $e');
    }
    _player = null;
    _controller = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cleanupResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _initializePlayer,
                                child: const Text('Tekrar Dene'),
                              ),
                            ],
                          ),
                        )
                      : _controller != null
                          ? Video(
                              controller: _controller!,
                              controls: AdaptiveVideoControls,
                            )
                          : const Center(
                              child: Text(
                                'Video oynatıcı başlatılamadı',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
