import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class FileBackupService {
  static const String _backupFolderName = 'File2Speech';

  /// 获取备份文件夹路径
  static Future<Directory> getBackupDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupPath = '${appDocDir.path}/$_backupFolderName';
    final backupDir = Directory(backupPath);
    
    // 如果文件夹不存在，创建它
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    return backupDir;
  }

  /// 备份文件内容到 File2Speech 文件夹
  static Future<String> backupFile(String fileName, String textContent) async {
    try {
      final backupDir = await getBackupDirectory();
      
      // 获取文件扩展名
      String getExtension(String name) {
        final lastDot = name.lastIndexOf('.');
        return lastDot > 0 ? name.substring(lastDot) : '';
      }
      
      // 获取不带扩展名的文件名
      String getNameWithoutExtension(String name) {
        final lastDot = name.lastIndexOf('.');
        return lastDot > 0 ? name.substring(0, lastDot) : name;
      }
      
      // 如果文件名已存在，添加时间戳
      String backupFileName = fileName;
      String backupFilePath = '${backupDir.path}/$backupFileName';
      File backupFile = File(backupFilePath);
      
      if (await backupFile.exists()) {
        // 文件名重复，添加时间戳
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = getExtension(fileName);
        final nameWithoutExtension = getNameWithoutExtension(fileName);
        backupFileName = '${nameWithoutExtension}_$timestamp$extension';
        backupFilePath = '${backupDir.path}/$backupFileName';
        backupFile = File(backupFilePath);
      }
      
      // 所有文件都保存为 TXT 格式
      backupFileName = getNameWithoutExtension(backupFileName) + '.txt';
      backupFilePath = '${backupDir.path}/$backupFileName';
      backupFile = File(backupFilePath);
      
      // 写入文件内容
      await backupFile.writeAsString(textContent, encoding: utf8);
      
      return backupFilePath;
    } catch (e) {
      throw Exception('备份文件失败: $e');
    }
  }

  /// 从备份文件夹加载所有文件
  static Future<List<FileBackupItem>> loadBackedUpFiles() async {
    try {
      final backupDir = await getBackupDirectory();
      
      if (!await backupDir.exists()) {
        return [];
      }
      
      final files = backupDir.listSync()
          .where((item) => item is File)
          .cast<File>()
          .where((file) {
            final path = file.path;
            final lastDot = path.lastIndexOf('.');
            final ext = lastDot > 0 ? path.substring(lastDot).toLowerCase() : '';
            return ext == '.txt' || ext == '.pdf';
          })
          .toList();
      
      final List<FileBackupItem> items = [];
      
      for (final file in files) {
        try {
          final textContent = await file.readAsString(encoding: utf8);
          final filePath = file.path;
          // 获取文件名（路径的最后一部分）
          final lastSlash = filePath.lastIndexOf('/');
          final fileName = lastSlash >= 0 ? filePath.substring(lastSlash + 1) : filePath;
          
          // 获取文件修改时间作为添加时间
          final stat = await file.stat();
          final addedAt = stat.modified;
          
          items.add(FileBackupItem(
            fileName: fileName,
            filePath: file.path,
            textContent: textContent,
            addedAt: addedAt,
          ));
        } catch (e) {
          // 跳过无法读取的文件
          continue;
        }
      }
      
      // 按添加时间倒序排列（最新的在前）
      items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      
      return items;
    } catch (e) {
      throw Exception('加载备份文件失败: $e');
    }
  }

  /// 更新备份文件内容
  static Future<void> updateBackupFile(String filePath, String textContent) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.writeAsString(textContent, encoding: utf8);
      } else {
        throw Exception('备份文件不存在');
      }
    } catch (e) {
      throw Exception('更新备份文件失败: $e');
    }
  }

  /// 删除备份文件
  static Future<void> deleteBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('删除备份文件失败: $e');
    }
  }
}

class FileBackupItem {
  final String fileName;
  final String filePath;
  final String textContent;
  final DateTime addedAt;

  FileBackupItem({
    required this.fileName,
    required this.filePath,
    required this.textContent,
    required this.addedAt,
  });
}
