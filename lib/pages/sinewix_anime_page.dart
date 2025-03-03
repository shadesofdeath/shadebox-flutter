import 'package:ShadeBox/pages/download_manager.dart';
import 'package:ShadeBox/pages/downloads_page.dart';
import 'package:ShadeBox/widgets/video_player_dialog.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

// TV Show model
class TVShow {
  final int id;
  final String title;
  final String posterPath;
  final String type;
  final double voteAverage;

  TVShow({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.type,
    required this.voteAverage,
  });

  factory TVShow.fromJson(Map<String, dynamic> json) {
    return TVShow(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? '', // Hem 'title' hem 'name' kontrolü ekledik
      posterPath: json['poster_path'] ?? '',
      type: json['type'] ?? 'anime',
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title, // 'name' yerine 'title' kullanıyoruz
      'poster_path': posterPath,
      'type': type,
      'vote_average': voteAverage,
    };
  }
}

// TV Show Detail model
class TVShowDetail {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double voteAverage;
  final int voteCount;
  final String firstAirDate;
  final List<Cast> cast;
  final List<String> genres;
  final String? imdbExternalId;
  final String? previewPath;
  final List<Season> seasons;
  final String backdropPathTv;
  final int popularity;
  final bool enableStream;

  TVShowDetail({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.voteCount,
    required this.firstAirDate,
    required this.cast,
    required this.genres,
    this.imdbExternalId,
    this.previewPath,
    required this.seasons,
    required this.backdropPathTv,
    required this.popularity,
    required this.enableStream,
  });

  factory TVShowDetail.fromJson(Map<String, dynamic> json) {
    String backdropPathTv = json['backdrop_path_tv'] ?? '';
    if (!backdropPathTv.startsWith('http')) {
      backdropPathTv = '';
    }

    return TVShowDetail(
      id: json['id'],
      title: json['name'] ?? '',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      firstAirDate: json['first_air_date'] ?? '',
      cast: (json['casterslist'] as List? ?? [])
          .take(10)
          .map((cast) => Cast.fromJson(cast))
          .toList(),
      genres: (json['genreslist'] as List? ?? [])
          .map((genre) => genre.toString())
          .toList(),
      imdbExternalId: json['imdb_external_id'],
      previewPath: json['preview_path'],
      seasons: (json['seasons'] as List? ?? [])
          .map((season) => Season.fromJson(season))
          .toList(),
      backdropPathTv: backdropPathTv,
      popularity: (json['popularity'] ?? 0.0).toInt(),
      enableStream: json['enable_stream'] == 1,
    );
  }
}

// Season model
class Season {
  final int id;
  final int seasonNumber;
  final String name;
  final String? overview;
  final String posterPath;
  final String airDate;
  final List<Episode> episodes;

  Season({
    required this.id,
    required this.seasonNumber,
    required this.name,
    this.overview,
    required this.posterPath,
    required this.airDate,
    required this.episodes,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'],
      seasonNumber: json['season_number'],
      name: json['name'] ?? '',
      overview: json['overview'],
      posterPath: json['poster_path'] ?? '',
      airDate: json['air_date'] ?? '',
      episodes: (json['episodes'] as List? ?? [])
          .map((episode) => Episode.fromJson(episode))
          .toList(),
    );
  }
}

// Episode model
class Episode {
  final int id;
  final int episodeNumber;
  final String name;
  final String? overview;
  final String stillPath;
  final String stillPathTv;
  final double voteAverage;
  final String airDate;
  final bool enableStream;
  final List<VideoSource> videos; // Add this

  Episode({
    required this.id,
    required this.episodeNumber,
    required this.name,
    this.overview,
    required this.stillPath,
    required this.stillPathTv,
    required this.voteAverage,
    required this.airDate,
    required this.enableStream,
    required this.videos,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'],
      episodeNumber: json['episode_number'],
      name: json['name'] ?? '',
      overview: json['overview'],
      stillPath: json['still_path'] ?? '',
      stillPathTv: json['still_path_tv'] ?? '',
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      airDate: json['air_date'] ?? '',
      enableStream: json['enable_stream'] == 1,
      videos: (json['videos'] as List? ?? [])
          .map((video) => VideoSource.fromJson(video))
          .toList(),
    );
  }
}

// Video kaynağı için yeni model ekle
class VideoSource {
  final int id;
  final String server;
  final String? header;
  final String? useragent;
  final String link;
  final String lang;

  VideoSource({
    required this.id,
    required this.server,
    this.header,
    this.useragent,
    required this.link,
    required this.lang,
  });

