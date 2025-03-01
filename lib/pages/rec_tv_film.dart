import 'dart:async';
import 'package:ShadeBox/pages/download_manager.dart'; // Download manager için import eklendi
import 'package:file_picker/file_picker.dart'; // FilePicker için import eklendi
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/video_player_dialog.dart';
import 'package:ShadeBox/pages/downloads_page.dart';

class RecTVPage extends StatefulWidget {
  const RecTVPage({super.key});

  @override
  State<RecTVPage> createState() => _RecTVPageState();
}

// Update Movie class to match the RecTV API structure
class Movie {
  final int id;
  final String title;
  final String image;
  final String? type;
  final List<Source> sources;
  final double? rating;
  final String? description;
  final int? year;
  final List<Genre>? genres;
  final String? label;

  Movie({
    required this.id,
    required this.title,
    required this.image,
    this.type,
    required this.sources,
    this.rating,
    this.description,
    this.year,
    this.genres,
    this.label,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'],
      image: json['image'],
      type: json['type'],
      sources: (json['sources'] as List? ?? []).map((s) => Source.fromJson(s)).toList(),
      rating: (json['rating'] ?? 0.0).toDouble(),
      description: json['description'],
      year: json['year'],
      genres: (json['genres'] as List?)?.map((g) => Genre.fromJson(g)).toList(),
      label: json['label'],
    );
  }
}

// Add Genre class
class Genre {
  final int id;
  final String title;

  Genre({required this.id, required this.title});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'],
      title: json['title'],
    );
  }
}

class Source {
  final String url;
  final String type;

  Source({required this.url, required this.type});

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      url: json['url'],
      type: json['type'],
    );
  }
}

// MovieDetail sınıfını RecTV'ye uygun şekilde güncelle
class MovieDetail {
  final int id;
  final String title;
  final String image;
  final String? type;
  final List<Source> sources;
  final double? rating;
  final String? description;
  final int? year;
  final List<Genre>? genres;

  MovieDetail({
    required this.id,
    required this.title,
    required this.image,
    this.type,
    required this.sources,
    this.rating,
    this.description,
    this.year,
    this.genres,
  });

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    return MovieDetail(
      id: json['id'],
      title: json['title'],
      image: json['image'],
      type: json['type'],
      sources: (json['sources'] as List? ?? []).map((s) => Source.fromJson(s)).toList(),
      rating: (json['rating'] ?? 0.0).toDouble(),
      description: json['description'],
      year: json['year'],
      genres: (json['genres'] as List?)?.map((g) => Genre.fromJson(g)).toList(),
    );
  }
}

class _RecTVPageState extends State<RecTVPage> {
  String _mainUrl = "https://a.prectv35.sbs"; // Default value
  String _swKey = "4F5A9C3D9A86FA54EACEDDD635185/c3c5bd17-e37b-4b94-a944-8a3688a30452"; // Default value
  
