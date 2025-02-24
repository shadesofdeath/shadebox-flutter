import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; // StreamController için eklendi
import 'package:http/http.dart' as http;
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

class _SinewixFilmPageState extends State<SinewixFilmPage> {
  final String _mainUrl = "https://ythls.kekikakademi.org";
  List<Movie> _movies = [];
  List<Movie> _filteredMovies = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  String? _selectedCategory;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

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
  void initState() {
    super.initState();
    _selectedCategory = _categories.first.id;
    _scrollController.addListener(_scrollListener);
    _fetchMovies();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _fetchMovies({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _movies.clear();
    }

    setState(() => _isLoading = true);

    try {
      final category = _categories.firstWhere((c) => c.id == _selectedCategory);
      
      // İlk açılışta 2 sayfa çek
      if (_movies.isEmpty) {
        final futures = [
          http.get(
            Uri.parse('$_mainUrl${category.url}/1'),
            headers: {'Accept-Charset': 'utf-8'},  // Add UTF-8 header
          ),
          http.get(
            Uri.parse('$_mainUrl${category.url}/2'),
            headers: {'Accept-Charset': 'utf-8'},  // Add UTF-8 header
          ),
        ];

        final responses = await Future.wait(futures);
        List<Movie> allMovies = [];

        for (var response in responses) {
          if (response.statusCode == 200) {
            final data = json.decode(utf8.decode(response.bodyBytes));  // Use utf8.decode
            allMovies.addAll(
              (data['data'] as List).map((movieJson) => Movie.fromJson(movieJson))
            );
          }
        }

        setState(() {
          _movies = allMovies;
          _filteredMovies = allMovies;
          _isLoading = false;
          _currentPage = 2; // Sonraki sayfa için
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

  Future<void> _showMovieDetails(Movie movie) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_mainUrl/sinewix/movie/${movie.id}'),
        headers: {'Accept-Charset': 'utf-8'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final movieDetail = MovieDetail.fromJson(data);

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
                                                  Icons.image_not_supported,
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
                                                Icons.image_not_supported,
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
                                              Icons.play_arrow,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                            onPressed: () {
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
                                              Icons.download,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                            onPressed: () async {
                                              final videoUrl = movieDetail.videos.first.link;
                                              final result = await showDialog<bool>(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (context) => DownloadDialog(
                                                  url: videoUrl,
                                                  fileName: '${movieDetail.title}',
                                                ),
                                              );
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
                                                  const Icon(Icons.star, size: 16),
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
                                                          ? const Icon(Icons.person, size: 40)
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
        );
      }
    } catch (e) {
      debugPrint('Error fetching movie details: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                  onChanged: (query) {
                    if (query.length >= 3) {
                      _searchMovies(query);
                    } else if (query.isEmpty) {
                      setState(() => _filteredMovies = _movies);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Film Ara... (En az 3 karakter)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
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
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
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
            ],
          ),
        ),
        Expanded(
          child: _isLoading && _movies.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _filteredMovies.isEmpty
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
                      itemCount: _filteredMovies.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _filteredMovies.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final movie = _filteredMovies[index];
                        return Card(
                          elevation: 0,
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
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(8),
                                        ),
                                        child: Image.network(
                                          movie.posterPath,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.error, size: 20),
                                        ),
                                      ),
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
                                                Icons.star_rounded,
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
                    ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
  late final player = Player();
  late final controller = VideoController(player);
  double subtitleFontSize = 32.0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await player.open(Media(widget.videoUrl));
    } catch (e) {
      debugPrint('Video yüklenirken hata: $e');
    }
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StreamBuilder(
                    stream: player.stream.tracks,
                    builder: (context, snapshot) {
                      final audioTracks = player.state.tracks.audio;
                      final subtitleTracks = player.state.tracks.subtitle;
                      final videoTracks = player.state.tracks.video;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ses kanalları menüsü
                          if (audioTracks.isNotEmpty)
                            PopupMenuButton<AudioTrack>(
                              icon: const Icon(Icons.audiotrack, color: Colors.white),
                              tooltip: 'Ses & Dublaj',
                              position: PopupMenuPosition.under,
                              itemBuilder: (context) => [
                                for (var track in audioTracks)
                                  PopupMenuItem(
                                    value: track,
                                    child: Row(
                                      children: [
                                        Icon(
                                          track == player.state.track.audio
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            track.title ?? 'Ses ${track.id}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              onSelected: player.setAudioTrack,
                            ),

                          if (subtitleTracks.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            PopupMenuButton<SubtitleTrack>(
                              icon: const Icon(Icons.subtitles, color: Colors.white),
                              tooltip: 'Altyazı',
                              position: PopupMenuPosition.under,
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: SubtitleTrack.no(),
                                  child: Row(
                                    children: [
                                      Icon(
                                        player.state.track.subtitle == null
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Kapalı'),
                                    ],
                                  ),
                                ),
                                for (var track in subtitleTracks)
                                  PopupMenuItem(
                                    value: track,
                                    child: Row(
                                      children: [
                                        Icon(
                                          track == player.state.track.subtitle
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            track.title ?? 'Altyazı ${track.id}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              onSelected: player.setSubtitleTrack,
                            ),

                            PopupMenuButton<void>(
                              icon: const Icon(Icons.text_fields, color: Colors.white),
                              tooltip: 'Altyazı Boyutu',
                              position: PopupMenuPosition.under,
                              itemBuilder: (context) => <PopupMenuEntry<void>>[
                                PopupMenuItem<void>(
                                  enabled: false,
                                  height: 48,
                                  child: StatefulBuilder(
                                    builder: (context, setMenuState) => SizedBox(
                                      width: 200,
                                      child: Slider(
                                        value: subtitleFontSize,
                                        min: 32,
                                        max: 140,
                                        divisions: 10,
                                        label: '${(subtitleFontSize / 32).round()}x',
                                        onChanged: (value) {
                                          setMenuState(() {
                                            setState(() {
                                              subtitleFontSize = value;
                                            });
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (videoTracks.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            PopupMenuButton<VideoTrack>(
                              icon: const Icon(Icons.hd, color: Colors.white),
                              tooltip: 'Video Kalitesi',
                              position: PopupMenuPosition.under,
                              itemBuilder: (context) => [
                                for (var track in videoTracks)
                                  PopupMenuItem(
                                    value: track,
                                    child: Row(
                                      children: [
                                        Icon(
                                          track == player.state.track.video
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            track.title ?? 'Video ${track.id}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              onSelected: player.setVideoTrack,
                            ),
                          ],

                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Video(
                  controller: controller,
                  controls: AdaptiveVideoControls,
                  subtitleViewConfiguration: SubtitleViewConfiguration(
                    style: TextStyle(fontSize: subtitleFontSize),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}

class DownloadDialog extends StatefulWidget {
  final String url;
  final String fileName;

  const DownloadDialog({
    Key? key,
    required this.url,
    required this.fileName,
  }) : super(key: key);

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  double _progress = 0;
  String _status = 'Hazırlanıyor...';
  String _speed = '0 KB/s';
  String _downloadedSize = '0 MB';
  String _totalSize = '0 MB';
  bool _isDownloading = false;
  bool _isCancelled = false;
  HttpClient? _client;
  DateTime? _startTime;
  Timer? _speedTimer;
  int _lastReceivedBytes = 0;
  String? _saveLocation;
  static const int bufferSize = 256 * 1024; // 64 KB buffer
  final Dio _dio = Dio();
  final int _chunkSize = 2 * 1024 * 1024; // 2MB chunks
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _client?.close();
    // İptal edilmişse dosyayı sil
    if (_isCancelled && _saveLocation != null) {
      File(_saveLocation!).deleteSync();
    }
    super.dispose();
  }

  Future<void> _startDownload() async {
    try {
      final fileName = _sanitizeFilename(widget.fileName);
      final fileExt = _detectFileExtension(widget.url);
      final fullFileName = '$fileName.$fileExt';

      _saveLocation = await FilePicker.platform.saveFile(
        dialogTitle: 'Kayıt Konumu Seç',
        fileName: fullFileName,
        type: FileType.custom,
        allowedExtensions: [fileExt],
      );

      if (_saveLocation == null || !mounted) {
        Navigator.pop(context);
        return;
      }

      setState(() {
        _isDownloading = true;
        _status = 'İndirme başlatılıyor...';
      });

      _cancelToken = CancelToken();
      _startTime = DateTime.now();
      var lastUpdateTime = DateTime.now();
      var lastBytes = 0;

      // Hız hesaplama timer'ı
      _speedTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        final duration = DateTime.now().difference(lastUpdateTime);
        if (duration.inSeconds > 0) {
          final speed = (_lastReceivedBytes - lastBytes) / duration.inSeconds;
          if (mounted && speed > 0) {
            setState(() => _speed = _formatSpeed(speed));
            lastBytes = _lastReceivedBytes;
            lastUpdateTime = DateTime.now();
          }
        }
      });

      // Optimize edilmiş dio ayarları
      _dio.options = BaseOptions(
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
        responseType: ResponseType.stream,
        followRedirects: true,
        validateStatus: (status) => status! < 500,
        receiveTimeout: const Duration(minutes: 30),
        sendTimeout: const Duration(minutes: 30),
        connectTimeout: const Duration(seconds: 30),
        receiveDataWhenStatusError: true,
        maxRedirects: 5,
      );

      final response = await _dio.get(
        widget.url,
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted && !_isCancelled) {
            setState(() {
              _progress = received / total;
              _lastReceivedBytes = received;
              _downloadedSize = _formatSize(received);
              _totalSize = _formatSize(total);
              _status = 'İndiriliyor... ${(_progress * 100).toStringAsFixed(1)}%';
            });
          }
        },
      );

      final file = File(_saveLocation!);
      final sink = file.openWrite();

      int received = 0;
      int total = -1;

      try {
        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          total = int.tryParse(contentLength) ?? -1;
        }

        await for (final chunk in response.data.stream) {
          if (_isCancelled) break;
          
          sink.add(chunk); // sync write
          received += (chunk.length as num).toInt();

          if (mounted && !_isCancelled) {
            setState(() {
              if (total > 0) {
                _progress = received / total;
                _lastReceivedBytes = received;
                _downloadedSize = _formatSize(received);
                _totalSize = _formatSize(total);
                _status = 'İndiriliyor... ${(_progress * 100).toStringAsFixed(1)}%';
              } else {
                _downloadedSize = _formatSize(received);
                _status = 'İndiriliyor... $_downloadedSize';
              }
            });
          }
        }

        await sink.flush();
      } finally {
        await sink.close();
      }

      _speedTimer?.cancel();

      if (_isCancelled) {
        await file.delete();
        if (mounted) Navigator.pop(context);
        return;
      }

      if (mounted) {
        setState(() {
          _status = 'İndirme tamamlandı';
          _isDownloading = false;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context, true);
      }
    } catch (e) {
      _speedTimer?.cancel();
      if (!_isCancelled && mounted) {
        setState(() {
          _status = 'Hata: ${e.toString()}';
          _isDownloading = false;
        });
      }
    }
  }

  void _cancelDownload() {
    _isCancelled = true;
    _cancelToken?.cancel();
    _dio.close(force: true);
    Navigator.pop(context);
  }

  String _sanitizeFilename(String name) {
    // Dosya adından geçersiz karakterleri temizle
    name = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    // Çift uzantıları temizle
    if (name.toLowerCase().endsWith('.mp4.mkv')) {
      name = name.substring(0, name.length - 4);
    }
    return name;
  }

  String _detectFileExtension(String url) {
    try {
      // Content-Type'a göre uzantı belirleme için HEAD request
      final uri = Uri.parse(url);
      final extensionFromPath = uri.path.split('.').last.toLowerCase();
      
      if (['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(extensionFromPath)) {
        return extensionFromPath;
      }
      return 'mp4';
    } catch (_) {
      return 'mp4';
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(1)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
    }
  }

  String _formatSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    
    while (size > 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isDownloading)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'İndirmeyi İptal Et',
                    onPressed: _cancelDownload,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_downloadedSize / $_totalSize',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    _speed,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              _status,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}