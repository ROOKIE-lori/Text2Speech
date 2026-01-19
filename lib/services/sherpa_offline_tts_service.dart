import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'model_manager.dart';

/// 基于官方 sherpa_onnx 插件的离线 TTS 服务
/// 
/// 注意：需要先运行 `flutter pub get` 安装 sherpa_onnx 插件
/// 然后根据实际 API 调整代码
class SherpaOfflineTTSService {
  bool _isInitialized = false;
  double _currentRate = 1.0;
  VoidCallback? _onComplete;
  Function(String)? _onError;
  Function(int, int)? _onProgress; // 进度回调 (currentPosition, totalDuration)
  
  Timer? _progressTimer;
  int _currentPosition = 0;
  int _totalDuration = 0;
  String _currentText = '';
  
  // 分段转换相关
  static const int _chunkSize = 10; // 每段10个字
  List<String> _textChunks = []; // 文本分段
  List<File> _audioChunks = []; // 音频文件队列
  List<int> _chunkDurations = []; // 每段音频的时长（毫秒）
  int _currentChunkIndex = 0; // 当前播放的段索引
  bool _isGenerating = false; // 是否正在生成音频
  bool _shouldStop = false; // 是否应该停止
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ModelManager _modelManager = ModelManager();
  
  // Sherpa-ONNX TTS 引擎
  OfflineTts? _tts;
  
  // 是否已初始化 bindings
  static bool _bindingsInitialized = false;
  
  // 模型路径
  String? _modelPath;
  String? _modelDir;
  
  // 当前使用的语音类型
  VoiceType _currentVoiceType = VoiceType.female;

  SherpaOfflineTTSService({VoiceType? voiceType}) {
    if (voiceType != null) {
      _currentVoiceType = voiceType;
      _modelManager.setVoiceType(voiceType);
    }
  }
  
  /// 获取语音类型名称
  String _getVoiceTypeName(VoiceType voiceType) {
    return voiceType == VoiceType.male ? '男声' : '女声';
  }

  /// 检查模型是否已下载
  Future<bool> isModelDownloaded({VoiceType? voiceType}) async {
    return await _modelManager.isModelDownloaded(voiceType: voiceType);
  }
  
  /// 设置语音类型
  void setVoiceType(VoiceType voiceType) {
    if (_currentVoiceType != voiceType) {
      _currentVoiceType = voiceType;
      _modelManager.setVoiceType(voiceType);
      // 如果已初始化，需要重新初始化以加载新模型
      if (_isInitialized) {
        _isInitialized = false;
        _tts?.free();
        _tts = null;
      }
    }
  }
  
