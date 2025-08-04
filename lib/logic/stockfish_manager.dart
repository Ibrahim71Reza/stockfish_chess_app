// lib/logic/stockfish_manager.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class StockfishManager {
  Future<String> getEnginePath() async {
    final binaryName = Platform.isWindows ? 'stockfish_binary.exe' : 'stockfish_binary';
    try {
      final supportDir = await getApplicationSupportDirectory();
      final enginePath = '${supportDir.path}/$binaryName';
      final engineFile = File(enginePath);

      if (!await engineFile.exists()) {
        print('Engine not found. Copying from assets...');
        final byteData = await rootBundle.load('assets/stockfish/$binaryName');
        await engineFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
        print('Engine copied to: $enginePath');
        if (Platform.isLinux || Platform.isAndroid || Platform.isMacOS) {
          print('Making engine executable...');
          final result = await Process.run('chmod', ['+x', enginePath]);
          if (result.exitCode != 0) {
            throw Exception('Failed to make engine executable. stderr: ${result.stderr}');
          }
          print('Engine is now executable.');
        }
      }
      return enginePath;
    } catch (e) {
      print('ERROR setting up engine: $e');
      throw Exception('Could not initialize Stockfish engine.');
    }
  }
}