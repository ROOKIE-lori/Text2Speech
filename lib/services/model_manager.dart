import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'dart:typed_data';

/// 语音类型枚举
enum VoiceType {
  male,   // 男声
  female, // 女声
}

/// 模型管理类
/// 负责模型的下载、解压、校验和路径管理
class ModelManager {
  static const String _modelDirName = 'sherpa-onnx-tts-model';
  static const String _modelArchiveName = 'model.tar.bz2'; // 改为 tar.bz2 格式
  static const String _modelFileName = 'model.onnx';
  
  // 默认模型下载地址
  static const String _defaultMaleModelUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2';
  static const String _defaultFemaleModelUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-aishell3.tar.bz2';
  
  // 当前语音类型
  VoiceType _currentVoiceType = VoiceType.female;
  
  // 模型下载地址映射
  final Map<VoiceType, String> _modelUrls = {
    VoiceType.male: _defaultMaleModelUrl,
    VoiceType.female: _defaultFemaleModelUrl,
  };
  
  ModelManager({String? downloadUrl, VoiceType? voiceType}) {
    if (voiceType != null) {
      _currentVoiceType = voiceType;
    }
    if (downloadUrl != null) {
      _modelUrls[_currentVoiceType] = downloadUrl;
    }
  }
  
  /// 获取当前语音类型
  VoiceType get currentVoiceType => _currentVoiceType;
  
  /// 设置语音类型
  void setVoiceType(VoiceType voiceType) {
    _currentVoiceType = voiceType;
  }
  
  /// 获取当前模型的下载地址
  String get modelDownloadUrl => _modelUrls[_currentVoiceType] ?? _defaultFemaleModelUrl;
  
  /// 获取指定语音类型的模型下载地址
  String getModelUrl(VoiceType voiceType) {
    return _modelUrls[voiceType] ?? (voiceType == VoiceType.male ? _defaultMaleModelUrl : _defaultFemaleModelUrl);
  }
  
