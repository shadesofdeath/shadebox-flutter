import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SetupService {
  Shell? shell;
  final String apiRepo = 'https://github.com/keyiflerolsun/KekikStreamAPI.git';
  
  Future<Shell> initializeShell() async {
    if (Platform.isLinux) {
      // pkexec veya gksudo kontrolü
      final hasPkexec = await _checkCommand('pkexec');
      final hasGksudo = await _checkCommand('gksudo');
      
      if (hasPkexec || hasGksudo) {
        shell = Shell(runInShell: true, commandVerbose: true);
      } else {
        // Yetki yöneticisi yoksa kur
        try {
          print('Yetki yöneticisi kuruluyor...');
          final tempShell = Shell(runInShell: true);
          await tempShell.run('sudo apt-get update');
          await tempShell.run('sudo apt-get install -y pkexec');
          shell = Shell(runInShell: true, commandVerbose: true);
        } catch (e) {
          print('Yetki yöneticisi kurulum hatası: $e');
          rethrow;
        }
      }
    } else {
      shell = Shell();
    }
    return shell!;
  }

  Future<bool> _checkCommand(String command) async {
    try {
      final result = await Process.run('which', [command]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<void> setupLinuxDependencies() async {
    if (!Platform.isLinux) return;

    try {
      print('Linux bağımlılıkları kuruluyor...');
      
      // Shell'i başlat ve değerini al
      shell = await initializeShell();

      // Paket yöneticisini güncelle
      await _runWithElevation('apt-get update');

      // Gerekli paketleri kur
      final packages = [
        'git',
        'python3',
        'python3-pip',
        'python3-venv'
      ];

      for (final package in packages) {
        print('$package kuruluyor...');
        await _runWithElevation('apt-get install -y $package');
      }

      print('Linux bağımlılıkları kuruldu.');
    } catch (e) {
      print('Linux bağımlılıkları kurulum hatası: $e');
      rethrow;
    }
  }

  Future<void> _runWithElevation(String command) async {
    try {
      if (await _checkCommand('pkexec')) {
        await shell!.run('pkexec $command');
      } else if (await _checkCommand('gksudo')) {
        await shell!.run('gksudo $command');
      } else {
        await shell!.run('sudo $command');
      }
    } catch (e) {
      print('Komut çalıştırma hatası ($command): $e');
      rethrow;
    }
  }

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
      await setupLinuxDependencies();
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
        await shell!.run('sudo apt-get update');
        await shell!.run('sudo apt-get install -y git');
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
      shell = await initializeShell();

      if (Platform.isLinux) {
        await setupLinuxDependencies();
      }

      final appDir = await getApplicationDocumentsDirectory();
      final apiPath = '${appDir.path}/KekikStreamAPI';
      
      final apiDir = Directory(apiPath);
      if (!await apiDir.exists()) {
        await apiDir.create(recursive: true);
      }

      // Git clone işlemi
      print('API indiriliyor...');
      if (await apiDir.list().isEmpty) {
        final cloneResult = await shell!.run('git clone $apiRepo "$apiPath"');
        if (cloneResult.any((result) => result.exitCode != 0)) {
          throw Exception('Git clone hatası: ${cloneResult.map((r) => r.stderr).join('\n')}');
        }
      }

      // Python sanal ortam oluştur ve paketleri kur
      if (Platform.isLinux) {
        final venvPath = '$apiPath/venv';
        print('Python sanal ortam oluşturuluyor...');
        
        // Önce mevcut venv'i temizle
        if (await Directory(venvPath).exists()) {
          await Directory(venvPath).delete(recursive: true);
        }

        // Yeni venv oluştur
        await shell!.run('python3 -m venv "$venvPath"');
        
        print('Pip paketleri kuruluyor...');
        
        // Linux'ta komutları ayrı ayrı çalıştır
        await shell!.cd(apiPath);
        
        // Sanal ortamı aktive et
        final activateCmd = '''
        . "$venvPath/bin/activate" && 
        python3 -m pip install --upgrade pip &&
        python3 -m pip install -r requirements.txt
        ''';
        
        // Bash üzerinden çalıştır
        final pipResult = await Process.run(
          'bash',
          ['-c', activateCmd],
          workingDirectory: apiPath,
          environment: {
            'PATH': Platform.environment['PATH'] ?? '',
            'PYTHONPATH': apiPath,
          },
        );

        if (pipResult.exitCode != 0) {
          throw Exception('Pip kurulum hatası: ${pipResult.stderr}');
        }
      }

      print('API kurulumu tamamlandı!');

    } catch (e) {
      print('API kurulum hatası: $e');
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
    final venvPath = '$apiPath/venv';

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
      // Linux için Python yolunu ve aktivasyon scriptini kullan
      return await Process.start(
        'bash',
        ['-c', '. "$venvPath/bin/activate" && python3 basla.py'],
        workingDirectory: apiPath,
        environment: {
          'PYTHONIOENCODING': 'utf-8',
          'PATH': Platform.environment['PATH'] ?? '',
          'PYTHONPATH': apiPath,
        }
      );
    }
  }
}
