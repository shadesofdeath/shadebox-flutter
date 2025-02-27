import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/mediafire_extractor.dart';
import 'dart:convert';

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  final String title;
  final bool isLiveStream;
  final String? userAgent;
  final String? referer;

  const VideoPlayerDialog({
    Key? key,
    required this.videoUrl,
    required this.title,
    this.isLiveStream = false,
    this.userAgent,
    this.referer,
  }) : super(key: key);

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late final player = Player();
  late final controller = VideoController(player);
  
  // Track selection state
  List<VideoTrack> videoTracks = [];
  List<AudioTrack> audioTracks = [];
  List<SubtitleTrack> subtitleTracks = [];
  
  SubtitleViewConfiguration _subtitleConfig = const SubtitleViewConfiguration(
    style: TextStyle(
      height: 1.4,
      fontSize: 24.0,
      letterSpacing: 0.0,
      wordSpacing: 0.0,
      color: Color(0xffffffff),
      fontWeight: FontWeight.normal,
      backgroundColor: Color(0xaa000000),
    ),
    textAlign: TextAlign.center,
    padding: EdgeInsets.all(24.0),
  );

  // Video pozisyonları için yeni değişkenler
  static const String _videoPositionsKey = 'video_positions';
  static const int _maxSavedVideos = 200;
  bool _isVideoLoaded = false;
  bool _isVideoReady = false;
  Duration? _pendingSeek;
  bool _manuallySeekPerformed = false; // Yeni eklenen flag
  bool _initialPositionChecked = false; // Yeni eklenen flag

  // Uyku zamanlayıcısı için yeni değişkenler
  Timer? _sleepTimer;
  Duration? _remainingTime;
  Timer? _remainingTimeTimer;
  String _sleepAction = 'pause'; // 'pause' veya 'close'

  // Kontrollerin görünürlüğü için yeni değişkenler
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _setupTrackListeners();
    _loadSavedSubtitleSettings(); // Kayıtlı ayarları yükle
    // Mouse hareketi için listener ekle
    _startHideControlsTimer();
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

      final headers = <String, String>{};
      if (widget.userAgent != null) {
        headers['User-Agent'] = widget.userAgent!;
      }
      if (widget.referer != null) {
        headers['Referer'] = widget.referer!;
      }

      await player.open(
        Media(videoUrl, httpHeaders: headers),
        play: true, // Başlangıçta otomatik oynat
      );

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

      setState(() => _isVideoReady = true);

      // Eğer manuel ilerleme yapılmamışsa ve ilk pozisyon kontrolü yapılmamışsa
      if (!_manuallySeekPerformed && !_initialPositionChecked && !widget.isLiveStream && mounted) {
        _initialPositionChecked = true; // İlk kontrol yapıldı
        final savedPosition = await _getSavedPosition(widget.videoUrl);
        if (savedPosition != null) {
          final shouldResume = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Kaldığın Yerden Devam Et'),
              content: Text(
                'Bu videoyu en son ${_formatDuration(savedPosition)} konumunda bırakmıştınız. '
                'Kaldığınız yerden devam etmek ister misiniz?'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Hayır'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Evet'),
                ),
              ],
            ),
          ) ?? false;

          if (shouldResume && mounted) {
            _manuallySeekPerformed = true; // Seek işlemi yapılacak
            await player.seek(savedPosition);
          }
        }
      }

    } catch (e) {
      debugPrint('Video yüklenirken hata: $e');
    }
  }

  void _setupTrackListeners() {
    player.stream.tracks.listen((tracks) {
      setState(() {
        videoTracks = tracks.video;
        audioTracks = tracks.audio;
        subtitleTracks = tracks.subtitle;
      });
    });

    // Video yüklenme durumunu dinle
    player.stream.playing.listen((playing) {
      if (playing && !_isVideoLoaded) {
        setState(() => _isVideoLoaded = true);
      }
    });

    // Video hazır olma durumunu dinle
    player.stream.completed.listen((completed) {
      if (!_isVideoReady) {
        setState(() => _isVideoReady = true);
        _applyPendingSeek();
      }
    });

    // Hata durumunu dinle
    player.stream.error.listen((error) {
      debugPrint('Video yükleme hatası: $error');
    });

    // Video konumunu dinle ve manuel ilerleme durumunu kontrol et
    player.stream.position.listen((position) {
      if (player.state.playing && !_manuallySeekPerformed) {
        _manuallySeekPerformed = position.inSeconds > 1; // Kullanıcı manuel ilerletti
      }
      setState(() {
        // UI'yi güncelle
      });
    });
  }

  // Bekleyen konumu uygulayan yeni metod
  Future<void> _applyPendingSeek() async {
    if (_pendingSeek != null) {
      try {
        await player.pause();
        await player.seek(_pendingSeek!);
        // Seeking işleminin tamamlanmasını bekle
        await Future.delayed(const Duration(seconds: 1));
        _pendingSeek = null;
        if (mounted) {
          await player.play();
        }
      } catch (e) {
        debugPrint('Konum değiştirme hatası: $e');
      }
    }
  }

  Future<void> _showSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayarlar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.track_changes),
                title: const Text('Parça Seçimi'),
                onTap: () {
                  Navigator.pop(context);
                  _showTrackSelectionDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.subtitles),
                title: const Text('Altyazı Ayarları'),
                onTap: () {
                  Navigator.pop(context);
                  _showSubtitleSettingsDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.keyboard),
                title: const Text('Klavye Kısayolları'),
                onTap: () {
                  Navigator.pop(context);
                  _showShortcutsDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime),
                title: const Text('Uyku Zamanlayıcısı'),
                onTap: () {
                  Navigator.pop(context);
                  _showSleepTimerDialog();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTrackSelectionDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Parça Seçimi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTrackSelector('Video Parçası', videoTracks, (track) => 
              player.setVideoTrack(track as VideoTrack)),
            _buildTrackSelector('Ses Parçası', audioTracks, (track) => 
              player.setAudioTrack(track as AudioTrack)),
            _buildTrackSelector('Altyazı', subtitleTracks, (track) => 
              player.setSubtitleTrack(track as SubtitleTrack)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSubtitleSettingsDialog() async {
    Color textColor = _subtitleConfig.style?.color ?? Colors.white;
    Color bgColor = _subtitleConfig.style?.backgroundColor ?? const Color(0xaa000000);
    double fontSize = _subtitleConfig.style?.fontSize ?? 24.0;
    double letterSpacing = _subtitleConfig.style?.letterSpacing ?? 0.0;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Altyazı Ayarları'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Yazı Boyutu
                const Text('Yazı Boyutu', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        if (fontSize > 12) {
                          setState(() => fontSize -= 2);
                          _updateSubtitleConfig(fontSize: fontSize);
                        }
                      },
                    ),
                    Text('${fontSize.round()}', style: const TextStyle(fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (fontSize < 160) {
                          setState(() => fontSize += 2);
                          _updateSubtitleConfig(fontSize: fontSize);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Harf Aralığı
                const Text('Harf Aralığı', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        if (letterSpacing > -2) {
                          setState(() => letterSpacing -= 0.5);
                          _updateSubtitleConfig(letterSpacing: letterSpacing);
                        }
                      },
                    ),
                    Text('${letterSpacing.toStringAsFixed(1)}', style: const TextStyle(fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (letterSpacing < 2) {
                          setState(() => letterSpacing += 0.5);
                          _updateSubtitleConfig(letterSpacing: letterSpacing);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildColorSettingTile(
                  'Yazı Rengi',
                  textColor,
                  (color) {
                    setState(() => textColor = color);
                    _updateSubtitleConfig(textColor: color);
                  },
                ),
                _buildColorSettingTile(
                  'Arka Plan Rengi',
                  bgColor,
                  (color) {
                    setState(() => bgColor = color);
                    _updateSubtitleConfig(backgroundColor: color);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateSubtitleConfig({
    double? fontSize,
    double? letterSpacing,
    Color? textColor,
    Color? backgroundColor,
  }) {
    setState(() {
      _subtitleConfig = SubtitleViewConfiguration(
        style: TextStyle(
          fontSize: fontSize ?? _subtitleConfig.style?.fontSize,
          letterSpacing: letterSpacing ?? _subtitleConfig.style?.letterSpacing,
          color: textColor ?? _subtitleConfig.style?.color,
          backgroundColor: backgroundColor ?? _subtitleConfig.style?.backgroundColor,
          fontWeight: FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        padding: const EdgeInsets.all(24.0),
      );
    });

    // Ayarları kaydet
    _saveSubtitleSettings(
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      textColor: textColor,
      backgroundColor: backgroundColor,
    );
  }

  // Kayıtlı ayarları yüklemek için
  Future<void> _loadSavedSubtitleSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _subtitleConfig = SubtitleViewConfiguration(
        style: TextStyle(
          fontSize: prefs.getDouble('subtitle_font_size') ?? 24.0,
          letterSpacing: prefs.getDouble('subtitle_letter_spacing') ?? 0.0,
          color: Color(prefs.getInt('subtitle_text_color') ?? 0xFFFFFFFF),
          backgroundColor: Color(prefs.getInt('subtitle_bg_color') ?? 0xAA000000),
          fontWeight: FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        padding: const EdgeInsets.all(24.0),
      );
    });
  }

  // Ayarları kaydetmek için
  Future<void> _saveSubtitleSettings({
    double? fontSize,
    double? letterSpacing,
    Color? textColor,
    Color? backgroundColor,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (fontSize != null) {
      await prefs.setDouble('subtitle_font_size', fontSize);
    }
    if (letterSpacing != null) {
      await prefs.setDouble('subtitle_letter_spacing', letterSpacing);
    }
    if (textColor != null) {
      await prefs.setInt('subtitle_text_color', textColor.value);
    }
    if (backgroundColor != null) {
      await prefs.setInt('subtitle_bg_color', backgroundColor.value);
    }
  }

  // Video pozisyonlarını yönetme metodları
  Future<Duration?> _getSavedPosition(String videoUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final positionsJson = prefs.getString(_videoPositionsKey);
    if (positionsJson != null) {
      final positions = Map<String, int>.from(json.decode(positionsJson));
      final position = positions[videoUrl];
      return position != null ? Duration(milliseconds: position) : null;
    }
    return null;
  }

  Future<void> _savePosition(String videoUrl, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    final positionsJson = prefs.getString(_videoPositionsKey);
    final positions = positionsJson != null 
        ? Map<String, int>.from(json.decode(positionsJson))
        : <String, int>{};

    // Eski pozisyonları temizle (200'den fazlaysa)
    if (positions.length >= _maxSavedVideos) {
      final oldestKeys = positions.keys.toList()
        ..sort((a, b) => positions[a]!.compareTo(positions[b]!));
      for (var i = 0; i < positions.length - _maxSavedVideos + 1; i++) {
        positions.remove(oldestKeys[i]);
      }
    }

    // Yeni pozisyonu kaydet
    positions[videoUrl] = position.inMilliseconds;
    await prefs.setString(_videoPositionsKey, json.encode(positions));
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : '';
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours$minutes:$seconds';
  }

  Future<void> _showColorPicker(BuildContext context, Color currentColor, Function(Color) onColorChanged) async {
    final Color newColor = await showColorPickerDialog(
      context,
      currentColor,
      title: const Text('Renk Seçici'),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 0,
      wheelDiameter: 165,
      enableOpacity: true,
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: true,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        copyButton: true,
        pasteButton: true,
        longPressMenu: true,
      ),
      actionButtons: const ColorPickerActionButtons(
        okButton: true,
        closeButton: true,
        dialogActionButtons: true,
      ),
      constraints: const BoxConstraints(
        minHeight: 480,
        minWidth: 320,
        maxWidth: 320,
      ),
    );

    if (newColor != currentColor) {
      onColorChanged(newColor);
    }
  }

  Widget _buildColorPreview(Color color) {
    return ColorIndicator(
      width: 44,
      height: 44,
      borderRadius: 4,
      color: color,
      elevation: 1,
      onSelectFocus: false,
    );
  }

  Widget _buildColorSettingTile(String title, Color color, Function(Color) onColorChanged) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(ColorTools.nameThatColor(color)),
      trailing: _buildColorPreview(color),
      onTap: () => _showColorPicker(context, color, onColorChanged),
    );
  }

  Widget _buildTrackSelector(String label, List<dynamic> tracks, Function(dynamic) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<dynamic>(
          value: null,
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: null, child: Text('Otomatik')),
            ...tracks.map((track) => DropdownMenuItem(
              value: track,
              child: Text(_getTrackName(track)),
            )),
          ],
          onChanged: (track) {
            onSelect(track ?? (label.contains('Video') ? VideoTrack.auto() : 
                              label.contains('Ses') ? AudioTrack.auto() : 
                              SubtitleTrack.auto()));
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  String _getTrackName(dynamic track) {
    if (track.title != null && track.title.isNotEmpty) {
      return track.title;
    }
    if (track.language != null) {
      return _getLanguageName(track.language);
    }
    return 'Parça ${track.id}';
  }

  // Dil kodlarını insan tarafından okunabilir formata çeviren yardımcı fonksiyon
  String _getLanguageName(String? languageCode) {
    final Map<String, String> languageNames = {
      'tur': 'Türkçe',
      'tr': 'Türkçe',
      'eng': 'İngilizce',
      'en': 'İngilizce',
      'jpn': 'Japonca',
      'ja': 'Japonca',
      'ger': 'Almanca',
      'de': 'Almanca',
      'fra': 'Fransızca',
      'fr': 'Fransızca',
      'spa': 'İspanyolca',
      'es': 'İspanyolca',
      // Daha fazla dil eklenebilir
    };
    
    return languageNames[languageCode?.toLowerCase()] ?? languageCode ?? 'Bilinmeyen';
  }

  Future<void> _showShortcutsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Klavye Kısayolları'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shortcutItem('Boşluk', 'Oynat/Duraklat'),
              _shortcutItem('J', '10 saniye geri'),
              _shortcutItem('L', '10 saniye ileri'),
              _shortcutItem('Sol Ok', '2 saniye geri'),
              _shortcutItem('Sağ Ok', '2 saniye ileri'),
              _shortcutItem('Yukarı Ok', 'Ses +5%'),
              _shortcutItem('Aşağı Ok', 'Ses -5%'),
              _shortcutItem('F', 'Tam Ekran'),
              _shortcutItem('ESC', 'Tam Ekrandan Çık'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _shortcutItem(String key, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Text(description),
        ],
      ),
    );
  }

  Future<void> _showSleepTimerDialog() async {
    int selectedMinutes = 30;
    String selectedAction = _sleepTimer != null ? _sleepAction : 'pause';
    final customTimeController = TextEditingController();
    final List<int> defaultTimes = [5, 10, 15, 30, 45, 60, 90, 120];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Uyku Zamanlayıcısı'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_sleepTimer != null) ...[
                  Text(
                    'Kalan Süre: ${_formatDuration(_remainingTime ?? Duration.zero)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _cancelSleepTimer();
                      Navigator.pop(context);
                    },
                    child: const Text('Zamanlayıcıyı İptal Et'),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                ],
                const Text('Süre Seç:'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: defaultTimes.contains(selectedMinutes) ? selectedMinutes : null,
                        isExpanded: true,
                        hint: Text(defaultTimes.contains(selectedMinutes) 
                            ? '$selectedMinutes dakika' 
                            : '${selectedMinutes.toString()} dakika (özel)'),
                        items: [
                          ...defaultTimes.map((minutes) => DropdownMenuItem(
                                value: minutes,
                                child: Text('$minutes dakika'),
                              )),
                          const DropdownMenuItem(
                            value: -1, // Özel süre için özel bir değer
                            child: Text('Özel süre...'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == -1) {
                            // Özel süre dialog'unu göster
                            final customMinutes = await _showCustomTimeDialog(
                                context, customTimeController);
                            if (customMinutes != null) {
                              setState(() => selectedMinutes = customMinutes);
                            }
                          } else if (value != null) {
                            setState(() => selectedMinutes = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Zamanlayıcı Dolduğunda:'),
                RadioListTile<String>(
                  title: const Text('Videoyu Duraklat'),
                  value: 'pause',
                  groupValue: selectedAction,
                  onChanged: (value) {
                    setState(() => selectedAction = value!);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Uygulamayı Kapat'),
                  value: 'close',
                  groupValue: selectedAction,
                  onChanged: (value) {
                    setState(() => selectedAction = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startSleepTimer(Duration(minutes: selectedMinutes), selectedAction);
              },
              child: const Text('Başlat'),
            ),
          ],
        ),
      ),
    );
  }

  Future<int?> _showCustomTimeDialog(BuildContext context, TextEditingController controller) async {
    controller.clear();
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Özel Süre'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Dakika',
            hintText: 'Örn: 25',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0) {
                Navigator.pop(context, minutes);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lütfen 1 veya daha büyük bir sayı giriniz'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _cancelSleepTimer() {
    if (_sleepTimer != null) {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      _remainingTimeTimer?.cancel();
      _remainingTime = null;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uyku zamanlayıcısı iptal edildi'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startSleepTimer(Duration duration, String action) {
    _cancelSleepTimer(); // Cancel existing timer if any
    _sleepAction = action;
    _remainingTime = duration;
    
    _sleepTimer = Timer(duration, () {
      if (action == 'pause') {
        player.pause();
      } else if (action == 'close') {
        Navigator.of(context).pop();
      }
    });

    // Update remaining time display
    _remainingTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime != null) {
        setState(() {
          _remainingTime = _remainingTime! - const Duration(seconds: 1);
          if (_remainingTime!.inSeconds <= 0) {
            _cancelSleepTimer();
          }
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Uyku zamanlayıcısı ${duration.inMinutes} dakika olarak ayarlandı'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _handleMouseMove() {
    setState(() => _showControls = true);
    _startHideControlsTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: MouseRegion(
        onHover: (_) => _handleMouseMove(),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Video player
              Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      child: Video(
                        controller: controller,
                        subtitleViewConfiguration: _subtitleConfig,
                      ),
                    ),
                  ),
                ],
              ),
              // Kontrol paneli
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
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
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: _showSettingsDialog,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _sleepTimer?.cancel();
    _remainingTimeTimer?.cancel();
    if (!widget.isLiveStream) {
      // Video pozisyonunu kaydet
      _savePosition(widget.videoUrl, player.state.position);
    }
    player.dispose();
    super.dispose();
  }
}