  /// 获取模型目录路径（根据语音类型）
  Future<Directory> getModelDirectory({VoiceType? voiceType}) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final voiceTypeToUse = voiceType ?? _currentVoiceType;
    final voiceDirName = voiceTypeToUse == VoiceType.male ? 'male' : 'female';
    final modelDir = Directory('${appDocDir.path}/$_modelDirName/$voiceDirName');
    
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    
    return modelDir;
  }
  
  /// 递归查找所有 .onnx 文件
  Future<List<String>> _findOnnxFiles(Directory dir) async {
    final List<String> onnxFiles = [];
    
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final path = entity.path;
          if (path.toLowerCase().endsWith('.onnx')) {
            onnxFiles.add(path);
          }
        }
      }
    } catch (e) {
      print('查找 .onnx 文件时出错: $e');
    }
    
    return onnxFiles;
  }
  
  /// 获取模型文件路径（根据语音类型）
  Future<String?> getModelFilePath({VoiceType? voiceType}) async {
    final modelDir = await getModelDirectory(voiceType: voiceType);
    
    // 首先尝试直接路径
    final expectedModelFile = File('${modelDir.path}/$_modelFileName');
    if (await expectedModelFile.exists()) {
      return expectedModelFile.path;
    }
    
    // 如果直接路径不存在，查找所有 .onnx 文件，返回最大的一个
    final onnxFiles = await _findOnnxFiles(modelDir);
    
    if (onnxFiles.isEmpty) {
      return null;
    }
    
    // 按大小排序，返回最大的文件（通常是主模型）
    final fileSizes = <int>[];
    for (var path in onnxFiles) {
      final file = File(path);
      if (await file.exists()) {
        fileSizes.add(await file.length());
      } else {
        fileSizes.add(0);
      }
    }
    
    // 找到最大的文件
    int maxIndex = 0;
    for (int i = 1; i < fileSizes.length; i++) {
      if (fileSizes[i] > fileSizes[maxIndex]) {
        maxIndex = i;
      }
    }
    
    return onnxFiles[maxIndex];
  }
  
  /// 检查模型是否已下载（根据语音类型）
  Future<bool> isModelDownloaded({VoiceType? voiceType}) async {
    final modelPath = await getModelFilePath(voiceType: voiceType);
    return modelPath != null;
  }
  
  /// 下载模型文件
  /// 
  /// [onProgress] 下载进度回调，参数为 (downloaded, total)
  /// [onExtracting] 解压状态回调，参数为 (currentFile, totalFiles, currentFileSize, totalSize)
  Future<void> downloadModel({
    required Function(int downloaded, int total) onProgress,
    Function(String currentFile, int currentFileIndex, int totalFiles)? onExtracting,
    CancelToken? cancelToken,
  }) async {
    try {
      final modelDir = await getModelDirectory(voiceType: _currentVoiceType);
      
      // 从 URL 中提取文件名，如果没有则使用默认名称
      String archiveFileName = _modelArchiveName;
      try {
        final uri = Uri.parse(modelDownloadUrl);
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final fileName = pathSegments.last;
          if (fileName.isNotEmpty && fileName.contains('.')) {
            archiveFileName = fileName;
          }
        }
      } catch (e) {
        print('无法从 URL 提取文件名，使用默认名称: $e');
      }
      
      final archiveFile = File('${modelDir.path}/$archiveFileName');
      
      // 如果文件已存在，先删除
      if (await archiveFile.exists()) {
        await archiveFile.delete();
      }
      
      print('开始下载模型文件: $modelDownloadUrl');
      print('保存为: ${archiveFile.path}');
      
      // 使用dio下载
      final dio = Dio();
      
      await dio.download(
        modelDownloadUrl,
        archiveFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received, total);
          }
        },
      );
      
      print('下载完成，文件大小: ${await archiveFile.length()} 字节');
      
      // 下载完成后解压（带进度反馈）
      await _extractModel(archiveFile.path, onExtracting: onExtracting);
      
      // 解压完成后删除压缩文件
      if (await archiveFile.exists()) {
        await archiveFile.delete();
        print('已删除压缩文件: ${archiveFile.path}');
      }
      
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        throw Exception('下载已取消');
      } else if (e is DioException && e.type == DioExceptionType.connectionTimeout) {
        throw Exception('网络连接超时，请检查网络设置');
      } else if (e is DioException) {
        throw Exception('下载失败: ${e.message}');
      } else {
        throw Exception('下载失败: $e');
      }
    }
  }
  
  /// 解压模型文件
  /// 
  /// [onExtracting] 解压进度回调，参数为 (currentFile, currentFileIndex, totalFiles)
  Future<void> _extractModel(
    String archivePath, {
    Function(String currentFile, int currentFileIndex, int totalFiles)? onExtracting,
  }) async {
    try {
      // 读取文件
      final archiveFile = File(archivePath);
      if (!await archiveFile.exists()) {
        throw Exception('压缩文件不存在: $archivePath');
      }
      
      final archiveData = await archiveFile.readAsBytes();
      print('开始解压文件: $archivePath, 大小: ${archiveData.length} 字节');
      
      if (archiveData.isEmpty) {
        throw Exception('压缩文件为空');
      }
      
      // 优先通过文件头（magic bytes）检测格式（不依赖扩展名）
      final fileSignature = _detectArchiveFormat(archiveData);
      print('检测到的文件格式: $fileSignature');
      print('文件路径: $archivePath');
      
      // 检查文件格式（只支持 .tar.bz2）
      final lowerPath = archivePath.toLowerCase();
      
      // 如果文件头是 BZIP2，直接解压（不检查扩展名）
      if (fileSignature == 'BZIP2') {
        print('文件格式验证通过: BZIP2 (.tar.bz2)');
      } else {
        // 文件头不是 BZIP2，检查扩展名
        if (!lowerPath.endsWith('.tar.bz2')) {
          throw Exception(
            '不支持的文件格式。\n'
            '检测到文件签名: $fileSignature\n'
            '文件扩展名: ${lowerPath.contains('.') ? lowerPath.split('.').last : '无'}\n'
            '本应用只支持 .tar.bz2 格式的模型文件。\n'
            '请确保下载的是 .tar.bz2 格式的模型文件。'
          );
        } else {
          // 扩展名是 .tar.bz2 但文件头不匹配，可能是文件损坏
          throw Exception(
            '文件格式验证失败。\n'
            '文件扩展名是 .tar.bz2，但文件头检测为: $fileSignature\n'
            '文件可能已损坏或下载不完整，请重新下载。\n'
            '文件大小: ${archiveData.length} 字节'
          );
        }
      }
      
      Archive archive;
      
      try {
        // 只支持 tar.bz2 格式：先解压 bzip2，再解压 tar
        print('开始解压 BZIP2 压缩...');
        print('压缩文件大小: ${(archiveData.length / 1024 / 1024).toStringAsFixed(2)} MB');
        
        // 第一步：解压 BZIP2
        List<int> bzip2Data;
        try {
          print('正在解压 BZIP2 数据...');
          bzip2Data = BZip2Decoder().decodeBytes(archiveData);
          print('BZIP2 解压完成，解压后大小: ${(bzip2Data.length / 1024 / 1024).toStringAsFixed(2)} MB');
        } catch (e) {
          print('BZIP2 解压失败: $e');
          print('错误类型: ${e.runtimeType}');
          throw Exception(
            'BZIP2 解压失败。\n'
            '可能的原因：\n'
            '1. 文件下载不完整（当前大小: ${(archiveData.length / 1024 / 1024).toStringAsFixed(2)} MB）\n'
            '2. 文件已损坏\n'
            '3. 内存不足（文件太大）\n'
            '请重新下载模型文件。\n'
            '错误详情: $e'
          );
        }
        
        // 第二步：解压 TAR
        try {
          print('开始解压 TAR 归档...');
          archive = TarDecoder().decodeBytes(bzip2Data);
          print('TAR 解压完成，共 ${archive.files.length} 个文件/目录');
        } catch (e) {
          print('TAR 解压失败: $e');
          print('错误类型: ${e.runtimeType}');
          throw Exception(
            'TAR 归档解压失败。\n'
            'BZIP2 解压已成功，但 TAR 归档解压失败。\n'
            '可能的原因：\n'
            '1. TAR 文件结构损坏\n'
            '2. 内存不足\n'
            '请重新下载模型文件。\n'
            '错误详情: $e'
          );
        }
      } catch (e) {
        // 如果错误信息已经包含了详细说明，直接抛出
        if (e.toString().contains('BZIP2 解压失败') || 
            e.toString().contains('TAR 归档解压失败')) {
          rethrow;
        }
        // 否则，包装为通用错误
        throw Exception(
          '解压 .tar.bz2 文件失败。\n'
          '请确保：\n'
          '1. 文件是完整的（下载未中断）\n'
          '2. 文件是有效的 .tar.bz2 格式\n'
          '3. archive 包已更新到最新版本（^4.0.0+）\n'
          '4. 设备有足够的可用内存和磁盘空间\n'
          '错误详情: $e\n'
          '错误类型: ${e.runtimeType}'
        );
      }
      
      final modelDir = await getModelDirectory(voiceType: _currentVoiceType);
      print('解压目标目录: ${modelDir.path}');
      
      int fileCount = 0;
      int totalSize = 0;
      final totalFiles = archive.files.where((f) => f.isFile).length;
      int processedFiles = 0;
      
      // 解压所有文件
      int fileIndex = 0;
      for (final file in archive.files) {
        fileIndex++;
        
        try {
          final filename = file.name;
          // 清理文件名（移除前导斜杠和相对路径）
          final cleanFilename = filename.replaceAll(RegExp(r'^[/\\]+|[/\\]+$'), '');
          if (cleanFilename.isEmpty) continue;
          
          // 检查路径安全性，防止路径遍历攻击
          if (cleanFilename.contains('..')) {
            print('跳过不安全路径: $cleanFilename');
            continue;
          }
          
          if (file.isFile) {
            try {
              // 更新解压进度（每处理一个文件更新一次）
              processedFiles++;
              if (onExtracting != null) {
                onExtracting(cleanFilename, processedFiles, totalFiles);
                // 每 5 个文件给 UI 一次更新机会，减少延迟
                if (processedFiles % 5 == 0) {
                  await Future.delayed(const Duration(milliseconds: 1));
                }
              }
              
              // 安全地获取文件内容
              List<int> fileData;
              final content = file.content;
              
              if (content is List<int>) {
                fileData = content;
              } else if (content is Uint8List) {
                fileData = content.toList();
              } else if (content != null) {
                // 尝试转换为字节列表
                try {
                  fileData = List<int>.from(content);
                } catch (e) {
                  print('无法转换文件内容 ($processedFiles/$totalFiles): $cleanFilename, 错误: $e');
                  continue;
                }
              } else {
                print('文件内容为空 ($processedFiles/$totalFiles): $cleanFilename');
                continue;
              }
              
              // 检查文件大小是否合理（防止异常大的值）
              if (fileData.length < 0 || fileData.length > 1024 * 1024 * 1024) { // 最大 1GB
                print('跳过异常大小的文件 ($processedFiles/$totalFiles): $cleanFilename, 大小: ${fileData.length}');
                continue;
              }
              
              final outFile = File('${modelDir.path}/$cleanFilename');
              
              // 确保父目录存在
              try {
                await outFile.parent.create(recursive: true);
              } catch (e) {
                throw Exception('无法创建目录: ${outFile.parent.path}, 错误: $e');
              }
              
              // 写入文件
              try {
                await outFile.writeAsBytes(fileData);
                fileCount++;
                totalSize += fileData.length;
                
                // 每 10 个文件或第一个文件打印一次进度
                if (fileCount % 10 == 0 || fileCount == 1) {
                  print('已解压 $fileCount/$totalFiles 个文件... ($cleanFilename, ${(fileData.length / 1024 / 1024).toStringAsFixed(2)} MB)');
                }
              } catch (e) {
                throw Exception('写入文件失败: ${outFile.path}, 错误: $e');
              }
            } catch (e) {
              // 单个文件解压失败，记录错误但继续处理
              print('解压文件失败 ($processedFiles/$totalFiles): $filename');
              print('错误详情: $e');
              print('错误堆栈: ${StackTrace.current}');
              // 继续处理其他文件，但记录失败的次数
              continue;
            }
          } else {
            // 创建目录
            try {
              final dir = Directory('${modelDir.path}/$cleanFilename');
              await dir.create(recursive: true);
            } catch (e) {
              print('创建目录失败: $cleanFilename, 错误: $e');
              // 目录创建失败通常可以继续，因为文件写入时会创建父目录
            }
          }
        } catch (e) {
          // 处理文件项时出错，记录但继续
          print('处理归档项失败 ($fileIndex/${archive.files.length}): ${file.name}');
          print('错误详情: $e');
          continue;
        }
      }
      
      print('解压完成，共处理 $fileCount 个文件，总大小: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // 检查是否解压了足够的文件
      if (fileCount == 0) {
        throw Exception(
          '解压失败：没有成功解压任何文件。\n'
          '可能的原因：\n'
          '1. 文件已损坏或格式不正确\n'
          '2. 文件权限问题\n'
          '3. 磁盘空间不足\n'
          '请重新下载模型文件。'
        );
      }
      
      // 列出所有解压后的文件（用于调试）
      try {
        final modelDir = await getModelDirectory(voiceType: _currentVoiceType);
        print('=== 解压后的文件列表 ===');
        await _listDirectoryRecursive(modelDir, modelDir.path, 0);
        print('========================');
      } catch (e) {
        print('列出文件时出错: $e');
      }
      
      // 校验核心文件是否存在
      try {
        await _validateModel();
        print('模型校验通过');
      } catch (e) {
        print('模型校验失败: $e');
        
        // 尝试查找所有 .onnx 文件，提供更详细的错误信息
        try {
          final modelDir = await getModelDirectory(voiceType: _currentVoiceType);
          final onnxFiles = await _findOnnxFiles(modelDir);
          
          if (onnxFiles.isNotEmpty) {
            print('找到以下 .onnx 文件:');
            for (var i = 0; i < onnxFiles.length; i++) {
              final file = File(onnxFiles[i]);
              final size = await file.length();
              print('  ${i + 1}. ${onnxFiles[i]} (${(size / 1024 / 1024).toStringAsFixed(2)} MB)');
            }
            throw Exception(
              '解压完成，但模型文件校验失败。\n'
              '已解压 $fileCount 个文件。\n'
              '找到了 ${onnxFiles.length} 个 .onnx 文件，但验证时出错。\n'
              '找到的文件：\n${onnxFiles.map((f) => '  - $f').join('\n')}\n'
              '错误详情: $e'
            );
          } else {
            throw Exception(
              '解压完成，但模型文件校验失败。\n'
              '已解压 $fileCount 个文件，但未找到任何 .onnx 模型文件。\n'
              '可能的原因：\n'
              '1. 模型文件结构不正确\n'
              '2. 核心文件未包含在压缩包中\n'
              '3. 文件命名不符合预期\n'
              '请检查下载的模型文件是否正确。\n'
              '错误详情: $e'
            );
          }
        } catch (e2) {
          // 如果查找 .onnx 文件也失败，使用原始错误信息
          if (e2.toString().contains('解压完成，但模型文件校验失败')) {
            rethrow;
          }
          rethrow;
        }
        
        // 尝试查找所有 .onnx 文件
        try {
          final modelDir = await getModelDirectory(voiceType: _currentVoiceType);
          final onnxFiles = await _findOnnxFiles(modelDir);
          
          if (onnxFiles.isNotEmpty) {
            print('找到以下 .onnx 文件:');
            for (var file in onnxFiles) {
              print('  - $file');
            }
            throw Exception(
              '解压完成，但模型文件校验失败。\n'
              '已解压 $fileCount 个文件。\n'
              '找到了 ${onnxFiles.length} 个 .onnx 文件，但位置不符合预期。\n'
              '找到的文件：\n${onnxFiles.map((f) => '  - $f').join('\n')}\n'
              '期望的文件：${modelDir.path}/$_modelFileName\n'
              '请检查模型文件结构。'
            );
          } else {
            throw Exception(
              '解压完成，但模型文件校验失败。\n'
              '已解压 $fileCount 个文件，但未找到任何 .onnx 模型文件。\n'
              '可能的原因：\n'
              '1. 模型文件结构不正确\n'
              '2. 核心文件未包含在压缩包中\n'
              '3. 文件命名不符合预期\n'
              '请检查下载的模型文件是否正确。\n'
              '错误详情: $e'
            );
          }
        } catch (e2) {
          // 如果查找 .onnx 文件也失败，使用原始错误信息
          rethrow;
        }
      }
      
    } catch (e) {
      print('解压过程出错: $e');
      print('错误类型: ${e.runtimeType}');
      print('错误堆栈: ${StackTrace.current}');
      
      // 如果是已明确的错误，直接抛出
      if (e.toString().contains('解压失败') || 
          e.toString().contains('不支持') ||
          e.toString().contains('校验失败')) {
        rethrow;
      }
      
      if (e is RangeError) {
        throw Exception(
          '解压失败：文件可能已损坏或格式不正确。\n'
          '错误类型: RangeError\n'
          '请重新下载模型文件。\n'
          '错误详情: $e'
        );
      }
      
      throw Exception(
        '解压失败: $e\n'
        '可能的原因：\n'
        '1. 文件下载不完整\n'
        '2. 文件格式不正确\n'
        '3. 磁盘空间不足\n'
        '4. 文件权限问题\n'
        '请检查文件完整性并重新下载。'
      );
    }
  }
  
  /// 递归列出目录中的所有文件（用于调试）
  Future<void> _listDirectoryRecursive(Directory dir, String basePath, int level) async {
    try {
      await for (final entity in dir.list()) {
        final relativePath = entity.path.substring(basePath.length + 1);
        final indent = '  ' * level;
        
        if (entity is File) {
          final size = await entity.length();
          print('$indent📄 $relativePath (${(size / 1024).toStringAsFixed(2)} KB)');
        } else if (entity is Directory) {
          print('$indent📁 $relativePath/');
          await _listDirectoryRecursive(entity, basePath, level + 1);
        }
      }
    } catch (e) {
      print('${'  ' * level}❌ 列出目录时出错: $e');
    }
  }
  
  /// 校验模型文件
  Future<void> _validateModel() async {
    final modelDir = await getModelDirectory();
    
    // 首先尝试直接路径
    final expectedModelFile = File('${modelDir.path}/$_modelFileName');
    if (await expectedModelFile.exists()) {
      final fileSize = await expectedModelFile.length();
      if (fileSize < 1024) {
        throw Exception('模型文件异常小，可能已损坏: ${fileSize} 字节');
      }
      print('模型文件验证通过: ${expectedModelFile.path}, 大小: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      return;
    }
    
    // 如果直接路径不存在，查找所有 .onnx 文件
    final onnxFiles = await _findOnnxFiles(modelDir);
    
    if (onnxFiles.isEmpty) {
      throw Exception('模型文件不存在，解压可能失败');
    }
    
    // 按大小排序，选择最大的文件（通常是主模型）
    final fileSizes = <int>[];
    for (var path in onnxFiles) {
      final file = File(path);
      if (await file.exists()) {
        fileSizes.add(await file.length());
      } else {
        fileSizes.add(0);
      }
    }
    
    int maxIndex = 0;
    for (int i = 1; i < fileSizes.length; i++) {
      if (fileSizes[i] > fileSizes[maxIndex]) {
        maxIndex = i;
      }
    }
    
    final modelFile = File(onnxFiles[maxIndex]);
    final fileSize = await modelFile.length();
    
    if (fileSize < 1024) {
      throw Exception('找到的模型文件异常小，可能已损坏: ${modelFile.path}, ${fileSize} 字节');
    }
    
    print('找到模型文件: ${modelFile.path}, 大小: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
    if (onnxFiles.length > 1) {
      print('注意：找到多个 .onnx 文件，已选择最大的一个');
      for (var i = 0; i < onnxFiles.length; i++) {
        print('  ${i + 1}. ${onnxFiles[i]} (${(fileSizes[i] / 1024 / 1024).toStringAsFixed(2)} MB)');
      }
    }
    print('模型文件验证通过');
  }
  
  /// 通过文件头（magic bytes）检测压缩文件格式
  /// 只检测 BZIP2 格式（.tar.bz2）
  String _detectArchiveFormat(List<int> data) {
    if (data.length < 2) return 'UNKNOWN';
    
    // BZIP2: BZ (0x42 0x5A)
    if (data.length >= 2 && data[0] == 0x42 && data[1] == 0x5A) {
      return 'BZIP2';
    }
    
    return 'UNKNOWN';
  }

  /// 删除模型文件
  Future<void> deleteModel() async {
    try {
      final modelDir = await getModelDirectory(voiceType: _currentVoiceType);
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
      }
    } catch (e) {
      throw Exception('删除模型失败: $e');
    }
  }
  
  /// 获取模型文件大小（MB）
  Future<double> getModelSize() async {
    final modelPath = await getModelFilePath();
    if (modelPath == null) return 0.0;
    
    final modelFile = File(modelPath);
    if (!await modelFile.exists()) return 0.0;
    
    final size = await modelFile.length();
    return size / 1024 / 1024; // 转换为MB
  }
}
