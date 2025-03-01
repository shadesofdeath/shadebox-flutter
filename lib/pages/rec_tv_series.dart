import 'dart:async';
import 'package:ShadeBox/pages/download_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/video_player_dialog.dart';
import 'package:ShadeBox/pages/downloads_page.dart';

class Series {
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

  Series({
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

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
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

class Episode {
  final int id;
  final String title;
  final List<Source> sources;

  Episode({
    required this.id,
    required this.title,
    required this.sources,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'],
      title: json['title'],
      sources: (json['sources'] as List).map((s) => Source.fromJson(s)).toList(),
    );
  }
}

class Season {
  final int id;
  final String title;
  final List<Episode> episodes;

  Season({
    required this.id,
    required this.title,
    required this.episodes,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'],
      title: json['title'],
      episodes: (json['episodes'] as List).map((e) => Episode.fromJson(e)).toList(),
    );
  }
}

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

class RecTVSeriesPage extends StatefulWidget {
  const RecTVSeriesPage({super.key});

  @override
  State<RecTVSeriesPage> createState() => _RecTVSeriesPageState();
}

class _RecTVSeriesPageState extends State<RecTVSeriesPage> {
  String _mainUrl = "https://a.prectv35.sbs";
  String _swKey = "4F5A9C3D9A86FA54EACEDDD635185/c3c5bd17-e37b-4b94-a944-8a3688a30452";
  
  List<Series> _series = [];
  bool _isLoading = false;
  String _selectedCategory = "0";
  int _currentPage = 0;
  Timer? _debounce;
  
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final Map<String, String> _categories = {
    "0": "Son Diziler",
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
    _fetchConfig().then((_) => _fetchInitialSeries()); // initState'de _fetchInitialSeries'i çağır
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 1000) {
      _loadMore();
    }
  }

  Future<void> _fetchInitialSeries() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _series.clear();
    });

    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('$_mainUrl/api/serie/by/filtres/$_selectedCategory/created/0/$_swKey/'),
          headers: {'user-agent': 'okhttp/4.12.0'},
        ),
        http.get(
          Uri.parse('$_mainUrl/api/serie/by/filtres/$_selectedCategory/created/1/$_swKey/'),
          headers: {'user-agent': 'okhttp/4.12.0'},
        ),
      ]);

      final List<Series> allSeries = [];
      
      for (var response in responses) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          allSeries.addAll(data.map((item) => Series.fromJson(item)).toList());
        }
      }

      if (mounted) {
        setState(() {
          _series = allSeries;
          _currentPage = 1;
          _isLoading = false; // Loading durumunu burada false yap
        });
      }
    } catch (e) {
      debugPrint('Error fetching initial series: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchSeries({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      await _fetchInitialSeries();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$_mainUrl/api/serie/by/filtres/$_selectedCategory/created/$_currentPage/$_swKey/'),
        headers: {'user-agent': 'okhttp/4.12.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Series> newSeries = data.map((item) => Series.fromJson(item)).toList();

        if (mounted) {
          setState(() {
            _series.addAll(newSeries);
            _isLoading = false; // Loading durumunu burada false yap
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching series: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    _currentPage++;
    await _fetchSeries();
  }

  Future<void> _searchSeries(String query) async {
    _debounce?.cancel();
    
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
          final List<Series> searchResults = [];
          
          if (data['posters'] != null) {
            searchResults.addAll(
              (data['posters'] as List)
                .where((item) => item['type'] == 'serie')
                .map((item) => Series.fromJson(item))
            );
          }

          setState(() {
            _series = searchResults;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error searching series: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<List<Season>> _fetchSeasons(int seriesId) async {
    try {
      final response = await http.get(
        Uri.parse('$_mainUrl/api/season/by/serie/$seriesId/$_swKey/'),
        headers: {'user-agent': 'okhttp/4.12.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((season) => Season.fromJson(season)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching seasons: $e');
      return [];
    }
  }

  Future<void> _handleDownload(String videoUrl, String title) async {
    try {
      debugPrint('Starting download for URL: $videoUrl');
      
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

      String extension = videoUrl.toLowerCase().contains('m3u8') ? 'ts' : 'mp4';

      final saveLocation = await FilePicker.platform.saveFile(
        dialogTitle: 'Kayıt Konumu Seç',
        fileName: '$title.$extension',
      );

      if (saveLocation != null && mounted) {
        debugPrint('Save location: $saveLocation');
        debugPrint('Final URL for download: $finalUrl');
        
        DownloadManager().startDownload(
          finalUrl,
          title,
          saveLocation,
        );

        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const DownloadsPage()),
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

  Future<void> _showSeriesDetails(Series series) async {
    if (!mounted) return;

    final seasons = await _fetchSeasons(series.id);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        Stack(
                          children: [
                            Image.network(
                              series.image,
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
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
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
                                    series.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (series.rating != null || series.year != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (series.rating != null)
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
                                                  series.rating!.toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (series.year != null) ...[
                                          const SizedBox(width: 12),
                                          Text(
                                            series.year.toString(),
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
                        if (series.description != null)
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
                                  series.description!,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                if (series.genres != null) ...[
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: series.genres!.map((genre) {
                                      return Chip(label: Text(genre.title));
                                    }).toList(),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                Text(
                                  'Sezonlar',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...seasons.map((season) => ExpansionTile(
                                  title: Text(season.title),
                                  children: season.episodes.map((episode) => ListTile(
                                    title: Text(episode.title),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(HugeIcons.strokeRoundedPlay),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            showDialog(
                                              context: context,
                                              builder: (context) => VideoPlayerDialog(
                                                videoUrl: episode.sources.first.url,
                                                title: '${series.title} - ${episode.title}',
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(HugeIcons.strokeRoundedDownload05),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _handleDownload(
                                              episode.sources.first.url,
                                              '${series.title} - ${episode.title}',
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                )).toList(),
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
        
        final RegExp mainUrlRegex = RegExp(r'mainUrl\s*=\s*"([^"]+)"');
        final RegExp swKeyRegex = RegExp(r'swKey\s*=\s*"([^"]+)"');
        
        final mainUrlMatch = mainUrlRegex.firstMatch(content);
        final swKeyMatch = swKeyRegex.firstMatch(content);
        
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
        
        if (newMainUrl != null && newSwKey != null) {
          bool urlChanged = _mainUrl != newMainUrl;
          
          setState(() {
            _mainUrl = newMainUrl!;
            _swKey = newSwKey!;
          });
          
          if (urlChanged) {
            try {
              final testResponse = await http.get(
                Uri.parse('$_mainUrl/api/serie/by/filtres/0/created/0/$_swKey/'),
                headers: {'user-agent': 'okhttp/4.12.0'},
              ).timeout(const Duration(seconds: 5));
              
              if (testResponse.statusCode != 200) {
                throw Exception('Invalid response from new URL');
              }
            } catch (e) {
              debugPrint('New URL test failed: $e');
              setState(() {
                _mainUrl = "https://m.prectv37.sbs";
              });
            }
          }
          
          _fetchSeries(refresh: true);
        }
      }
    } catch (e) {
      debugPrint('Error fetching config: $e');
      setState(() {
        _mainUrl = "https://m.prectv37.sbs";
      });
      _fetchSeries(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
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
                        _searchSeries(query);
                      } else if (query.isEmpty) {
                        _fetchSeries(refresh: true);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Dizi Ara...',
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
                          _fetchInitialSeries(); // Kategori değişiminde _fetchInitialSeries'i çağır
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
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
              itemCount: _series.length + (_isLoading && _series.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _series.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final series = _series[index];
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
                    onTap: () => _showSeriesDetails(series),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                series.image,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => 
                                  const Icon(HugeIcons.strokeRoundedImageNotFound01),
                              ),
                              if (series.rating != null)
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
                                          series.rating!.toStringAsFixed(1),
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
                            series.title,
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
}
