import 'dart:math';
import 'dart:typed_data';
import 'package:ShadeBox/pages/download_manager.dart';
import 'package:ShadeBox/pages/downloads_page.dart';
import 'package:ShadeBox/utils/mediafire_extractor.dart';
import 'package:ShadeBox/widgets/video_player_dialog.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; 
import 'package:http/http.dart' as http;
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:dio/dio.dart';

class Movie {
  final int id;
  final String title;
  final String posterPath;
  final String type;
  final double voteAverage;

  Movie({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.type,
    required this.voteAverage,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'] ?? json['name'] ?? '',
      posterPath: json['poster_path'] ?? '',
      type: json['type'] ?? 'movie',
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster_path': posterPath,
      'type': type,
      'vote_average': voteAverage,
    };
  }
}

class MovieDetail {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double voteAverage;
  final int voteCount;
  final String releaseDate;
  final String runtime;
  final List<Cast> cast;
  final List<String> genres;
  final String? imdbExternalId;
  final String? previewPath;
  final List<VideoLink> videos;
  final String backdropPathTv;
  final int popularity;
  final bool enableStream;
  final bool enableMediaDownload;

  MovieDetail({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.voteCount,
    required this.releaseDate,
    required this.runtime,
    required this.cast,
    required this.genres,
    this.imdbExternalId,
    this.previewPath,
    required this.videos,
    required this.backdropPathTv,
    required this.popularity,
    required this.enableStream,
    required this.enableMediaDownload,
  });

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    String backdropPathTv = json['backdrop_path_tv'] ?? '';
    // URL'in geçerli olup olmadığını kontrol et
    if (!backdropPathTv.startsWith('http')) {
      backdropPathTv = ''; // Geçersiz URL ise boş string ata
    }

    return MovieDetail(
      id: json['id'],
      title: json['title'],
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      releaseDate: json['release_date'] ?? '',
      runtime: json['runtime']?.toString() ?? '',
      cast: (json['casterslist'] as List? ?? [])
          .take(10)
          .map((cast) => Cast.fromJson(cast))
          .toList(),
      genres: (json['genres'] as List? ?? [])
          .map((genre) => genre['name'].toString())
          .toList(),
      imdbExternalId: json['imdb_external_id'],
      previewPath: json['preview_path'],
      videos: (json['videos'] as List? ?? [])
          .map((video) => VideoLink.fromJson(video))
          .toList(),
      backdropPathTv: backdropPathTv,
      popularity: (json['popularity'] ?? 0.0).toInt(),
      enableStream: json['enable_stream'] == 1,
      enableMediaDownload: json['enable_media_download'] == 1,
    );
  }
}

class VideoLink {
  final String server;
  final String link;
  final String lang;
  final bool hd;

  VideoLink({
    required this.server,
    required this.link,
    required this.lang,
    required this.hd,
  });

  factory VideoLink.fromJson(Map<String, dynamic> json) {
    return VideoLink(
      server: json['server'] ?? '',
      link: json['link'] ?? '',
      lang: json['lang'] ?? '',
      hd: json['hd'] == 1,
    );
  }
}

class Cast {
  final String name;
  final String character;
  final String? profilePath;

  Cast({
    required this.name,
    required this.character,
    this.profilePath,
  });

  factory Cast.fromJson(Map<String, dynamic> json) {
    return Cast(
      name: json['name'] ?? '',
      character: json['character'] ?? '',
      profilePath: json['profile_path'],
    );
  }
}

class Category {
  final String id;
  final String name;
  final String url;

  Category({required this.id, required this.name, required this.url});
}

class SinewixFilmPage extends StatefulWidget {
  const SinewixFilmPage({super.key});

  @override
  State<SinewixFilmPage> createState() => _SinewixFilmPageState();
}

class _SinewixFilmPageState extends State<SinewixFilmPage> with AutomaticKeepAliveClientMixin {
  final String _mainUrl = "https://ythls.kekikakademi.org";
  List<Movie> _movies = [];
  List<Movie> _filteredMovies = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  String? _selectedCategory;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final ImageCache imageCache = PaintingBinding.instance.imageCache;
  final PageController _recentMoviesController = PageController();
  List<Movie> _recentlyWatched = [];
  Timer? _autoScrollTimer;
  int _currentRecentPage = 0;

  // Movie detail cache'i ekle
  final Map<int, MovieDetail> _movieDetailCache = {};
  
  // Image provider cache'i ekle
  final Map<String, ImageProvider> _imageCache = {};

