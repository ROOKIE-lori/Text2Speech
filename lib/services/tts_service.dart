import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  double _currentRate = 1.0; // 保存当前速度值
  VoidCallback? _onComplete;
  Function(String)? _onError;
  Function(int, int)? _onProgress; // 进度回调 (currentPosition, totalDuration)
  
  Timer? _progressTimer;
  int _currentPosition = 0; // 当前播放位置（毫秒）
  int _totalDuration = 0; // 总时长（毫秒）
  String _currentText = ''; // 当前播放的文字
  int _currentTextIndex = 0; // 当前播放到的文字索引位置

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 设置语言
    await _flutterTts.setLanguage('zh-CN'); // 中文（中国）
    
    // 优化音色参数，使其更接近微信公众号的自然语音
    await _flutterTts.setVolume(1.0); // 音量设为最大
    // 音调设置：0.5-2.0，1.0是正常。稍低一点（0.9-0.95）会让声音更自然、不那么机械
    await _flutterTts.setPitch(0.92); // 略微降低音调，使声音更自然
    
    // 尝试选择更好的语音引擎（如果可用）
    // 注意：引擎选择在Android上更有效，iOS使用系统AVSpeechSynthesizer
    try {
      // 检查平台是否支持getEngines
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          final engines = await _flutterTts.getEngines;
          if (engines.isNotEmpty) {
            // Android: 优先选择 Google TTS 或 讯飞（如果可用）
            for (var engine in engines) {
              String engineName = '';
              // 引擎可能是Map或String类型
              if (engine is Map) {
                engineName = (engine['name'] ?? engine['label'] ?? '').toString().toLowerCase();
              } else {
                engineName = engine.toString().toLowerCase();
              }
              
              // 优先选择高质量的TTS引擎
              if (engineName.contains('google') || 
                  engineName.contains('iflytek') ||
                  engineName.contains('xiaoyan') ||
                  engineName.contains('xiaoyu')) {
                try {
                  await _flutterTts.setEngine(engineName);
                  print('已选择语音引擎: $engineName');
                  break;
                } catch (e) {
                  // 如果设置失败，继续尝试下一个
                  continue;
                }
              }
            }
          }
        } catch (e) {
          // 如果获取引擎失败，使用默认引擎（不显示错误，这是正常的）
          // 某些平台或配置可能不支持getEngines方法
          // print('无法选择语音引擎，使用默认引擎: $e');
        }
      }
    } catch (e) {
      // 外层异常处理，确保不影响初始化
      // print('引擎选择过程出错，使用默认引擎: $e');
    }
    
    // iOS: AVSpeechSynthesizer 已经比较自然
    // Android: 如果系统有更好的TTS引擎，会优先使用
    
    // 监听播放完成
    _flutterTts.setCompletionHandler(() {
      _stopProgressTracking();
      _currentPosition = _totalDuration;
      _onProgress?.call(_currentPosition, _totalDuration);
      _onComplete?.call();
    });

    // 监听错误
    _flutterTts.setErrorHandler((msg) {
      _onError?.call(msg);
    });

    _isInitialized = true;
  }

  void setOnComplete(VoidCallback? callback) {
    _onComplete = callback;
  }

  void setOnError(Function(String)? callback) {
    _onError = callback;
  }

  void setOnProgress(Function(int, int)? callback) {
    _onProgress = callback;
  }

  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  Future<void> setSpeechRate(double rate) async {
    // 保存用户输入的原始速度值
    // 滑块范围：0.5-1.5（让1.0x在中间，对称范围）
    _currentRate = rate.clamp(0.5, 1.5);
    
    // flutter_tts的speechRate在不同平台上有不同范围和行为：
    // - iOS: 0.0-1.0，其中 0.0 最慢，0.5 大约是正常速度，1.0 是快速
    // - Android: 通常 0.0-2.0，其中 1.0 是正常速度
      // - iOS/Android: 0.0-1.0，其中 1.0 是正常速度
    // 
    // 映射规则（滑块值直接使用，0.5x-1.5x）：
    // 0.5x -> 0.25 (慢速)
    // 1.0x -> 0.5 (正常)
    // 1.5x -> 0.75 (快速)
    // 公式：speechRate = rate * 0.5
    
    // 稍微降低语速可以让声音更自然（类似微信公众号）
    double mappedRate = _currentRate * 0.5;
    
    // 确保TTS已初始化
    if (!_isInitialized) {
      await initialize();
    }
    
    await _flutterTts.setSpeechRate(mappedRate);
  }

  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  Future<void> speak(String text, {int startPosition = 0}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (text.isEmpty) return;
    
    _currentText = text;
    
    // 估算总时长：假设中文每分钟约200-300字，根据速度调整
    // 正常速度(0.5)约每分钟250字，即每字约240毫秒
    double charsPerMinute = 250 * (_currentRate * 0.5) / 0.5; // 根据速度调整
    double msPerChar = 60000 / charsPerMinute;
    
    // 始终重新计算总时长，确保准确性
    _totalDuration = (text.length * msPerChar).round();
    
    // 如果指定了起始位置，需要计算从哪个字符开始播放
    String textToSpeak = text;
    if (startPosition > 0) {
      // 根据时间位置计算字符索引
      int charIndex = (startPosition / msPerChar).round();
      
      if (charIndex > 0 && charIndex < text.length) {
        textToSpeak = text.substring(charIndex);
        _currentTextIndex = charIndex;
      } else {
        _currentTextIndex = 0;
      }
    } else {
      _currentTextIndex = 0;
      _currentPosition = 0;
    }
    
    // 更新当前位置（确保使用传入的起始位置）
    _currentPosition = startPosition;
    
    // 开始播放
    double mappedRate = _currentRate * 0.5;
    await _flutterTts.setSpeechRate(mappedRate);
    
    // 启动进度追踪（传入起始位置）
    _startProgressTracking(startPosition);
    
    // 立即通知一次当前位置，确保UI显示正确
    if (_onProgress != null && _totalDuration > 0) {
      _onProgress!(_currentPosition, _totalDuration);
    }
    
    await _flutterTts.speak(textToSpeak);
  }

  void _startProgressTracking([int startPosition = 0]) {
    _stopProgressTracking();
    
    // 确保使用传入的起始位置
    _currentPosition = startPosition;
    
    // 立即通知一次初始进度
    if (_onProgress != null && _totalDuration > 0) {
      _onProgress!(_currentPosition, _totalDuration);
    }
    
    // 只有在总时长大于0时才启动进度追踪
    if (_totalDuration > 0) {
      _progressTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
        // 更新当前位置（基于时间估算，每250ms增加250ms）
        _currentPosition += 250;
        
        // 通知进度更新
        if (_onProgress != null) {
          _onProgress!(_currentPosition, _totalDuration);
        }
        
        // 如果播放完成或超过总时长，停止计时器
        if (_currentPosition >= _totalDuration) {
          _stopProgressTracking();
          _currentPosition = _totalDuration;
          if (_onProgress != null) {
            _onProgress!(_currentPosition, _totalDuration);
          }
        }
      });
    }
  }

  void _stopProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  int getCurrentPosition() => _currentPosition;
  int getTotalDuration() => _totalDuration;

  Future<void> stop({bool resetPosition = false}) async {
    await _flutterTts.stop();
    _stopProgressTracking();
    // 根据参数决定是否重置位置（拖动时不重置）
    if (resetPosition) {
      _currentPosition = 0;
      _currentTextIndex = 0;
      // 通知UI重置进度
      _onProgress?.call(0, _totalDuration);
    }
    // 如果不重置，保持当前位置（用于拖动时保持位置）
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    _stopProgressTracking();
    // 保持当前位置，以便恢复播放
    // 通知UI当前进度（暂停时的位置）
    _onProgress?.call(_currentPosition, _totalDuration);
  }

  Future<void> seekBackward(int seconds) async {
    // 后退指定秒数
    int newPosition = (_currentPosition - seconds * 1000).clamp(0, _totalDuration);
    await _navigateToPosition(newPosition);
  }

  Future<void> seekForward(int seconds) async {
    // 快进指定秒数
    int newPosition = (_currentPosition + seconds * 1000).clamp(0, _totalDuration);
    await _navigateToPosition(newPosition);
  }

  Future<void> seekToPosition(int positionInMs) async {
    // 跳转到指定位置（毫秒）
    await _navigateToPosition(positionInMs);
  }

  Future<void> _navigateToPosition(int position) async {
    // 先更新位置，确保位置正确
    if (_totalDuration > 0) {
      _currentPosition = position.clamp(0, _totalDuration);
    } else {
      _currentPosition = position;
    }
    
    // 立即通知UI更新位置（在停止之前）
    if (_onProgress != null) {
      _onProgress!(_currentPosition, _totalDuration);
    }
    
    // 停止当前播放
    await _flutterTts.stop();
    _stopProgressTracking();
    
    // 再次确保位置正确（防止被stop()重置）
    if (_totalDuration > 0) {
      _currentPosition = position.clamp(0, _totalDuration);
    } else {
      _currentPosition = position;
    }
    
    // 再次通知UI更新位置
    if (_onProgress != null) {
      _onProgress!(_currentPosition, _totalDuration);
    }
    
    // 注意：不在这里自动播放，让调用者决定是否继续播放
    // 这样可以避免在快进/快退时自动播放
  }

  Future<List<dynamic>> getLanguages() async {
    return await _flutterTts.getLanguages;
  }

  Future<List<dynamic>> getEngines() async {
    return await _flutterTts.getEngines;
  }

  void dispose() {
    _stopProgressTracking();
    _flutterTts.stop();
  }
}
