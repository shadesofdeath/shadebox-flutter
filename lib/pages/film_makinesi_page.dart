import 'package:ShadeBox/widgets/video_player_dialog.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Category {
  final String url;
  final String name;

  Category({required this.url, required this.name});
}

// Film modeli ekleniyor
class Film {
  final String category;
  final String title;
  final String url;
  final String poster;

  Film({
    required this.category,
    required this.title,
    required this.url,
    required this.poster,
  });

  factory Film.fromJson(Map<String, dynamic> json) {
    return Film(
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      poster: json['poster'] ?? '',
    );
  }
}

// Film detay modeli
class FilmDetail {
  final String url;
  final String poster;
  final String title;
  final String description;
  final String tags;
  final String rating;
  final String year;
  final String actors;
  final int duration;

  FilmDetail({
    required this.url,
    required this.poster,
    required this.title,
    required this.description,
    required this.tags,
    required this.rating,
    required this.year,
    required this.actors,
    required this.duration,
  });

  factory FilmDetail.fromJson(Map<String, dynamic> json) {
    return FilmDetail(
      url: json['url'] ?? '',
      poster: json['poster'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      tags: json['tags'] ?? '',
      rating: json['rating'] ?? '',
      year: json['year'] ?? '',
      actors: json['actors'] ?? '',
      duration: json['duration'] ?? 0,
    );
  }
}

class FilmMakinesiPage extends StatefulWidget {
  const FilmMakinesiPage({super.key});

  @override
  State<FilmMakinesiPage> createState() => _FilmMakinesiPageState();
}

class _FilmMakinesiPageState extends State<FilmMakinesiPage> {
  List<Category> categories = [];
  Category? selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();
  List<Film> _films = [];
  int _currentPage = 1;
  bool _isLoadingMore = false;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    fetchCategories().then((_) {
      if (categories.isNotEmpty) {
        setState(() {
          selectedCategory = categories.first;
          _currentUrl = categories.first.url;
        });
        _fetchFilms();
      }
    });
  }

  Future<void> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:3310/api/v1/get_plugin?plugin=FilmMakinesi'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, dynamic> mainPage = data['result']['main_page'];

