import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/video_player_dialog.dart';

class Channel {
  final int id;
  final String title;
  final String image;
  final List<Source> sources;
  final String? description;
  final String? label;

  Channel({
    required this.id,
    required this.title,
    required this.image,
    required this.sources,
    this.description,
    this.label,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'],
      title: json['title'],
      image: json['image'],
      sources: (json['sources'] as List? ?? []).map((s) => Source.fromJson(s)).toList(),
      description: json['description'],
      label: json['label'],
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

class RecTVLivePage extends StatefulWidget {
  const RecTVLivePage({super.key});

  @override
  State<RecTVLivePage> createState() => _RecTVLivePageState();
}

class _RecTVLivePageState extends State<RecTVLivePage> {
  String _mainUrl = "https://a.prectv35.sbs";
  String _swKey = "4F5A9C3D9A86FA54EACEDDD635185/c3c5bd17-e37b-4b94-a944-8a3688a30452";
  
  List<Channel> _channels = [];
  bool _isLoading = false;
  Timer? _debounce;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchConfig();
    await _fetchAllChannels();
  }

  Future<void> _fetchAllChannels() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      List<Channel> allChannels = [];
      int page = 0;
      bool hasMore = true;

      while (hasMore) {
        final response = await http.get(
          Uri.parse('$_mainUrl/api/channel/by/filtres/0/0/$page/$_swKey/'),
          headers: {'user-agent': 'okhttp/4.12.0'},
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          if (data.isEmpty) {
            hasMore = false;
          } else {
            allChannels.addAll(data.map((item) => Channel.fromJson(item)).toList());
            page++;
          }
        } else {
          hasMore = false;
        }
      }

      if (mounted) {
        setState(() {
          _channels = allChannels;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching all channels: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchChannels(String query) async {
    _debounce?.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      setState(() => _isLoading = true);

      try {
        final response = await http.get(
          Uri.parse('$_mainUrl/api/search/$query/$_swKey/'),
          headers: {'user-agent': 'okhttp/4.12.0'},
        );

        if (response.statusCode == 200 && mounted) {
          final data = json.decode(response.body);
          final List<Channel> searchResults = [];
          
          if (data['channels'] != null) {
            searchResults.addAll(
              (data['channels'] as List).map((item) => Channel.fromJson(item))
            );
          }

          setState(() {
            _channels = searchResults;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error searching channels: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
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
        }
        
        if (swKeyMatch != null && swKeyMatch.group(1) != null) {
          newSwKey = swKeyMatch.group(1)!;
        }
        
        if (newMainUrl != null && newSwKey != null) {
          setState(() {
            _mainUrl = newMainUrl!;
            _swKey = newSwKey!;
          });
          
          _fetchAllChannels();
        }
      }
    } catch (e) {
      debugPrint('Error fetching config: $e');
      setState(() {
        _mainUrl = "https://m.prectv37.sbs";
      });
      _fetchAllChannels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (query) {
                if (query.length >= 3) {
                  _searchChannels(query);
                } else if (query.isEmpty) {
                  _fetchAllChannels();
                }
              },
              decoration: InputDecoration(
                hintText: 'Kanal Ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Kanallar yükleniyor...'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                itemCount: _channels.length,
                itemBuilder: (context, index) {
                  final channel = _channels[index];
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
                      onTap: () {
                        if (channel.sources.isNotEmpty) {
                          showDialog(
                            context: context,
                            builder: (context) => VideoPlayerDialog(
                              videoUrl: channel.sources.first.url,
                              title: channel.title,
                            ),
                          );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Image.network(
                              channel.image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                const Icon(HugeIcons.strokeRoundedImageNotFound01),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              channel.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
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
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