  /// 获取当前语音类型
  VoiceType get currentVoiceType => _currentVoiceType;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized && _tts != null) return;
    
    try {
      // 确保 ModelManager 使用当前语音类型
      _modelManager.setVoiceType(_currentVoiceType);
      
      // 检查模型是否已下载
      final isDownloaded = await isModelDownloaded(voiceType: _currentVoiceType);
      if (!isDownloaded) {
        throw Exception('${_getVoiceTypeName(_currentVoiceType)}模型未下载，请先下载模型');
      }
      
      // 获取模型目录（使用当前语音类型）
      final modelDir = await _modelManager.getModelDirectory(voiceType: _currentVoiceType);
      _modelDir = modelDir.path;
      
      // 获取模型路径（使用当前语音类型）
      _modelPath = await _modelManager.getModelFilePath(voiceType: _currentVoiceType);
      if (_modelPath == null) {
        throw Exception('无法获取模型文件路径，请先下载模型');
      }
      
      // 使用官方插件初始化 TTS 引擎
      try {
        // 初始化 bindings（只需要一次）
        if (!_bindingsInitialized) {
          initBindings();
          _bindingsInitialized = true;
          print('✅ Sherpa-ONNX bindings 初始化成功');
        }
        
        // 验证模型路径
        final modelFile = File(_modelPath!);
        if (!await modelFile.exists()) {
          throw Exception('模型文件不存在: $_modelPath');
        }
        print('📁 模型文件存在: $_modelPath');
        print('   文件大小: ${await modelFile.length()} 字节');
        
        // 列出模型目录中的所有文件（用于调试）
        final modelDirObj = Directory(_modelDir ?? '');
        if (await modelDirObj.exists()) {
          print('📂 模型目录内容:');
          await for (final entity in modelDirObj.list()) {
            if (entity is File) {
              final size = await entity.length();
              print('   - ${entity.path.split('/').last} (${size} 字节)');
            } else if (entity is Directory) {
              print('   - ${entity.path.split('/').last}/ (目录)');
            }
          }
        }
        
        // 获取模型文件所在的目录（这是实际的数据目录）
        // 例如：模型文件在 /path/to/vits-zh-aishell3/vits-aishell3.onnx
        // 那么 dataDir 应该是 /path/to/vits-zh-aishell3/
        final actualDataDir = modelFile.parent.path;
        print('📂 实际数据目录: $actualDataDir');
        
        // 查找 tokens.txt 文件（首先在模型文件同目录查找）
        String? tokensPath;
        final tokensFile = File('$actualDataDir/tokens.txt');
        if (await tokensFile.exists()) {
          tokensPath = tokensFile.path;
          print('✅ 在模型目录找到 tokens.txt: $tokensPath');
        } else {
          // 如果在模型文件同目录找不到，递归搜索
          if (_modelDir != null) {
            final dir = Directory(_modelDir!);
            if (await dir.exists()) {
              await for (final entity in dir.list(recursive: true)) {
                if (entity is File && entity.path.toLowerCase().endsWith('tokens.txt')) {
                  tokensPath = entity.path;
                  print('✅ 递归找到 tokens.txt: $tokensPath');
                  break;
                }
              }
            }
          }
        }
        
        // 查找 lexicon.txt 文件（某些模型需要）
        String? lexiconPath;
        final lexiconFile = File('$actualDataDir/lexicon.txt');
        if (await lexiconFile.exists()) {
          lexiconPath = lexiconFile.path;
          print('✅ 找到 lexicon.txt: $lexiconPath');
        }
        
        // 查找 phontab 文件（某些模型必需）
        final phontabFile = File('$actualDataDir/phontab');
        final hasPhontab = await phontabFile.exists();
        
        // 列出数据目录中的所有文件（用于调试）
        final dataDirObj = Directory(actualDataDir);
        if (await dataDirObj.exists()) {
          print('📂 数据目录内容:');
          await for (final entity in dataDirObj.list()) {
            if (entity is File) {
              final size = await entity.length();
              print('   - ${entity.path.split('/').last} (${size} 字节)');
            } else if (entity is Directory) {
              print('   - ${entity.path.split('/').last}/ (目录)');
            }
          }
        }
        
        // 根据官方文档，vits-zh-aishell3 模型不需要 phontab 和 phonindex 文件
        // 这些文件是 espeak-ng 的一部分，但对于中文 VITS 模型不是必需的
        // 如果设置 dataDir，Sherpa-ONNX 可能会检查这些文件
        // 尝试不设置 dataDir，只使用 model、tokens 和 lexicon
        
        // 尝试策略：先不设置 dataDir，如果失败再尝试其他方法
        String dataDirToUse = '';
        
        // 检查模型目录中是否有 .fst 文件（这些是规则文件，可能需要 dataDir）
        bool hasFstFiles = false;
        if (await dataDirObj.exists()) {
          await for (final entity in dataDirObj.list()) {
            if (entity is File && entity.path.toLowerCase().endsWith('.fst')) {
              hasFstFiles = true;
              break;
            }
          }
        }
        
        // 如果有 .fst 文件，可能需要 dataDir，但尝试使用空字符串
        // 如果模型包中确实需要 dataDir，会在创建时失败，然后我们可以尝试其他方法
        if (hasFstFiles) {
          print('📝 检测到 .fst 规则文件，但尝试不设置 dataDir（官方模型不需要 phontab）');
          dataDirToUse = ''; // 尝试不使用 dataDir
        } else {
          dataDirToUse = ''; // 不使用 dataDir
        }
        
        print('📂 配置 dataDir: ${dataDirToUse.isEmpty ? "(空，不设置)" : dataDirToUse}');
        
        // 创建 VITS 模型配置
        // 注意：根据官方文档，vits-zh-aishell3 只需要 model、tokens 和可选的 lexicon
        final vitsConfig = OfflineTtsVitsModelConfig(
          model: _modelPath!,
          tokens: tokensPath ?? '', // 必须的 tokens.txt
          lexicon: lexiconPath ?? '', // 可选的 lexicon.txt
          dataDir: dataDirToUse, // 尝试不设置 dataDir
        );
        
        print('⚙️  VITS 配置:');
        print('   model: ${vitsConfig.model}');
        print('   tokens: ${vitsConfig.tokens.isEmpty ? "(未找到)" : vitsConfig.tokens}');
        print('   lexicon: ${vitsConfig.lexicon.isEmpty ? "(无)" : vitsConfig.lexicon}');
        print('   dataDir: ${vitsConfig.dataDir.isEmpty ? "(无)" : vitsConfig.dataDir}');
        
        // 创建模型配置
        final modelConfig = OfflineTtsModelConfig(
          vits: vitsConfig,
          numThreads: 1,
          debug: true, // 启用调试以获取更多信息
          provider: 'cpu',
        );
        
        // 创建 TTS 配置
        final ttsConfig = OfflineTtsConfig(
          model: modelConfig,
        );
        
        // 创建 TTS 引擎实例
        print('🔄 正在创建 TTS 引擎...');
        _tts = OfflineTts(ttsConfig);
        
        print('✅ Sherpa-ONNX TTS 引擎初始化成功');
        print('   模型路径: $_modelPath');
        print('   模型目录: $_modelDir');
      } catch (e, stackTrace) {
        print('⚠️ Sherpa-ONNX 初始化失败: $e');
        print('   堆栈跟踪: $stackTrace');
        // 如果初始化失败，给出详细错误信息
        if (e.toString().contains('NoSuchMethodError') || 
            e.toString().contains('ClassNotFoundException')) {
          throw Exception(
            'sherpa_onnx 插件未正确安装或配置。\n'
            '请确保：\n'
            '1. 已运行 flutter pub get 安装插件\n'
            '2. 模型文件完整且路径正确\n'
            '3. 模型目录包含必要的配置文件（如 tokens.txt）\n'
            '错误详情: $e'
          );
        }
        throw Exception('Sherpa-ONNX 初始化失败: $e');
      }
      
      // 初始化音频播放器
      _audioPlayer.onPlayerComplete.listen((_) {
        _onChunkPlaybackComplete();
      });
      
      _audioPlayer.onPositionChanged.listen((duration) {
        _onPositionChanged(duration);
      });
      
      _isInitialized = true;
    } catch (e) {
      throw Exception('Sherpa-ONNX 初始化失败: $e');
    }
  }

  /// 设置完成回调
  void setOnComplete(VoidCallback? callback) {
    _onComplete = callback;
  }

  /// 设置错误回调
  void setOnError(Function(String)? callback) {
    _onError = callback;
  }

  /// 设置进度回调
  void setOnProgress(Function(int, int)? callback) {
    _onProgress = callback;
  }

  /// 设置语言
  Future<void> setLanguage(String language) async {
    // Sherpa-ONNX 使用模型文件来确定语言
  }

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    _currentRate = rate.clamp(0.5, 2.0);
    // 如果已初始化，更新引擎速度
    if (_tts != null && _isInitialized) {
      // 注意：sherpa_onnx 插件可能不支持动态更改速度
      // 如果需要更改速度，可能需要重新初始化引擎
    }
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    // 注意：sherpa-onnx 的音调控制可能需要通过模型参数实现
  }

  /// 将文本分割成段落（智能分割：优先按句子，其次按标点，最后按固定长度）
  List<String> _splitTextIntoChunks(String text) {
    if (text.length <= _chunkSize) {
      return [text];
    }
    
    final chunks = <String>[];
    int start = 0;
    
    while (start < text.length) {
      // 优先尝试找到句子结束符（句号、问号、感叹号等）
      int end = start + _chunkSize;
      
      if (end >= text.length) {
        // 最后一段
        chunks.add(text.substring(start));
        break;
      }
      
      // 在当前段内向前查找句子结束符（最多往前找5个字符）
      int searchStart = (end - 5).clamp(start, end);
      int sentenceEnd = -1;
      
      for (int i = end; i >= searchStart; i--) {
        final char = text[i];
        if (char == '。' || char == '！' || char == '？' || 
            char == '.' || char == '!' || char == '?') {
          sentenceEnd = i + 1;
          break;
        }
      }
      
      // 如果找到句子结束符，使用它
      if (sentenceEnd > start) {
        chunks.add(text.substring(start, sentenceEnd));
        start = sentenceEnd;
      } else {
        // 没找到句子结束符，尝试找逗号、分号等
        int commaEnd = -1;
        for (int i = end; i >= searchStart; i--) {
          final char = text[i];
          if (char == '，' || char == '；' || char == ',' || char == ';') {
            commaEnd = i + 1;
            break;
          }
        }
        
        if (commaEnd > start) {
          chunks.add(text.substring(start, commaEnd));
          start = commaEnd;
        } else {
          // 都没找到，按固定长度分割
          chunks.add(text.substring(start, end));
          start = end;
        }
      }
    }
    
    return chunks;
  }

  /// 合成并播放语音（分段转换和播放）
  Future<void> speak(String text, {int startPosition = 0}) async {
    if (!_isInitialized || _tts == null) {
      await initialize();
    }
    
    if (text.isEmpty) return;
    
    if (_tts == null) {
      throw Exception('TTS 引擎未初始化');
    }
    
    _currentText = text;
    
    try {
      // 停止当前播放
      await stop();
      
      // 重置状态（必须在 stop() 之后，因为 stop() 会设置 _shouldStop = true）
      _shouldStop = false;
      _audioChunks.clear();
      _chunkDurations.clear();
      _currentChunkIndex = 0;
      _totalDuration = 0;
      
      // 将文本分割成段落
      _textChunks = _splitTextIntoChunks(text);
      print('🎤 文本已分割为 ${_textChunks.length} 段，开始分段转换和播放');
      
      // 开始生成第一段并播放
      await _generateAndPlayNextChunk(0);
      
    } catch (e) {
      _onError?.call('语音合成失败: $e');
      rethrow;
    }
  }
  
  /// 生成一个音频段（不播放）
  Future<void> _generateChunk(int chunkIndex) async {
    if (_shouldStop || chunkIndex >= _textChunks.length || chunkIndex < _audioChunks.length) {
      return; // 已经生成过或不应该生成
    }
    
    try {
      _isGenerating = true;
      final chunkText = _textChunks[chunkIndex];
      print('🔄 正在生成第 ${chunkIndex + 1}/${_textChunks.length} 段: "${chunkText.substring(0, chunkText.length > 20 ? 20 : chunkText.length)}..."');
      
      // 生成当前段的音频
      final generatedAudio = _tts!.generate(
        text: chunkText,
        sid: 0,
        speed: _currentRate.toDouble(),
      );
      
      if (generatedAudio.samples.isEmpty) {
        throw Exception('语音合成失败：第 ${chunkIndex + 1} 段未生成音频数据');
      }
      
      // 转换为音频文件
      final sampleRate = generatedAudio.sampleRate;
      final audioBytes = <int>[];
      for (final sample in generatedAudio.samples) {
        final int16Value = (sample.clamp(-1.0, 1.0) * 32767).round();
        audioBytes.add(int16Value & 0xFF);
        audioBytes.add((int16Value >> 8) & 0xFF);
      }
      
      final audioFile = await _saveAudioToFile(audioBytes, sampleRate);
      
      // 计算这段音频的时长
      final chunkDuration = (generatedAudio.samples.length / sampleRate * 1000).round();
      
      // 添加到队列
      _audioChunks.add(audioFile);
      _chunkDurations.add(chunkDuration);
      _totalDuration += chunkDuration;
      
      _isGenerating = false;
      print('✅ 第 ${chunkIndex + 1} 段生成完成，时长: ${chunkDuration}ms');
    } catch (e) {
      _isGenerating = false;
      print('⚠️ 生成第 ${chunkIndex + 1} 段失败: $e');
      rethrow;
    }
  }
  
  /// 生成并播放下一个音频段
  Future<void> _generateAndPlayNextChunk(int chunkIndex) async {
    if (_shouldStop || chunkIndex >= _textChunks.length) {
      // 所有段都已播放完成
      print('✅ 所有段都已处理完成，chunkIndex: $chunkIndex, totalChunks: ${_textChunks.length}');
      _onPlaybackComplete();
      return;
    }
    
    try {
      print('🎵 开始处理第 ${chunkIndex + 1}/${_textChunks.length} 段');
      
      // 如果当前段还没有生成，先生成它
      if (chunkIndex >= _audioChunks.length) {
        print('📝 第 ${chunkIndex + 1} 段尚未生成，开始生成...');
        await _generateChunk(chunkIndex);
      } else {
        print('✅ 第 ${chunkIndex + 1} 段已生成，直接播放');
      }
      
      // 如果还有下一段，在后台预生成（流水线）
      if (chunkIndex + 1 < _textChunks.length && chunkIndex + 1 >= _audioChunks.length && !_shouldStop) {
        // 异步生成下一段，不等待完成
        print('🔄 后台预生成第 ${chunkIndex + 2} 段');
        _generateChunk(chunkIndex + 1).catchError((e) {
          print('⚠️ 预生成下一段失败: $e');
        });
      }
      
      // 确保当前段已生成，然后播放
      if (chunkIndex < _audioChunks.length && !_shouldStop) {
        _currentChunkIndex = chunkIndex;
        final audioFile = _audioChunks[chunkIndex];
        
        // 检查文件是否存在
        if (!await audioFile.exists()) {
          throw Exception('音频文件不存在: ${audioFile.path}');
        }
        
        print('▶️ 开始播放第 ${chunkIndex + 1} 段: ${audioFile.path}');
        
        // 播放当前段
        await _playAudio(audioFile, 0);
        
        print('✅ 第 ${chunkIndex + 1} 段播放命令已发送');
        
        // 启动进度追踪（使用累计时长）
        if (chunkIndex == 0) {
          // 只在第一段播放时启动进度追踪
          print('📊 启动进度追踪');
          _startProgressTrackingForChunks();
        }
      } else {
        print('⚠️ 无法播放第 ${chunkIndex + 1} 段: chunkIndex=$chunkIndex, audioChunks.length=${_audioChunks.length}, shouldStop=$_shouldStop');
      }
    } catch (e, stackTrace) {
      _isGenerating = false;
      print('❌ 播放第 ${chunkIndex + 1} 段失败: $e');
      print('堆栈跟踪: $stackTrace');
      _onError?.call('播放第 ${chunkIndex + 1} 段失败: $e');
      // 不抛出异常，继续尝试播放下一段
    }
  }
  
  /// 当前片段播放完成回调
  void _onChunkPlaybackComplete() {
    if (_shouldStop) return;
    
    // 计算当前已播放的总时长
    int playedDuration = 0;
    for (int i = 0; i < _currentChunkIndex; i++) {
      if (i < _chunkDurations.length) {
        playedDuration += _chunkDurations[i];
      }
    }
    
    if (_currentChunkIndex < _chunkDurations.length) {
      playedDuration += _chunkDurations[_currentChunkIndex];
    }
    
    _currentPosition = playedDuration;
    
    // 播放下一段
    final nextChunkIndex = _currentChunkIndex + 1;
    if (nextChunkIndex < _textChunks.length) {
      // 等待下一段生成完成（如果需要）
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_shouldStop) {
          _generateAndPlayNextChunk(nextChunkIndex);
        }
      });
    } else {
      // 所有段都已播放完成
      _onPlaybackComplete();
    }
  }
  
  /// 为分段播放启动进度追踪
  void _startProgressTrackingForChunks() {
    _stopProgressTracking();
    
    if (_totalDuration > 0) {
      _progressTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
        if (_shouldStop) {
          timer.cancel();
          return;
        }
        
        // 计算当前已播放时长
        int playedDuration = 0;
        for (int i = 0; i < _currentChunkIndex; i++) {
          if (i < _chunkDurations.length) {
            playedDuration += _chunkDurations[i];
          }
        }
        
        // 这里简化处理：假设当前段播放了一半
        // 更精确的方法需要从 AudioPlayer 获取当前位置
        _currentPosition = playedDuration;
        
        if (_currentPosition >= _totalDuration) {
          _currentPosition = _totalDuration;
          _stopProgressTracking();
        }
        
        _onProgress?.call(_currentPosition, _totalDuration);
      });
    }
  }

  /// 保存音频到文件（WAV 格式）
  Future<File> _saveAudioToFile(List<int> audioData, int sampleRate) async {
    final tempDir = await getTemporaryDirectory();
    final audioFile = File('${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav');
    
    // 创建 WAV 文件头
    final wavHeader = _createWavHeader(audioData.length, sampleRate);
    final wavData = [...wavHeader, ...audioData];
    
    await audioFile.writeAsBytes(wavData);
    return audioFile;
  }

  /// 创建 WAV 文件头
  List<int> _createWavHeader(int dataSize, int sampleRate) {
    final header = <int>[];
    
    // RIFF header
    header.addAll('RIFF'.codeUnits);
    header.addAll(_intToBytes(dataSize + 36, 4)); // File size - 8
    header.addAll('WAVE'.codeUnits);
    
    // fmt chunk
    header.addAll('fmt '.codeUnits);
    header.addAll(_intToBytes(16, 4)); // Subchunk1Size
    header.addAll(_intToBytes(1, 2)); // AudioFormat (PCM)
    header.addAll(_intToBytes(1, 2)); // NumChannels (mono)
    header.addAll(_intToBytes(sampleRate, 4)); // SampleRate
    header.addAll(_intToBytes(sampleRate * 2, 4)); // ByteRate
    header.addAll(_intToBytes(2, 2)); // BlockAlign
    header.addAll(_intToBytes(16, 2)); // BitsPerSample
    
    // data chunk
    header.addAll('data'.codeUnits);
    header.addAll(_intToBytes(dataSize, 4)); // Subchunk2Size
    
    return header;
  }

  /// 将整数转换为字节数组（little endian）
  List<int> _intToBytes(int value, int length) {
    final bytes = <int>[];
    for (int i = 0; i < length; i++) {
      bytes.add(value & 0xFF);
      value >>= 8;
    }
    return bytes;
  }

  /// 播放音频
  Future<void> _playAudio(File audioFile, int startPosition) async {
    try {
      print('🎧 AudioPlayer.play 调用: ${audioFile.path}, position: $startPosition ms');
      await _audioPlayer.play(
        DeviceFileSource(audioFile.path),
        position: Duration(milliseconds: startPosition),
      );
      print('🎧 AudioPlayer.play 调用完成');
    } catch (e, stackTrace) {
      print('❌ 播放音频文件失败: $e');
      print('堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  /// 启动进度追踪
  void _startProgressTracking(int startPosition) {
    _stopProgressTracking();
    _currentPosition = startPosition;
    
    if (_totalDuration > 0) {
      _progressTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
        _currentPosition += 250;
        
        if (_currentPosition >= _totalDuration) {
          _currentPosition = _totalDuration;
          _stopProgressTracking();
        }
        
        _onProgress?.call(_currentPosition, _totalDuration);
      });
    }
  }

  /// 停止进度追踪
  void _stopProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// 播放完成回调
  void _onPlaybackComplete() {
    _stopProgressTracking();
    _currentPosition = _totalDuration;
    _onProgress?.call(_currentPosition, _totalDuration);
    _onComplete?.call();
  }

  /// 位置变化回调
  void _onPositionChanged(Duration position) {
    _currentPosition = position.inMilliseconds;
    _onProgress?.call(_currentPosition, _totalDuration);
  }

  /// 停止播放
  Future<void> stop({bool resetPosition = false}) async {
    _shouldStop = true;
    _isGenerating = false;
    await _audioPlayer.stop();
    _stopProgressTracking();
    
    // 清理临时音频文件
    for (final file in _audioChunks) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // 忽略删除失败的错误
      }
    }
    _audioChunks.clear();
    _chunkDurations.clear();
    _textChunks.clear();
    
    if (resetPosition) {
      _currentPosition = 0;
      _currentChunkIndex = 0;
      _onProgress?.call(0, _totalDuration);
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    _shouldStop = true; // 暂停时停止生成新段
    await _audioPlayer.pause();
    _stopProgressTracking();
    _onProgress?.call(_currentPosition, _totalDuration);
  }

  /// 获取当前播放位置
  int getCurrentPosition() => _currentPosition;

  /// 获取总时长
  int getTotalDuration() => _totalDuration;

  /// 跳转到指定位置
  Future<void> seekToPosition(int positionInMs) async {
    await _audioPlayer.seek(Duration(milliseconds: positionInMs));
    _currentPosition = positionInMs;
    _onProgress?.call(_currentPosition, _totalDuration);
  }

  /// 后退指定毫秒
  Future<void> seekBackward(int milliseconds) async {
    final newPosition = (_currentPosition - milliseconds).clamp(0, _totalDuration);
    await seekToPosition(newPosition);
  }

  /// 前进指定毫秒
  Future<void> seekForward(int milliseconds) async {
    final newPosition = (_currentPosition + milliseconds).clamp(0, _totalDuration);
    await seekToPosition(newPosition);
  }

  /// 清理资源
  void dispose() {
    _stopProgressTracking();
    if (_tts != null) {
      try {
        // 调用 free() 方法释放资源
        _tts!.free();
        _tts = null;
      } catch (e) {
        print('清理 TTS 引擎时出错: $e');
        _tts = null;
      }
    }
    _audioPlayer.dispose();
    _isInitialized = false;
  }
}
