import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SetupService {
  Shell shell = Shell();
  final String apiRepo = 'https://github.com/keyiflerolsun/KekikStreamAPI.git';
  
  Future<bool> isPythonInstalled() async {
    try {
      if (Platform.isWindows) {
        // Direkt Python'u çalıştırmayı dene
        var result = await Process.run('C:\\Python311\\python.exe', ['--version']);
        if (result.exitCode == 0) return true;
        
        // Eğer bulunamazsa PATH üzerinden dene
        result = await Process.run('python', ['--version']);
        return result.exitCode == 0;
      } else {
        var result = await Process.run('python3', ['--version']);
        return result.exitCode == 0;
      }
    } catch (e) {
      print('Python kontrol hatası: $e');
      return false;
    }
  }

  Future<void> waitForPythonInstallation() async {
    print('Python kurulumunun tamamlanması bekleniyor...');
    while (!await isPythonInstalled()) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    print('Python kurulumu tamamlandı!');
  }

  Future<void> installPython() async {
    if (Platform.isWindows) {
      try {
        final tempDir = await getTemporaryDirectory();
        final installer = '${tempDir.path}/python_installer.exe';
        final logFile = '${tempDir.path}/python_install.log';
        final pythonUrl = 'https://www.python.org/ftp/python/3.13.2/python-3.13.2-amd64.exe';
        
        print('Python indiriliyor...');
        final dio = Dio();
        await dio.download(pythonUrl, installer);
        
        print('Python kuruluyor...');
        var result = await Process.run(
          installer,
          [
            '/quiet',
            'InstallAllUsers=1',
            'TargetDir=C:\\Python311',
            'DefaultAllUsersTargetDir=C:\\Python311',
            'AssociateFiles=1',
            'PrependPath=1',
            'Include_doc=0',
            'Include_test=0',
            'Include_tcltk=0',
            'Include_launcher=0',
            'Include_debug=0',
            'Include_symbols=0',
            'Shortcuts=0',
            'CompileAll=1',
            '/log=${logFile}'
          ]
        );
        
        if (result.exitCode != 0) {
          final log = await File(logFile).readAsString();
          throw Exception('Python kurulumu başarısız oldu. Log: $log');
        }
        
        await File(installer).delete();
        
        // PATH'i yenile
        final sysEnv = await Process.run('cmd', ['/c', 'echo', '%PATH%']);
        final path = sysEnv.stdout.toString().trim();
        final newPath = '$path;C:\\Python311;C:\\Python311\\Scripts';
        
        await Process.run('setx', ['PATH', newPath]);
        print('Python kurulumu tamamlandı!');
        
        // Shell'i yeniden başlat
        shell = Shell(
          environment: {'PATH': newPath},
          throwOnError: true
        );

      } catch (e) {
        print('Python kurulum hatası: $e');
        rethrow;
      }
    } else if (Platform.isLinux) {
      shell = Shell();
      await shell.run('sudo apt-get update');
      await shell.run('sudo apt-get install -y python3 python3-pip');
    }
  }

  Future<bool> isGitInstalled() async {
    try {
      final result = await Process.run('git', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<void> installGit() async {
    if (Platform.isLinux) {
      try {
        print('Git yükleniyor...');
        await shell.run('sudo apt-get update');
        await shell.run('sudo apt-get install -y git');
        print('Git kurulumu tamamlandı!');
      } catch (e) {
        print('Git kurulum hatası: $e');
        rethrow;
      }
    }
  }

  Future<bool> checkApiUpdates(String localPath) async {
    try {
      print('API güncellemeleri kontrol ediliyor...');
      
      // Önce mevcut git reposunun remote origin hash'ini al
      var remoteResult = await Process.run('git', [
        'ls-remote',
        apiRepo,
        'HEAD'
      ]);
      
      if (remoteResult.exitCode != 0) {
        print('Remote hash alınamadı: ${remoteResult.stderr}');
        return true; // Hata durumunda güvenli tarafta kal, güncelleme yap
      }
      
      String remoteHash = remoteResult.stdout.toString().split('\t')[0];
      
      // Yerel git reposunun hash'ini al
      var localResult = await Process.run('git', [
        'rev-parse',
        'HEAD'
      ], workingDirectory: localPath);
      
      if (localResult.exitCode != 0) {
        print('Yerel hash alınamadı: ${localResult.stderr}');
        return true; // Hata durumunda güvenli tarafta kal, güncelleme yap
      }
      
      String localHash = localResult.stdout.toString().trim();
      
      bool needsUpdate = remoteHash != localHash;
      if (needsUpdate) {
        print('Yeni API güncellemesi mevcut!');
      } else {
        print('API güncel!');
      }
      
      return needsUpdate;
    } catch (e) {
      print('API güncelleme kontrolünde hata: $e');
      return true; // Hata durumunda güvenli tarafta kal, güncelleme yap
    }
  }

  Future<void> setupAPI() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final apiPath = '${appDir.path}/KekikStreamAPI';

      print('API kurulumu başlıyor...');
      print('Çalışma dizini: $apiPath');

      // Git kontrolü
      if (!await isGitInstalled()) {
        print('Git yüklü değil, yükleniyor...');
        await installGit();
      }

      bool shouldUpdate = true;

      // API klasörü kontrolü ve oluşturma
      final apiDir = Directory(apiPath);
      if (!await apiDir.exists()) {
        await apiDir.create(recursive: true);
      }

      // Eğer API klasörü varsa, güncelleme kontrolü yap
      if (await Directory('$apiPath/.git').exists()) {
        shouldUpdate = await checkApiUpdates(apiPath);
      }

      if (shouldUpdate) {
        // Önce çalışan Python işlemlerini sonlandır
        await killPythonProcesses();
        
        // Klasörü temizle
        if (await Directory(apiPath).exists()) {
          print('Eski API siliniyor...');
          await Directory(apiPath).delete(recursive: true);
          await Directory(apiPath).create(recursive: true);
        }
      
        print('GitHub\'dan API indiriliyor...');
        
        // Git clone işlemini shell üzerinden yap
        if (Platform.isLinux) {
          try {
            await shell.cd(appDir.path);
            await shell.run('git clone $apiRepo KekikStreamAPI');
          } catch (e) {
            print('Linux git clone hatası: $e');
            // Alternatif yöntem dene
            var result = await Process.run('git', 
              ['clone', apiRepo, apiPath],
              workingDirectory: appDir.path,
              runInShell: true
            );
            if (result.exitCode != 0) {
              throw Exception('Git clone hatası: ${result.stderr}');
            }
          }
        } else {
          var result = await Process.run('git', ['clone', apiRepo, apiPath]);
          if (result.exitCode != 0) {
            throw Exception('Git clone hatası: ${result.stderr}');
          }
        }

        print('API indirildi: $apiPath');

        // Python paketlerini kur
        final pythonPath = Platform.isWindows ? 'C:\\Python311\\python.exe' : 'python3';
        final pipPath = Platform.isWindows ? 'C:\\Python311\\Scripts\\pip.exe' : 'pip3';

        print('Python paketleri kuruluyor...');
        
        if (Platform.isLinux) {
          try {
            await shell.cd(apiPath);
            // pip yüklü değilse yükle
            await shell.run('sudo apt-get install -y python3-pip');
            // requirements.txt dosyasını kontrol et
            if (await File('$apiPath/requirements.txt').exists()) {
              await shell.run('pip3 install --user -r requirements.txt');
            } else {
              throw Exception('requirements.txt dosyası bulunamadı');
            }
          } catch (e) {
            print('Linux paket kurulum hatası: $e');
            rethrow;
          }
        } else {
          // Windows için mevcut kod
          if (Platform.isWindows) {
            // Önce pip'i güncelleyelim
            var result = await Process.run(pythonPath, ['-m', 'ensurepip', '--upgrade']);
            if (result.exitCode != 0) {
              throw Exception('Pip yükseltme hatası: ${result.stderr}');
            }
  
            result = await Process.run(pythonPath, ['-m', 'pip', 'install', '--upgrade', 'pip']);
            if (result.exitCode != 0) {
              throw Exception('Pip yükseltme hatası: ${result.stderr}');
            }
  
            // requirements.txt dosyasının varlığını kontrol et
            final requirementsFile = File('$apiPath/requirements.txt');
            if (!await requirementsFile.exists()) {
              throw Exception('requirements.txt dosyası bulunamadı: ${requirementsFile.path}');
            }
  
            // Paketleri kur
            result = await Process.run(
              pipPath,
              ['install', '-r', 'requirements.txt'],
              workingDirectory: apiPath,
              runInShell: true
            );
            
            if (result.exitCode != 0) {
              throw Exception('Paket kurulum hatası: ${result.stderr}');
            }
          }
        }
        
        print('API kurulumu tamamlandı!');
      } else {
        print('API zaten güncel, kurulum atlanıyor.');
      }

    } catch (e) {
      print('API kurulumunda hata: $e');
      rethrow;
    }
  }

  Future<void> addFirewallRule() async {
    if (Platform.isWindows) {
      try {
        print('Güvenlik duvarı kuralı ekleniyor...');
        
        // Python için kural ekle
        await Process.run('powershell', [
          '-Command',
          'New-NetFirewallRule -DisplayName "Python-3.11" -Direction Inbound -Program "C:\\Python311\\python.exe" -Action Allow -ErrorAction SilentlyContinue'
        ], runInShell: true);

        // Port için kural ekle
        await Process.run('powershell', [
          '-Command',
          'New-NetFirewallRule -DisplayName "KekikStreamAPI" -Direction Inbound -LocalPort 3310 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue'
        ], runInShell: true);

        print('Güvenlik duvarı kuralları eklendi.');
      } catch (e) {
        print('Güvenlik duvarı kuralı eklenirken hata: $e');
      }
    }
  }

  Future<void> killPythonProcesses() async {
    if (Platform.isWindows) {
      try {
        print('Python işlemleri sonlandırılıyor...');
        
        // Python işlemlerini daha agresif şekilde sonlandır
        final commands = [
          'taskkill /F /IM python.exe',
          'taskkill /F /IM pythonw.exe',
          'taskkill /F /IM py.exe'
        ];

        for (final command in commands) {
          try {
            await Process.run('cmd', ['/c', command]);
          } catch (e) {
            print('Komut çalıştırma hatası ($command): $e');
          }
        }

        // Bir süre bekle
        await Future.delayed(Duration(seconds: 2));
        
      } catch (e) {
        print('Python işlemleri sonlandırılırken hata: $e');
      }
    }
  }

  Future<Process> startAPI() async {
    final appDir = await getApplicationDocumentsDirectory();
    final apiPath = '${appDir.path}/KekikStreamAPI';
    
    print('API başlatılıyor...');
    if (Platform.isWindows) {
      await killPythonProcesses();
      await addFirewallRule();

      final startupFile = File('$apiPath/basla.py');
      if (!await startupFile.exists()) {
        throw Exception('basla.py dosyası bulunamadı: ${startupFile.path}');
      }

      final env = Map<String, String>.from(Platform.environment);
      env['PYTHONIOENCODING'] = 'utf-8';
      env['PYTHONUTF8'] = '1';
      env['PYTHONLEGACYWINDOWSSTDIO'] = '0';

      final process = await Process.start(
        'C:\\Python311\\python.exe',
        ['basla.py'],
        workingDirectory: apiPath,
        environment: env,
        runInShell: true
      );

      process.stdout.transform(utf8.decoder).listen(
        (data) => print('API Çıktısı: $data'),
        onError: (error) => print('API Çıktı Hatası: $error')
      );

      process.stderr.transform(utf8.decoder).listen(
        (data) => print('API Hatası: $data'),
        onError: (error) => print('API Hata Çıktısı Hatası: $error')
      );

      return process;
    } else {
      return await Process.start(
        'python3',
        ['basla.py'],
        workingDirectory: apiPath,
      );
    }
  }
}