  List<Movie> _movies = [];
  bool _isLoading = false; // false olarak değiştirildi
  String _selectedCategory = "0"; // Default category
  int _currentPage = 0;
  Timer? _debounce; // Debounce için timer ekle
  
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final Map<String, String> _categories = {
    "0": "Son Filmler",
    "14": "Aile",
    "1": "Aksiyon",
    "13": "Animasyon",
    "19": "Belgesel",
    "4": "Bilim Kurgu",
    "2": "Dram",
    "10": "Fantastik",
    "3": "Komedi",
    "8": "Korku",
    "17": "Macera",
    "5": "Romantik",
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchConfig(); // Config'i çek
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 1000) {
      _loadMore();
    }
  }

  Future<void> _fetchMovies({bool refresh = false}) async {
    if (_isLoading) return; // Önce loading kontrolü

    setState(() => _isLoading = true);

    if (refresh) {
      setState(() {
        _currentPage = 0;
        _movies.clear();
      });
    }

    try {
      final response = await http.get(
        Uri.parse('$_mainUrl/api/movie/by/filtres/$_selectedCategory/created/$_currentPage/$_swKey/'),
        headers: {'user-agent': 'okhttp/4.12.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Movie> movies = data.map((item) => Movie.fromJson(item)).toList();

        setState(() {
          if (refresh) {
            _movies = movies;
          } else {
            _movies.addAll(movies);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching movies: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    _currentPage++;
    await _fetchMovies();
  }

  Future<void> _searchMovies(String query) async {
    // Önceki timer'ı iptal et
    _debounce?.cancel();
    
    // Yeni timer başlat
    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;
      
      setState(() => _isLoading = true);

      try {
        final response = await http.get(
          Uri.parse('$_mainUrl/api/search/$query/$_swKey/'),
          headers: {'user-agent': 'okhttp/4.12.0'},
        );

        if (response.statusCode == 200 && mounted) {
          final data = json.decode(response.body);
          final List<Movie> searchResults = [];
          
          if (data['posters'] != null) {
            searchResults.addAll(
              (data['posters'] as List).map((item) => Movie.fromJson(item))
            );
          }

          setState(() {
            _movies = searchResults;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error searching movies: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<MovieDetail?> _getMovieDetails(Movie movie) async {
    try {
      final response = await http.get(
        Uri.parse('$_mainUrl/api/movie/${movie.id}/$_swKey/'),
        headers: {'user-agent': 'okhttp/4.12.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MovieDetail.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching movie details: $e');
      return null;
    }
  }

  // İndirme işlemi için yeni method
  Future<void> _handleDownload(String videoUrl, String title) async {
    try {
      debugPrint('Starting download for URL: $videoUrl');
      
      // İlk olarak HEAD request ile video URL'sini kontrol et
      final headResponse = await http.head(
        Uri.parse(videoUrl),
        headers: {
          'User-Agent': 'googleusercontent',
          'Referer': 'https://twitter.com/',
          'Range': 'bytes=0-',
        },
      );

      String finalUrl = videoUrl;
      if (headResponse.isRedirect && headResponse.headers['location'] != null) {
        finalUrl = headResponse.headers['location']!;
        debugPrint('Redirected to: $finalUrl');
      }

      // Dosya uzantısını belirle
      String extension = 'mp4';
      if (videoUrl.toLowerCase().contains('m3u8')) {
        extension = 'ts';
      }

      final saveLocation = await FilePicker.platform.saveFile(
        dialogTitle: 'Kayıt Konumu Seç',
        fileName: '$title.$extension',
      );

      if (saveLocation != null && mounted) {
        debugPrint('Save location: $saveLocation');
        debugPrint('Final URL for download: $finalUrl');
        
        // İndirme işlemini başlat
        DownloadManager().startDownload(
          finalUrl,
          title,
          saveLocation,
        );

        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const DownloadsPage(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İndirme başlatılırken hata oluştu: $e')),
        );
      }
    }
  }

  // _RecTVPageState sınıfı içinde _showMovieDetails metodunu güncelle
  Future<void> _showMovieDetails(Movie movie) async {
    debugPrint('Movie ID: ${movie.id}'); // Debug için
    
    if (!mounted) return;

    // Mevcut movie nesnesini kullanalım, API çağrısı yapmadan
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: GestureDetector(
            onTap: () {}, // Boş gesture detector arkaya tıklamayı engeller
            child: AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: EdgeInsets.zero,
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.75,
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Film Afişi
                            Stack(
                              children: [
                                Image.network(
                                  movie.image,
                                  width: double.infinity,
                                  height: 400,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => 
                                    Container(
                                      color: Colors.grey[900],
                                      child: const Icon(
                                        HugeIcons.strokeRoundedImageNotFound01,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    ),
                                ),
                                // Gradient overlay
                                Positioned.fill(
                                  child: Container(
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
                                ),
                                // Kontrol butonları
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ),
                                if (movie.sources.isNotEmpty)
                                  Positioned.fill(
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // İzle butonu
                                          CircleAvatar(
                                            radius: 35,
                                            backgroundColor: Colors.black45,
                                            child: IconButton(
                                              icon: const Icon(
                                                HugeIcons.strokeRoundedPlay,
                                                size: 40,
                                                color: Colors.white,
                                              ),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => VideoPlayerDialog(
                                                    videoUrl: movie.sources.first.url,
                                                    title: movie.title,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // İndir butonu
                                          CircleAvatar(
                                            radius: 35,
                                            backgroundColor: Colors.black45,
                                            child: IconButton(
                                              icon: const Icon(
                                                HugeIcons.strokeRoundedDownload05,
                                                size: 40,
                                                color: Colors.white,
                                              ),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _handleDownload(
                                                  movie.sources.first.url,
                                                  movie.title,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Film başlığı ve bilgileri
                                Positioned(
                                  left: 20,
                                  bottom: 20,
                                  right: 20,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        movie.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (movie.rating != null || movie.year != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            if (movie.rating != null)
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
                                                      movie.rating!.toStringAsFixed(1),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (movie.year != null) ...[
                                              const SizedBox(width: 12),
                                              Text(
                                                movie.year.toString(),
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Film açıklaması
                            if (movie.description != null)
                              Padding(
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
                                      movie.description!,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    if (movie.genres != null) ...[
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: movie.genres!.map((genre) {
                                          return Chip(label: Text(genre.title));
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchConfig() async {
    try {
      final response = await http.get(
        Uri.parse('https://raw.githubusercontent.com/keyiflerolsun/Kekik-cloudstream/refs/heads/master/RecTV/src/main/kotlin/com/keyiflerolsun/RecTV.kt'),
        headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      if (response.statusCode == 200) {
        final content = response.body;
        debugPrint('Raw content: $content'); // Debug için içeriği görelim
        
        // Regular expression to extract mainUrl and swKey
        final RegExp mainUrlRegex = RegExp(r'mainUrl\s*=\s*"([^"]+)"');
        final RegExp swKeyRegex = RegExp(r'swKey\s*=\s*"([^"]+)"');
        
        final mainUrlMatch = mainUrlRegex.firstMatch(content);
        final swKeyMatch = swKeyRegex.firstMatch(content);
        
        // Yeni değerleri geçici değişkenlerde tutalım
        String? newMainUrl;
        String? newSwKey;
        
        if (mainUrlMatch != null && mainUrlMatch.group(1) != null) {
          newMainUrl = mainUrlMatch.group(1)!;
          debugPrint('Found mainUrl: $newMainUrl');
        }
        
        if (swKeyMatch != null && swKeyMatch.group(1) != null) {
          newSwKey = swKeyMatch.group(1)!;
          debugPrint('Found swKey: $newSwKey');
        }
        
        // Eğer her iki değer de başarıyla alındıysa güncelle
        if (newMainUrl != null && newSwKey != null) {
          bool urlChanged = _mainUrl != newMainUrl;
          
          setState(() {
            _mainUrl = newMainUrl!;
            _swKey = newSwKey!;
          });
          
          // URL değiştiyse bağlantıyı test et
          if (urlChanged) {
            try {
              final testResponse = await http.get(
                Uri.parse('$_mainUrl/api/movie/by/filtres/0/created/0/$_swKey/'),
                headers: {'user-agent': 'okhttp/4.12.0'},
              ).timeout(const Duration(seconds: 5));
              
              if (testResponse.statusCode != 200) {
                throw Exception('Invalid response from new URL');
              }
            } catch (e) {
              debugPrint('New URL test failed: $e');
              // URL test başarısız olursa eski değere geri dön
              setState(() {
                _mainUrl = "https://m.prectv37.sbs";
              });
            }
          }
          
          // Filmleri çek
          _fetchMovies(refresh: true);
        }
      }
    } catch (e) {
      debugPrint('Error fetching config: $e');
      // Hata durumunda varsayılan değeri kullan
      setState(() {
        _mainUrl = "https://m.prectv37.sbs";
      });
      _fetchMovies(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Column yerine Scaffold kullan
      body: Column(
        children: [
          // Search and category selection
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (query) {
                      if (query.length >= 3) {
                        _searchMovies(query);
                      } else if (query.isEmpty) {
                        _fetchMovies(refresh: true);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Film Ara...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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
                    ),
                    items: _categories.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                          _fetchMovies(refresh: true);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Movie grid
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: _movies.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _movies.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final movie = _movies[index];
                return _buildMovieCard(movie);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DownloadsPage()),
          );
        },
        child: const Icon(HugeIcons.strokeRoundedDownload05),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Film kartı widget'ını güncelle
  Widget _buildMovieCard(Movie movie) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        onTap: () => _showMovieDetails(movie),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    movie.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                      const Icon(HugeIcons.strokeRoundedImageNotFound01),
                  ),
                  if (movie.rating != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              movie.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                movie.title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
