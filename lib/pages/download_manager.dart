import 'dart:io';
import 'package:ShadeBox/utils/mediafire_extractor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  canceled
}

class DownloadTask {
  final String url;
  final String fileName;
  final String savePath;
  double progress;
  String status;
  String speed;
  String downloadedSize;
  String totalSize;
  DownloadStatus downloadStatus;
  CancelToken cancelToken;
  
  DownloadTask({
    required this.url,
    required this.fileName,
    required this.savePath,
    this.progress = 0,
    this.status = 'Kuyrukta',
    this.speed = '0 KB/s',
    this.downloadedSize = '0 MB',
    this.totalSize = '0 MB',
    this.downloadStatus = DownloadStatus.queued,
  }) : cancelToken = CancelToken();
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final List<DownloadTask> downloads = [];
  final _dio = Dio();
  final downloadListeners = <VoidCallback>[];

  void addListener(VoidCallback listener) {
    downloadListeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    downloadListeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in downloadListeners) {
      listener();
    }
  }

  Future<void> startDownload(String url, String fileName, String savePath) async {
    final task = DownloadTask(
      url: url,
      fileName: fileName,
      savePath: savePath,
    );
    
    downloads.add(task);
    _notifyListeners();

    try {
      task.downloadStatus = DownloadStatus.downloading;
      task.status = 'İndirme başlatılıyor...';
      _notifyListeners();

      // Mediafire link kontrolü ekle
      String downloadUrl = url;
      if (MediafireExtractor.isMediafireUrl(url)) {
        task.status = 'Mediafire linki çözümleniyor...';
        _notifyListeners();
        
        final directUrl = await MediafireExtractor.extractDirectUrl(url);
        if (directUrl != null) {
          downloadUrl = directUrl;
        } else {
          task.downloadStatus = DownloadStatus.failed;
          task.status = 'Mediafire linki çözümlenemedi';
          _notifyListeners();
          return;
        }
      }

      final response = await _dio.get(
        downloadUrl, // url yerine downloadUrl kullan
        cancelToken: task.cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      final file = File(savePath);
      final sink = file.openWrite();

      int received = 0;
      int total = int.parse(response.headers.value('content-length') ?? '-1');
      DateTime lastUpdateTime = DateTime.now();
      int lastBytes = 0;

      await for (final chunk in response.data.stream) {
        if (task.cancelToken.isCancelled) break;
        
        sink.add(chunk);
        received += (chunk.length as int); // chunk.length'i int'e cast et

        final now = DateTime.now();
        final duration = now.difference(lastUpdateTime);
        
        if (duration.inMilliseconds >= 500) { // Update every 500ms
          final speed = (received - lastBytes) / duration.inSeconds;
          
          task.progress = total != -1 ? received / total : 0;
          task.downloadedSize = _formatSize(received);
          task.totalSize = total != -1 ? _formatSize(total) : 'Unknown';
          task.speed = _formatSpeed(speed);
          task.status = 'İndiriliyor... ${(task.progress * 100).toStringAsFixed(1)}%';
          
          lastUpdateTime = now;
          lastBytes = received;
          _notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();

      if (!task.cancelToken.isCancelled) {
        task.downloadStatus = DownloadStatus.completed;
        task.status = 'Tamamlandı';
        task.progress = 1.0;
      } else {
        task.downloadStatus = DownloadStatus.canceled;
        task.status = 'İptal edildi';
        await file.delete();
      }

    } catch (e) {
      task.downloadStatus = DownloadStatus.failed;
      task.status = 'Hata: ${e.toString()}';
    } finally {
      _notifyListeners();
    }
  }

  Future<void> cancelAndDeleteDownload(DownloadTask task) async {
    // Önce indirmeyi iptal et
    task.cancelToken.cancel();
    task.downloadStatus = DownloadStatus.canceled;
    task.status = 'İptal edildi';
    
    try {
      // Dosyayı ve olası kısmi indirmeleri sil
      final file = File(task.savePath);
      final tempFile = File('${task.savePath}.part');
      
      // Ana dosyayı sil
      if (await file.exists()) {
        await file.delete();
      }
      
      // Kısmi indirme dosyasını sil
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      // Diğer olası artık dosyaları kontrol et ve sil
      final directory = file.parent;
      final baseName = file.uri.pathSegments.last;
      final files = directory.listSync();
      
      for (var entity in files) {
        if (entity is File && entity.uri.pathSegments.last.startsWith(baseName)) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('Dosya silinirken hata: $e');
    }
    
    // Listeden kaldır
    downloads.remove(task);
    _notifyListeners();
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

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(1)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }
}
