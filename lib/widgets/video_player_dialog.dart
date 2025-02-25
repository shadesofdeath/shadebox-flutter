import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../utils/mediafire_extractor.dart';

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
      String videoUrl = widget.videoUrl;
      if (MediafireExtractor.isMediafireUrl(videoUrl)) {
        final directUrl = await MediafireExtractor.extractDirectUrl(videoUrl);
        if (directUrl != null) {
          videoUrl = directUrl;
        } else {
          throw Exception('Failed to extract Mediafire URL');
        }
      }
      await player.open(Media(videoUrl));
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
