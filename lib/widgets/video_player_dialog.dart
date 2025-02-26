import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/mediafire_extractor.dart';
import 'package:crypto/crypto.dart';

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
  bool showControls = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _loadSubtitleFontSize();
    _checkLastPosition();
  }

  Future<void> _loadSubtitleFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      subtitleFontSize = prefs.getDouble('subtitleFontSize') ?? 32.0;
    });
  }

  Future<void> _saveSubtitleFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('subtitleFontSize', size);
  }

  // Başlıktan benzersiz ID oluşturan yardımcı fonksiyon
  String _generateVideoId(String title) {
    var bytes = utf8.encode(title); // String'i byte dizisine çevir
    var digest = sha256.convert(bytes); // SHA256 hash oluştur
    return digest.toString().substring(0, 16); // İlk 16 karakteri al
  }

  Future<void> _checkLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final String? videoPositions = prefs.getString('videoPositions');
    final String videoId = _generateVideoId(widget.title);
    
    if (videoPositions != null) {
      final Map<String, dynamic> positions = json.decode(videoPositions);
      final double? lastPosition = positions[videoId]?.toDouble();
      
      if (lastPosition != null && lastPosition > 0) {
        if (!mounted) return;
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Kaldığınız yerden devam et'),
            content: Text('${widget.title}\n\nBu videoyu ${Duration(seconds: lastPosition.toInt()).toString().split('.').first} kaldınız. Devam etmek ister misiniz?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _initializePlayer();
                },
                child: const Text('Baştan Başla'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _initializePlayer(startPosition: lastPosition);
                },
                child: const Text('Devam Et'),
              ),
            ],
          ),
        );
      } else {
        _initializePlayer();
      }
    } else {
      _initializePlayer();
    }
  }

  Future<void> _saveVideoPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final String? videoPositions = prefs.getString('videoPositions');
    final Map<String, dynamic> positions = videoPositions != null 
        ? json.decode(videoPositions) 
        : {};
    
    final String videoId = _generateVideoId(widget.title);
    positions[videoId] = await player.state.position.inSeconds;
    
    // Son 100 video pozisyonunu tut (isteğe bağlı)
    if (positions.length > 100) {
      final List<String> keys = positions.keys.toList();
      keys.sort((a, b) => (positions[a] as num).compareTo(positions[b] as num));
      positions.remove(keys.first);
    }
    
    await prefs.setString('videoPositions', json.encode(positions));
  }

  Future<void> _initializePlayer({double? startPosition}) async {
    try {
      String videoUrl = widget.videoUrl;
      if (MediafireExtractor.isMediafireUrl(videoUrl)) {
        final directUrl = await MediafireExtractor.extractDirectUrl(videoUrl);
        if (directUrl != null) {
          videoUrl = directUrl;
        } else {
          throw Exception('Failed to extract Mediafire URL');
        }
      }

      // Önce videoyu aç
      await player.open(Media(videoUrl));
      
      // Video hazır olana kadar bekle
      await Future.wait([
        player.stream.playing.first,
        player.stream.completed.first,
        player.stream.width.firstWhere((width) => width != null && width > 0),
        player.stream.height.firstWhere((height) => height != null && height > 0),
      ]).timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('Video yükleme zaman aşımına uğradı');
        return [];
      });

      if (startPosition != null && startPosition > 0) {
        // Video yüklendikten sonra pozisyona git
        await player.pause();
        await player.seek(Duration(seconds: startPosition.toInt()));
        
        // Seeking işleminin tamamlanmasını bekle
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          await player.play();
        }
      }
    } catch (e) {
      debugPrint('Video yüklenirken hata: $e');
    }
  }

  void _handleMouseMove() {
    setState(() => showControls = true);
    
    // Mevcut zamanlayıcıyı iptal et
    _hideTimer?.cancel();
    
    // 3 saniye sonra kontrolleri gizleyecek yeni bir zamanlayıcı başlat
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => showControls = false);
      }
    });
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
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Video(
                  controller: controller,
                  controls: (state) => MouseRegion(
                    onHover: (_) => _handleMouseMove(),
                    onExit: (_) => setState(() => showControls = false),
                    child: Stack(
                      children: [
                        AdaptiveVideoControls(state),
                        if (showControls) // state.showControls yerine kendi değişkenimizi kullanıyoruz
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: StreamBuilder(
                                stream: player.stream.tracks,
                                builder: (context, snapshot) {
                                  final audioTracks = player.state.tracks.audio;
                                  final subtitleTracks = player.state.tracks.subtitle;
                                  final videoTracks = player.state.tracks.video;

                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                                          _saveSubtitleFontSize(value); // Yeni değeri kaydet
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
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
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
    _saveVideoPosition(); // Video pozisyonunu kaydet
    _hideTimer?.cancel(); // Timer'ı temizle
    player.dispose();
    super.dispose();
  }
}
