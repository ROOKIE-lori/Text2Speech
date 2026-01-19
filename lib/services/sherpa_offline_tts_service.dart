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
        _onPlaybackComplete();
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

  /// 合成并播放语音
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
      
      // 使用官方插件合成语音
      print('🎤 开始合成语音: ${text.length} 字符');
      
      try {
        // 使用 Sherpa-ONNX 合成语音
        // generate 方法返回 GeneratedAudio，包含 samples (Float32List) 和 sampleRate
        final generatedAudio = _tts!.generate(
          text: text,
          sid: 0, // speaker ID，如果有多个说话人
          speed: _currentRate.toDouble(),
        );
        
        if (generatedAudio.samples.isEmpty) {
          throw Exception('语音合成失败：未生成音频数据');
        }
        
        // 获取采样率
        final sampleRate = generatedAudio.sampleRate;
        
        // 将 Float32List 转换为 16位 PCM 字节数组（little-endian）
        final audioBytes = <int>[];
        for (final sample in generatedAudio.samples) {
          // 将浮点数限制在 -1.0 到 1.0 之间，然后转换为 16位整数
          final int16Value = (sample.clamp(-1.0, 1.0) * 32767).round();
          // 转换为 little-endian 字节
          audioBytes.add(int16Value & 0xFF); // 低字节
          audioBytes.add((int16Value >> 8) & 0xFF); // 高字节
        }
        
        // 保存音频到临时文件
        final audioFile = await _saveAudioToFile(
          audioBytes,
          sampleRate,
        );
        
        // 估算总时长（基于音频样本数量和采样率）
        final samplesCount = generatedAudio.samples.length;
        _totalDuration = (samplesCount / sampleRate * 1000).round();
        
        // 播放音频
        await _playAudio(audioFile, startPosition);
        
        // 启动进度追踪
        _startProgressTracking(startPosition);
        
        print('✅ 语音合成完成，时长: ${_totalDuration}ms，采样率: ${sampleRate}Hz');
      } catch (e) {
        print('⚠️ 语音合成失败: $e');
        throw Exception('语音合成失败: $e');
      }
      
    } catch (e) {
      _onError?.call('语音合成失败: $e');
      rethrow;
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
    await _audioPlayer.play(
      DeviceFileSource(audioFile.path),
      position: Duration(milliseconds: startPosition),
    );
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
    await _audioPlayer.stop();
    _stopProgressTracking();
    if (resetPosition) {
      _currentPosition = 0;
      _onProgress?.call(0, _totalDuration);
    }
  }

  /// 暂停播放
  Future<void> pause() async {
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
