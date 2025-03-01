import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class M3U8Downloader {
  static Future<List<String>> extractSegmentUrls(String m3u8Url) async {
    final response = await http.get(Uri.parse(m3u8Url));
    if (response.statusCode != 200) throw Exception('Failed to load m3u8');

    final lines = response.body.split('\n');
    final segments = <String>[];
    final baseUrl = m3u8Url.substring(0, m3u8Url.lastIndexOf('/') + 1);

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      
      if (line.startsWith('http')) {
        segments.add(line);
      } else {
        segments.add(baseUrl + line);
      }
    }

    return segments;
  }

  static Future<void> downloadSegments({
    required String m3u8Url,
    required String outputPath,
    required Function(double) onProgress,
    required Function(String, String, String) onStatus, // Değiştirildi: İndirme boyutu bilgisi için
  }) async {
    try {
      onStatus('M3U8 dosyası analiz ediliyor...', '0 MB', '0 MB');
      final segments = await extractSegmentUrls(m3u8Url);
      
      if (segments.isEmpty) {
        throw Exception('No segments found in m3u8');
      }

      // Klasör adını düzelt - sadece film adını kullan
      final fileName = path.basenameWithoutExtension(outputPath);
      final tempDir = Directory(path.join(path.dirname(outputPath), fileName));
      await tempDir.create(recursive: true);

      onStatus('Parçalar indiriliyor...', '0 MB', '0 MB');
      final totalSegments = segments.length;
      int downloadedSegments = 0;
      int totalBytes = 0;
      DateTime startTime = DateTime.now();

      final List<File> segmentFiles = [];

      for (var i = 0; i < segments.length; i++) {
        final segmentUrl = segments[i];
        final segmentFile = File(path.join(tempDir.path, 'segment_$i.ts'));
        
        final response = await http.get(
          Uri.parse(segmentUrl),
          headers: {
            'User-Agent': 'googleusercontent',
            'Referer': 'https://twitter.com/',
          },
        );

        final bytes = response.bodyBytes;
        totalBytes += bytes.length;
        await segmentFile.writeAsBytes(bytes);
        segmentFiles.add(segmentFile);
        
        downloadedSegments++;
        
        // İndirme hızı ve boyut hesaplama
        final duration = DateTime.now().difference(startTime).inSeconds;
        if (duration > 0) {
          final speed = totalBytes / duration;
          final downloadedSize = _formatSize(totalBytes);
          final speedText = _formatSpeed(speed);
          
          onStatus(
            'İndiriliyor... ${(downloadedSegments / totalSegments * 100).toStringAsFixed(1)}% ($speedText)',
            downloadedSize,
            'Bilinmiyor'
          );
        }
        
        onProgress(downloadedSegments / totalSegments);
      }

      onStatus('Parçalar birleştiriliyor...', _formatSize(totalBytes), _formatSize(totalBytes));

      // Parçaları birleştir
      final outputFile = File(outputPath);
      final sink = outputFile.openWrite();
      
      for (var file in segmentFiles) {
        await sink.addStream(file.openRead());
      }
      
      await sink.close();

      // Temizlik
      for (var file in segmentFiles) {
        await file.delete();
      }
      await tempDir.delete();

      onStatus('İndirme tamamlandı', _formatSize(totalBytes), _formatSize(totalBytes));
    } catch (e) {
      debugPrint('M3U8 download error: $e');
      rethrow;
    }
  }

  static String _formatSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    
    while (size > 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  static String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(1)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }
}