  factory VideoSource.fromJson(Map<String, dynamic> json) {
    return VideoSource(
      id: json['id'],
      server: json['server'] ?? '',
      header: json['header'],
      useragent: json['useragent'],
      link: json['link'] ?? '',
      lang: json['lang'] ?? '',
    );
  }
}

// Cast model
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

class SinewixAnimePage extends StatefulWidget {
  const SinewixAnimePage({super.key});

  @override
  State<SinewixAnimePage> createState() => _SinewixAnimePageState();
}

class _SinewixAnimePageState extends State<SinewixAnimePage> {
  final String _mainUrl = "https://ythls.kekikakademi.org";
  List<TVShow> _shows = [];
  List<TVShow> _filteredShows = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Add these new variables after existing ones
  final PageController _recentShowsController = PageController();
  List<TVShow> _recentlyWatched = [];
  Timer? _autoScrollTimer;
  int _currentRecentPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchShows();
    _loadRecentlyWatched(); // Add this
    _startAutoScroll(); // Add this
  }

  // Add these new methods before build()
  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_recentlyWatched.isNotEmpty && mounted) {
        final pageCount = (_recentlyWatched.length / 8).ceil();
        final nextPage = (_currentRecentPage + 1) % pageCount;
        
        _recentShowsController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadRecentlyWatched() async {
    final prefs = await SharedPreferences.getInstance();
    final recentShowsJson = prefs.getStringList('recent_animes') ?? [];
    setState(() {
      _recentlyWatched = recentShowsJson
          .map((json) => TVShow.fromJson(jsonDecode(json)))
          .toList();
    });
  }

  Future<void> _saveRecentShow(TVShow show) async {
    if (_recentlyWatched.any((s) => s.id == show.id)) return;

    final prefs = await SharedPreferences.getInstance();
    _recentlyWatched.insert(0, show);
    if (_recentlyWatched.length > 20) {
      _recentlyWatched.removeLast();
    }

    await prefs.setStringList(
      'recent_animes',
      _recentlyWatched.map((s) => jsonEncode(s.toJson())).toList(),
    );

    setState(() {});
  }

  Widget _buildRecentlyWatchedSection() {
    if (_recentlyWatched.isEmpty) return const SizedBox.shrink();

    final int itemsPerPage = 8;
    final int pageCount = (_recentlyWatched.length / itemsPerPage).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8), // top padding'i kaldırdık
          child: Text(
            'Son İzlenenler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 220, // yüksekliği azalttık (240->220)
          child: PageView.builder(
            controller: _recentShowsController,
            onPageChanged: (page) {
              setState(() => _currentRecentPage = page);
            },
            itemCount: pageCount,
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * itemsPerPage;
              final endIndex = min(startIndex + itemsPerPage, _recentlyWatched.length);
              final pageShows = _recentlyWatched.sublist(startIndex, endIndex);

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: pageShows.length,
                itemBuilder: (context, index) {
                  final show = pageShows[index];
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
                      onTap: () => _showTVDetails(show),
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
                                    show.posterPath,
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
                                          HugeIcons.strokeRoundedStar,
                                          size: 14,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          show.voteAverage.toStringAsFixed(1),
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
                              show.title,
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
          ),
        ),
      ],
    );
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _fetchShows();
    setState(() => _isLoadingMore = false);
  }

  Future<void> _fetchShows({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _shows.clear();
    }

    setState(() => _isLoading = true);

    try {
      if (_shows.isEmpty) {
        final futures = [
          http.get(
            Uri.parse('$_mainUrl/sinewix/animes/1'),
            headers: {'Accept-Charset': 'utf-8'},
          ),
          http.get(
            Uri.parse('$_mainUrl/sinewix/animes/2'),
            headers: {'Accept-Charset': 'utf-8'},
          ),
          http.get(
            Uri.parse('$_mainUrl/sinewix/animes/3'),
            headers: {'Accept-Charset': 'utf-8'},
          ),
        ];

        final responses = await Future.wait(futures);
        List<TVShow> allShows = [];

        for (var response in responses) {
          if (response.statusCode == 200) {
            final data = json.decode(utf8.decode(response.bodyBytes));
            allShows.addAll(
              (data['data'] as List).map((showJson) => TVShow.fromJson(showJson))
            );
          }
        }

        setState(() {
          _shows = allShows;
          _filteredShows = allShows;
          _isLoading = false;
          _currentPage = 3;
        });
      } else {
        final response = await http.get(
          Uri.parse('$_mainUrl/sinewix/animes/$_currentPage'),
          headers: {'Accept-Charset': 'utf-8'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final List<TVShow> shows = (data['data'] as List)
              .map((showJson) => TVShow.fromJson(showJson))
              .toList();

          setState(() {
            if (refresh) {
              _shows = shows;
            } else {
              _shows.addAll(shows);
            }
            _filteredShows = _shows;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error fetching shows: $e');
    }
  }

  Future<void> _searchShows(String query) async {
    if (query.isEmpty) {
      setState(() => _filteredShows = _shows);
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
            .where((item) => item['type'] == 'anime')
            .map((showJson) => TVShow.fromJson(showJson))
            .toList();

        setState(() {
          _filteredShows = searchResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching shows: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showTVDetails(TVShow show) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_mainUrl/sinewix/anime/${show.id}'),
        headers: {'Accept-Charset': 'utf-8'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final tvShowDetail = TVShowDetail.fromJson(data);

        if (!mounted) return;

        await showDialog(
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
                              // Backdrop ve Başlık
                              SliverAppBar(
                                expandedHeight: 400,
                                pinned: true,
                                flexibleSpace: FlexibleSpaceBar(
                                  background: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: tvShowDetail.backdropPathTv.isNotEmpty
                                            ? Image.network(
                                                tvShowDetail.backdropPathTv,
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
                                      Positioned(
                                        left: 20,
                                        bottom: 20,
                                        right: 20,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tvShowDetail.title,
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
                                                        tvShowDetail.voteAverage.toStringAsFixed(1),
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  tvShowDetail.firstAirDate,
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
                              // İçerik
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Türler
                                      if (tvShowDetail.genres.isNotEmpty) ...[
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: tvShowDetail.genres.map((genre) {
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
                                      // Özet
                                      Text(
                                        'Özet',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        tvShowDetail.overview,
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                      const SizedBox(height: 24),
                                      // Oyuncular
                                      if (tvShowDetail.cast.isNotEmpty) ...[
                                        Text(
                                          'Oyuncular',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          height: 150,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: tvShowDetail.cast.length,
                                            itemBuilder: (context, index) {
                                              final cast = tvShowDetail.cast[index];
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
                                      // Sezonlar
                                      Text(
                                        'Sezonlar',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 16),
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: tvShowDetail.seasons.length,
                                        itemBuilder: (context, seasonIndex) {
                                          final season = tvShowDetail.seasons[seasonIndex];
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 16.0), // Sezonlar arası boşluğu azalttık (24->16)
                                            child: Card(
                                              margin: EdgeInsets.zero,
                                              child: ExpansionTile(
                                                leading: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    season.posterPath,
                                                    width: 60,
                                                    height: 90,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        Container(
                                                      width: 60,
                                                      height: 90,
                                                      color: Colors.grey[900],
                                                      child: const Icon(
                                                        HugeIcons.strokeRoundedImageNotFound01,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  season.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                subtitle: Text(
                                                  '${season.episodes.length} Bölüm',
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                                children: season.episodes.map((episode) {
                                                  return Padding( // Bölümler arası padding ekledik
                                                    padding: const EdgeInsets.only(bottom: 8.0), // Bölümler arası boşluk
                                                    child: ListTile(
                                                      leading: episode.stillPathTv.isNotEmpty
                                                          ? ClipRRect(
                                                              borderRadius: BorderRadius.circular(4),
                                                              child: Image.network(
                                                                episode.stillPathTv,
                                                                width: 100,
                                                                height: 60,
                                                                fit: BoxFit.cover,
                                                                errorBuilder: (context, error, stackTrace) =>
                                                                    Container(
                                                                  width: 100,
                                                                  height: 60,
                                                                  color: Colors.grey[900],
                                                                  child: const Icon(
                                                                    HugeIcons.strokeRoundedImageNotFound01,
                                                                    color: Colors.grey,
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          : Container(
                                                              width: 100,
                                                              height: 60,
                                                              color: Colors.grey[900],
                                                              child: const Icon(
                                                                HugeIcons.strokeRoundedImageNotFound01,
                                                                color: Colors.grey,
                                                              ),
                                                            ),
                                                      title: Text(
                                                        '${episode.episodeNumber}. ${episode.name}',
                                                        style: const TextStyle(fontSize: 14),
                                                      ),
                                                      subtitle: episode.overview != null
                                                          ? Text(
                                                              episode.overview!,
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall,
                                                            )
                                                          : null,
                                                      trailing: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          if (episode.enableStream && episode.videos.isNotEmpty)
                                                            IconButton(
                                                              icon: const Icon(HugeIcons.strokeRoundedPlay),
                                                              onPressed: () {
                                                                // Episode oynatma dialog'ını göster
                                                                showDialog(
                                                                  context: context,
                                                                  builder: (context) => VideoPlayerDialog(
                                                                    videoUrl: episode.videos.first.link, // API'den gelen link
                                                                    title:
                                                                        '${tvShowDetail.title} - ${season.name} - ${episode.episodeNumber}. Bölüm',
                                                                  ),
                                                                );
                                                                _saveRecentShow(show); // Add this
                                                              },
                                                            ),
                                                          if (episode.videos.isNotEmpty)
                                                            IconButton(
                                                              icon: const Icon(HugeIcons.strokeRoundedDownload05),
                                                              onPressed: () async {
                                                                final safeFileName = _sanitizeFileName(
                                                                  '${tvShowDetail.title} - ${season.name} - ${episode.episodeNumber}. Bölüm'
                                                                );
                                                                
                                                                final saveLocation = await FilePicker.platform.saveFile(
                                                                  dialogTitle: 'Kayıt Konumu Seç',
                                                                  fileName: '$safeFileName.mp4',
                                                                );

                                                                if (saveLocation != null && context.mounted) {
                                                                  DownloadManager().startDownload(
                                                                    episode.videos.first.link,
                                                                    safeFileName,
                                                                    saveLocation
                                                                  );
                                                                  Navigator.push(
                                                                    context,
                                                                    MaterialPageRoute(builder: (context) => const DownloadsPage()),
                                                                  );
                                                                }
                                                              },
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          );
                                        },
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
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching TV show details: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Column yerine Scaffold kullanıyoruz
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (query) {
                if (query.length >= 3) {
                  _searchShows(query);
                } else if (query.isEmpty) {
                  setState(() => _filteredShows = _shows);
                }
              },
              decoration: InputDecoration(
                hintText: 'Anime Ara... (En az 3 karakter)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Add recently watched section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8), // Son izlenenler ile grid arasındaki boşluğu azalttık
                    child: _buildRecentlyWatchedSection(),
                  ),
                ),
                
                // Existing grid view
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _filteredShows.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final show = _filteredShows[index];
                        return _buildShowCard(show);
                      },
                      childCount: _filteredShows.length + (_isLoadingMore ? 1 : 0),
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

  Widget _buildShowCard(TVShow show) {
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
        onTap: () => _showTVDetails(show),
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
                      show.posterPath,
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
                            HugeIcons.strokeRoundedStar,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            show.voteAverage.toStringAsFixed(1),
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
                show.title,
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
  void dispose() {
    _autoScrollTimer?.cancel(); // Add this
    _recentShowsController.dispose(); // Add this
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Yardımcı fonksiyonu ekleyin (sınıfın içine)
  String _sanitizeFileName(String fileName) {
    // Windows'ta yasaklı karakterleri temizle
    var sanitized = fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')  // Windows yasaklı karakterler
        .replaceAll('\n', ' ')  // Yeni satırları boşlukla değiştir
        .replaceAll('\r', '')   // Satır sonlarını kaldır
        .trim();                // Baş ve sondaki boşlukları kaldır

    // Türkçe karakterleri dönüştür
    sanitized = sanitized
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'G')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 'S')
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'I')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'O')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C');

    // Uzun dosya adlarını kısalt
    if (sanitized.length > 200) {
      sanitized = sanitized.substring(0, 200);
    }

    return sanitized;
  }
}

// VideoPlayerDialog ve DownloadDialog sınıfları film sayfasıyla aynı
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
  Timer? _speedTimer;
  int _lastReceivedBytes = 0;
  String? _saveLocation;
  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  DateTime? _startTime; // Add this line
  int _totalSizeInBytes = 0; // Add this field

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
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
        options: Options(responseType: ResponseType.stream),
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
          
          sink.add(chunk);
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
    // Windows'ta yasaklı karakterleri temizle
    name = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    // Noktaları ve boşlukları güvenli karakterlerle değiştir
    name = name.replaceAll('.', '_');
    name = name.trim().replaceAll(RegExp(r'\s+'), '_');
    // Özel Türkçe karakterleri dönüştür
    name = name
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'G')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 'S')
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'I')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'O')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C');
    // Dosya adı uzunluğunu sınırla
    if (name.length > 200) {
      name = name.substring(0, 200);
    }
    // Dosya adı boşsa varsayılan ad ver
    if (name.isEmpty) {
      name = 'video';
    }
    return name;
  }

  String _detectFileExtension(String url) {
    try {
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