        setState(() {
          categories = mainPage.entries.map((entry) {
            return Category(
              url: Uri.decodeComponent(entry.key.replaceAll('%2F', '/')),
              name: Uri.decodeComponent(entry.value.replaceAll('+', ' ')),
            );
          }).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error fetching categories: $e');
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 500) {
      if (!_isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _fetchFilms(isLoadMore: true);
    setState(() => _isLoadingMore = false);
  }

  Future<void> _fetchFilms({bool isLoadMore = false}) async {
    if (!isLoadMore) {
      setState(() {
        _films.clear(); // .clear() kullanarak listeyi temizle
        _currentPage = 1;
        isLoading = true;
      });
    }

    try {
      final response = await http.get(
        Uri.parse(
          'http://127.0.0.1:3310/api/v1/get_main_page?plugin=FilmMakinesi&page=$_currentPage&encoded_url=${Uri.encodeComponent(_currentUrl ?? "")}&encoded_category=${Uri.encodeComponent(selectedCategory?.name ?? "")}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)); // UTF-8 decode ekle
        final List<Film> newFilms = (data['result'] as List)
            .map((film) => Film.fromJson(film))
            .toList();

        setState(() {
          if (isLoadMore) {
            _films.addAll(newFilms); // addAll ile yeni filmleri ekle
          } else {
            _films = newFilms;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching films: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _showMovieDetails(Film film) async {
    debugPrint('Tıklanan film: ${film.title}');
    debugPrint('Film URL: ${film.url}');

    try {
      setState(() => isLoading = true);

      // Film detaylarını çek
      final filmDetail = await _fetchWithRetry(() async {
        final detailResponse = await http.get(
          Uri.parse(
            'http://127.0.0.1:3310/api/v1/load_item?plugin=FilmMakinesi&encoded_url=${film.url}',
          ),
        );
        if (detailResponse.statusCode == 200) {
          final detailData = json.decode(utf8.decode(detailResponse.bodyBytes));
          return FilmDetail.fromJson(detailData['result']);
        }
        throw Exception('Failed to load film details');
      });

      if (!mounted) return;

      setState(() => isLoading = false);

      // Kullanıcıya seçenek sunma dialog'u
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(filmDetail.title),
          content: const Text('Ne yapmak istersiniz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showMovieDialog(film, filmDetail);
              },
              child: const Text('İzle'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _initiateDownload(film.url);
              },
              child: const Text('İndir'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Film detayları çekilirken hata: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<T> _fetchWithRetry<T>(Future<T> Function() apiCall) async {
    while (true) {
      try {
        return await apiCall();
      } catch (e) {
        debugPrint('API çağrısı başarısız, tekrar deneniyor: $e');
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _showMovieDialog(Film film, FilmDetail filmDetail) async {
    if (!mounted) return;
    
    try {
      // Video linklerini al
      final videoLinks = await _fetchWithRetry(() async {
        final linksResponse = await http.get(
          Uri.parse('http://127.0.0.1:3310/api/v1/load_links?plugin=FilmMakinesi&encoded_url=${film.url}'),
        );
        if (linksResponse.statusCode == 200) {
          final linksData = json.decode(linksResponse.body);
          return linksData['result'] as List;
        }
        throw Exception('Failed to load video links');
      });

      // Extract video URL
      final extractData = await _fetchWithRetry(() async {
        final extractResponse = await http.get(
          Uri.parse('http://127.0.0.1:3310/api/v1/extract?encoded_url=${videoLinks[0]}&encoded_referer=https://filmmakinesi.de'),
        );
        if (extractResponse.statusCode == 200) {
          return json.decode(extractResponse.body);
        }
        throw Exception('Failed to extract video URL');
      });

      if (!mounted) return;

      final videoUrl = extractData['result']['url'];
      final referer = extractData['result']['referer'];

      showDialog(
        context: context,
        builder: (context) => VideoPlayerDialog(
          videoUrl: videoUrl,
          title: filmDetail.title,
          referer: referer,
        ),
      );
    } catch (e) {
      debugPrint('Video oynatma hatası: $e');
    }
  }

  Future<void> _initiateDownload(String encodedUrl) async {
    try {
      // Video linklerini al
      final videoLinks = await _fetchWithRetry(() async {
        final linksResponse = await http.get(
          Uri.parse('http://127.0.0.1:3310/api/v1/load_links?plugin=FilmMakinesi&encoded_url=$encodedUrl'),
        );
        if (linksResponse.statusCode == 200) {
          final linksData = json.decode(linksResponse.body);
          return linksData['result'] as List;
        }
        throw Exception('Failed to load video links');
      });

      // Extract download URL
      final extractData = await _fetchWithRetry(() async {
        final extractResponse = await http.get(
          Uri.parse('http://127.0.0.1:3310/api/v1/extract?encoded_url=${videoLinks[0]}&encoded_referer=https://filmmakinesi.de'),
        );
        if (extractResponse.statusCode == 200) {
          return json.decode(extractResponse.body);
        }
        throw Exception('Failed to extract video URL');
      });

      final downloadUrl = extractData['result']['url'];
      final referer = extractData['result']['referer'];

      // TODO: İndirme işlemini başlat
      debugPrint('Download URL: $downloadUrl');
      debugPrint('Referer: $referer');
    } catch (e) {
      debugPrint('İndirme başlatma hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search Bar and Category Dropdown in Row
          Row(
            children: [
              // Search Bar - Takes more space (2/3)
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Film Ara...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16), // Spacing between elements
              // Category Dropdown - Takes less space (1/3)
              Expanded(
                flex: 1,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<Category>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          labelText: 'Kategori',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                        ),
                        items: categories.map((Category category) {
                          return DropdownMenuItem<Category>(
                            value: category,
                            child: Text(
                              category.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (Category? value) {
                          setState(() {
                            selectedCategory = value;
                            _currentUrl = value?.url;
                          });
                          _fetchFilms();
                        },
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Films grid
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    controller: _scrollController,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 10, // Daha fazla sütun
                      childAspectRatio: 0.65, // En-boy oranı
                      crossAxisSpacing: 12, // Yatay boşluk
                      mainAxisSpacing: 12, // Dikey boşluk
                    ),
                    itemCount: _films.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _films.length) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      
                      final film = _films[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        margin: EdgeInsets.zero, // Margin'i kaldır
                        child: InkWell(
                          onTap: () {
                            debugPrint('Karta tıklandı: ${film.title}'); // Debug log
                            _showMovieDetails(film);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      film.poster,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Center(child: Icon(Icons.error, size: 20)),
                                    ),
                                    // Tıklanabilir olduğunu belli etmek için hover efekti
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _showMovieDetails(film),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                Colors.black.withOpacity(0.3),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Text(
                                  film.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11, // Font boyutunu küçült
                                    fontWeight: FontWeight.w500,
                                  ),
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
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