  final List<Category> _categories = [
    Category(id: "all", name: "Tüm Filmler", url: "/sinewix/movies"),
    Category(id: "10751", name: "Aile", url: "/sinewix/movies/10751"),
    Category(id: "28", name: "Aksiyon", url: "/sinewix/movies/28"),
    Category(id: "16", name: "Animasyon", url: "/sinewix/movies/16"),
    Category(id: "99", name: "Belgesel", url: "/sinewix/movies/99"),
    Category(id: "878", name: "Bilim-Kurgu", url: "/sinewix/movies/878"),
    Category(id: "18", name: "Dram", url: "/sinewix/movies/18"),
    Category(id: "14", name: "Fantastik", url: "/sinewix/movies/14"),
    Category(id: "53", name: "Gerilim", url: "/sinewix/movies/53"),
    Category(id: "27", name: "Korku", url: "/sinewix/movies/27"),
    Category(id: "35", name: "Komedi", url: "/sinewix/movies/35"),
  ];

  @override
  bool get wantKeepAlive => true; // Side menu'den dönüşte state'i koru

  @override
  void initState() {
    super.initState();
    // Görüntü önbellek limitlerini ayarla
    PaintingBinding.instance.imageCache.maximumSize = 200; // Arttırıldı
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB'a çıkarıldı
    
    _selectedCategory = _categories.first.id;
    _scrollController.addListener(_scrollListener);
    _fetchMovies();
    _loadRecentlyWatched();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_recentlyWatched.isNotEmpty && mounted) {
        final pageCount = (_recentlyWatched.length / 8).ceil();
        final nextPage = (_currentRecentPage + 1) % pageCount;
        
        _recentMoviesController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadRecentlyWatched() async {
    final prefs = await SharedPreferences.getInstance();
    final recentMoviesJson = prefs.getStringList('recent_movies') ?? [];
    setState(() {
      _recentlyWatched = recentMoviesJson
          .map((json) => Movie.fromJson(jsonDecode(json)))
          .toList();
    });
  }

  Future<void> _saveRecentMovie(Movie movie) async {
    if (_recentlyWatched.any((m) => m.id == movie.id)) return;

    final prefs = await SharedPreferences.getInstance();
    _recentlyWatched.insert(0, movie);
    if (_recentlyWatched.length > 20) {
      _recentlyWatched.removeLast();
    }

    await prefs.setStringList(
      'recent_movies',
      _recentlyWatched.map((m) => jsonEncode(m.toJson())).toList(),
    );

    setState(() {});
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 1000) {
      if (!_isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _fetchMovies({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _movies.clear();
      imageCache.clear();
      imageCache.clearLiveImages();
    }

    setState(() => _isLoading = true);

    try {
      final category = _categories.firstWhere((c) => c.id == _selectedCategory);
      
      // İlk açılışta 3 sayfa çek
      if (_movies.isEmpty) {
        final futures = [
          http.get(
            Uri.parse('$_mainUrl${category.url}/1'),
            headers: {'Accept-Charset': 'utf-8'},
          ),
          http.get(
            Uri.parse('$_mainUrl${category.url}/2'),
            headers: {'Accept-Charset': 'utf-8'},
          ),
          http.get(
            Uri.parse('$_mainUrl${category.url}/3'),
            headers: {'Accept-Charset': 'utf-8'},
          ),
        ];

        final responses = await Future.wait(futures);
        List<Movie> allMovies = [];

        for (var response in responses) {
          if (response.statusCode == 200) {
            final data = json.decode(utf8.decode(response.bodyBytes));
            allMovies.addAll(
              (data['data'] as List).map((movieJson) => Movie.fromJson(movieJson))
            );
          }
        }

        setState(() {
          _movies = allMovies;
          _filteredMovies = allMovies;
          _isLoading = false;
          _currentPage = 3; // Sonraki sayfa için 3'ten başla
        });
      } else {
        // Normal sayfa yükleme
        final response = await http.get(
          Uri.parse('$_mainUrl${category.url}/$_currentPage'),
          headers: {'Accept-Charset': 'utf-8'},  // Add UTF-8 header
        );

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));  // Use utf8.decode
          final List<Movie> movies = (data['data'] as List)
              .map((movieJson) => Movie.fromJson(movieJson))
              .toList();

          setState(() {
            if (refresh) {
              _movies = movies;
            } else {
              _movies.addAll(movies);
            }
            _filteredMovies = _movies;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error fetching movies: $e');
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _fetchMovies();
    setState(() => _isLoadingMore = false);
  }

  Future<void> _searchMovies(String query) async {
    if (query.isEmpty) {
      setState(() => _filteredMovies = _movies);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$_mainUrl/sinewix/search/$query'),
        headers: {'Accept-Charset': 'utf-8'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final searchResults = (data['search'] as List)
            .where((item) => item['type'] == 'movie')
            .map((movieJson) => Movie.fromJson(movieJson))
            .toList();

        setState(() {
          _filteredMovies = searchResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching movies: $e');
      setState(() => _isLoading = false);
    }
  }

  // Optimize edilmiş image provider getter'ı
  ImageProvider _getOptimizedImageProvider(String imageUrl) {
    if (_imageCache.containsKey(imageUrl)) {
      return _imageCache[imageUrl]!;
    }
    
    final provider = NetworkImage(
      imageUrl,
      headers: const {'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8'},
    );
    
    _imageCache[imageUrl] = provider;
    return provider;
  }

  // Movie detail fetch işlemini optimize et
  Future<void> _showMovieDetails(Movie movie) async {
    setState(() => _isLoading = true);
    
    try {
      // Cache'den kontrol et
      if (_movieDetailCache.containsKey(movie.id)) {
        if (!mounted) return;
        _showMovieDetailDialog(_movieDetailCache[movie.id]!, movie);
        return;
      }

      // ... existing fetch code ...

      final response = await http.get(
        Uri.parse('$_mainUrl/sinewix/movie/${movie.id}'),
        headers: {'Accept-Charset': 'utf-8'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final movieDetail = MovieDetail.fromJson(data);
        
        // Cache'e ekle
        _movieDetailCache[movie.id] = movieDetail;

        if (!mounted) return;
        _showMovieDetailDialog(movieDetail, movie);
      }
    } catch (e) {
      debugPrint('Error fetching movie details: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Movie detail dialog'unu ayrı bir metoda taşı
  void _showMovieDetailDialog(MovieDetail movieDetail, Movie movie) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: GestureDetector(
          onTap: () {}, // Boş gesture detector arkaya tıklamayı engeller
          child: Dialog(
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
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: movieDetail.backdropPathTv.isNotEmpty
                                        ? Image.network(
                                            movieDetail.backdropPathTv,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey[900],
                                              child: const Center(
                                                child: Icon(
                                                  HugeIcons.strokeRoundedImageNotFound01,
                                                  size: 50,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey[900],
                                            child: const Center(
                                              child: Icon(
                                                HugeIcons.strokeRoundedImageNotFound01,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
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
                                  Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
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
                                              // Film izlendiğinde son izlenenlere ekle
                                              _saveRecentMovie(movie);
                                              final videoUrl = movieDetail.videos.first.link;
                                              showDialog(
                                                context: context,
                                                builder: (context) => VideoPlayerDialog(
                                                  videoUrl: videoUrl,
                                                  title: movieDetail.title,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 16),
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
                                              final videoUrl = movieDetail.videos.first.link;
                                              final title = movieDetail.title;
                                              Navigator.pop(context); // Dialog'u kapat
                                              _handleDownload(videoUrl, title); // İndirme işlemini başlat
                                            },
                                          ),
                                        ),
                                      ],
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
                                          movieDetail.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
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
                                                children: [
                                                  const Icon(HugeIcons.strokeRoundedStar, size: 16),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    movieDetail.voteAverage.toStringAsFixed(1),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '${movieDetail.runtime} dk',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              movieDetail.releaseDate,
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ],
                                        ),
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
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (movieDetail.genres.isNotEmpty) ...[
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: movieDetail.genres.map((genre) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            genre,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                  Text(
                                    'Özet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    movieDetail.overview,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 24),
                                  if (movieDetail.cast.isNotEmpty) ...[
                                    Text(
                                      'Oyuncular',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 150, // Yüksekliği artırdık
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: movieDetail.cast.length,
                                        itemBuilder: (context, index) {
                                          final cast = movieDetail.cast[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 16),
                                            child: SizedBox(
                                              width: 100,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 80,
                                                    height: 80,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(0.2),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: CircleAvatar(
                                                      backgroundImage: cast.profilePath != null
                                                          ? NetworkImage(cast.profilePath!)
                                                          : null,
                                                      child: cast.profilePath == null
                                                          ? const Icon(HugeIcons.strokeRoundedUser, size: 40)
                                                          : null,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    cast.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w500,
                                                      fontSize: 12,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    cast.character,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(fontSize: 11),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
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
        ),
      ),
    );
  }

  Widget _buildRecentlyWatchedSection() {
    if (_recentlyWatched.isEmpty) return const SizedBox.shrink();

    final int itemsPerPage = 8;
    final int pageCount = (_recentlyWatched.length / itemsPerPage).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min, // Ekledik
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 16, bottom: 8), // top padding ekledik
          child: Text(
            'Son İzlenenler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 240, // Yüksekliği biraz daha azalttık
          child: PageView.builder(
            controller: _recentMoviesController,
            onPageChanged: (page) {
              setState(() => _currentRecentPage = page);
            },
            itemCount: pageCount,
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * itemsPerPage;
              final endIndex = min(startIndex + itemsPerPage, _recentlyWatched.length);
              final pageMovies = _recentlyWatched.sublist(startIndex, endIndex);

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12, // Spacing'i azalttık
                ),
                itemCount: pageMovies.length,
                itemBuilder: (context, index) {
                  final movie = pageMovies[index];
                  return _buildMovieCard(movie);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Image widget'ını optimize et
  Widget _buildOptimizedImage(String imageUrl) {
    return Image(
      image: _getOptimizedImageProvider(imageUrl),
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: frame != null
              ? child
              : Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[900],
        child: const Icon(
          Icons.error_outline,
          color: Colors.white54,
        ),
      ),
      filterQuality: FilterQuality.medium,
    );
  }

  Widget _buildMovieCard(Movie movie) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
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
                  _buildOptimizedImage(movie.posterPath),
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
                            movie.voteAverage.toStringAsFixed(1),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Column(
        children: [
          // Arama ve kategori seçimi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (query) {
                        if (query.length >= 3) {
                          _searchMovies(query);
                        } else if (query.isEmpty) {
                          setState(() => _filteredMovies = _movies);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Film Ara... (En az 3 karakter)',
                        hintStyle: const TextStyle(fontSize: 13), // Font boyutunu küçülttük
                        prefixIcon: const Icon(Icons.search, size: 20), // İkon boyutunu küçülttük
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12), // İç padding'i küçülttük
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 40,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), // İç padding'i küçülttük
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      style: const TextStyle(fontSize: 13), // Font boyutunu küçülttük
                      items: _categories.map((Category category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                          _searchController.clear();
                          _fetchMovies(refresh: true);
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Film listesi ve son izlenenler
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Son izlenenler bölümü
                SliverToBoxAdapter(
                  child: _buildRecentlyWatchedSection(),
                ),
                
                // Film grid'i
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4), // Boşluğu azalttık
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _filteredMovies.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final movie = _filteredMovies[index];
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return Card(
                              elevation: 0,
                              clipBehavior: Clip.hardEdge, // Bunu ekledik
                              color: Theme.of(context).colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _showMovieDetails(movie),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch, // Bunu ekledik
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _buildOptimizedImage(movie.posterPath),
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
                                                    HugeIcons.strokeRoundedStar,
                                                    size: 14,
                                                    color: Colors.amber,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    movie.voteAverage.toStringAsFixed(1),
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
                          },
                        );
                      },
                      childCount: _filteredMovies.length + (_isLoadingMore ? 1 : 0),
                    ),
                  ),
                ),
              ],
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
    // Cache'leri temizle
    _movieDetailCache.clear();
    _imageCache.clear();
    
    _autoScrollTimer?.cancel();
    _recentMoviesController.dispose();
    // Belleği temizle
    imageCache.clear();
    imageCache.clearLiveImages();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleDownload(String videoUrl, String title) async {
    try {
      final saveLocation = await FilePicker.platform.saveFile(
        dialogTitle: 'Kayıt Konumu Seç',
        fileName: '$title.mkv',
      );

      if (saveLocation != null && mounted) {
        // İndirmeyi başlat
        DownloadManager().startDownload(videoUrl, title, saveLocation);
        
        // pushReplacement yerine push kullan
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
          const SnackBar(content: Text('İndirme başlatılırken bir hata oluştu')),
        );
      }
    }
  }
}

class DownloadDialog extends StatelessWidget {
  final String url;
  final String fileName;

  const DownloadDialog({
    Key? key,
    required this.url,
    required this.fileName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('İndirme Konumunu Seç'),
      content: const Text('Dosyayı indirmek istediğiniz konumu seçin.'),
      actions: [
        TextButton(
          child: const Text('İptal'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: const Text('Seç'),
          onPressed: () async {
            String downloadUrl = url;
            if (MediafireExtractor.isMediafireUrl(url)) {
              final directUrl = await MediafireExtractor.extractDirectUrl(url);
              if (directUrl != null) {
                downloadUrl = directUrl;
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mediafire linkinden indirme linki alınamadı')),
                  );
                  Navigator.pop(context);
                  return;
                }
              }
            }

            final saveLocation = await FilePicker.platform.saveFile(
              dialogTitle: 'Kayıt Konumu Seç',
              fileName: '$fileName.mkv',
            );

            if (saveLocation != null && context.mounted) {
              DownloadManager().startDownload(downloadUrl, fileName, saveLocation);
              Navigator.pop(context);
              
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DownloadsPage()),
              );
            }
          },
        ),
      ],
    );
  }
}