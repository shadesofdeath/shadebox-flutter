import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/video_player_dialog.dart';
import 'package:hugeicons/hugeicons.dart';

class TVChannel {
  final String name;
  final String logo;
  final String group;
  final String url;
  final String language;
  final String? userAgent;    // Yeni eklenen
  final String? referer;      // Yeni eklenen

  TVChannel({
    required this.name,
    required this.logo,
    required this.group,
    required this.url,
    required this.language,
    this.userAgent,           // Yeni eklenen
    this.referer,            // Yeni eklenen
  });
}

class SinewixTVPage extends StatefulWidget {
  const SinewixTVPage({super.key});

  @override
  State<SinewixTVPage> createState() => _SinewixTVPageState();
}

class _SinewixTVPageState extends State<SinewixTVPage> {
  List<TVChannel> _channels = [];
  List<TVChannel> _filteredChannels = [];
  List<String> _groups = [];
  String? _selectedGroup;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchChannels();
  }

  Future<void> _fetchChannels() async {
    try {
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/keyiflerolsun/IPTV_YenirMi/main/Kanallar/KekikAkademi.m3u'));

      if (response.statusCode == 200) {
        final List<TVChannel> channels = [];
        final Set<String> groups = {};
        
        final lines = response.body.split('\n');
        String currentName = '';
        String currentLogo = '';
        String currentGroup = '';
        String currentUrl = '';
        String currentLanguage = '';
        String? currentUserAgent;    // Yeni eklenen
        String? currentReferer;      // Yeni eklenen

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          
          if (line.startsWith('#EXTINF')) {
            final info = line.split(',');
            if (info.length > 1) {
              currentName = info[1].trim();
              
              final logoMatch = RegExp(r'tvg-logo="([^"]+)"').firstMatch(line);
              currentLogo = logoMatch?.group(1) ?? '';
              
              final groupMatch = RegExp(r'group-title="([^"]+)"').firstMatch(line);
              currentGroup = groupMatch?.group(1) ?? '';
              
              final langMatch = RegExp(r'tvg-language="([^"]+)"').firstMatch(line);
              currentLanguage = langMatch?.group(1) ?? '';
              
              if (currentGroup.isNotEmpty) {
                groups.add(currentGroup);
              }

              // User-Agent ve Referer değerlerini kontrol et
              currentUserAgent = null;
              currentReferer = null;
              
              // Sonraki satırları kontrol et
              var nextIndex = i + 1;
              while (nextIndex < lines.length && lines[nextIndex].startsWith('#EXTVLCOPT:')) {
                final optLine = lines[nextIndex].trim();
                if (optLine.contains('http-user-agent=')) {
                  currentUserAgent = optLine.split('=')[1];
                } else if (optLine.contains('http-referrer=')) {
                  currentReferer = optLine.split('=')[1];
                }
                nextIndex++;
                i = nextIndex - 1; // Ana döngü indexini güncelle
              }
            }
          } else if (line.startsWith('http')) {
            currentUrl = line;
            if (currentUrl.isNotEmpty && currentName.isNotEmpty) {
              channels.add(TVChannel(
                name: currentName,
                logo: currentLogo,
                group: currentGroup,
                url: currentUrl,
                language: currentLanguage,
                userAgent: currentUserAgent,  // Yeni eklenen
                referer: currentReferer,      // Yeni eklenen
              ));
            }
          }
        }

        setState(() {
          _channels = channels;
          _filteredChannels = channels;
          _groups = groups.toList()..sort();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterChannels(String query) {
    setState(() {
      _filteredChannels = _channels.where((channel) {
        final matchesSearch = channel.name.toLowerCase().contains(query.toLowerCase());
        final matchesGroup = _selectedGroup == null || channel.group == _selectedGroup;
        return matchesSearch && matchesGroup;
      }).toList();
    });
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
                    onChanged: _filterChannels,
                    decoration: InputDecoration(
                      hintText: 'Kanal Ara...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGroup,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    hint: const Text('Tüm Kanallar'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tüm Kanallar')),
                      ..._groups.map((group) => DropdownMenuItem(
                            value: group,
                            child: Text(group),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedGroup = value;
                        _filterChannels(_searchController.text);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredChannels.length,
                    itemBuilder: (context, index) {
                      final channel = _filteredChannels[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context, 
                              builder: (context) => VideoPlayerDialog(
                                videoUrl: channel.url,
                                title: channel.name,
                                isLiveStream: true,
                                userAgent: channel.userAgent,    // Yeni eklenen
                                referer: channel.referer,        // Yeni eklenen
                              ),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: channel.logo.isNotEmpty
                                      ? Image.network(
                                          channel.logo,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) => const Icon(
                                            HugeIcons.strokeRoundedTvSmart,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            );
                                          },
                                        )
                                      : const Icon(
                                          HugeIcons.strokeRoundedTv01,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  channel.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
    _searchController.dispose();
    super.dispose();
  }
}
