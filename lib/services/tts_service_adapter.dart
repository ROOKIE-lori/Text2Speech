import 'package:flutter/material.dart';
import 'dart:async';
import 'tts_service.dart';
// import 'sherpa_tts_service.dart';  // 当 sherpa-onnx 集成完成后取消注释

/// TTS 服务适配器
/// 
/// 这个类提供了一个统一的接口，可以在不同的 TTS 实现之间切换
/// 当前使用 flutter_tts，未来可以切换到 sherpa-onnx
class TTSServiceAdapter {
  // 当前使用 flutter_tts
  final TTSService _flutterTtsService = TTSService();
  
  // 未来可以切换到 sherpa-onnx
  // final SherpaTTSService _sherpaTtsService = SherpaTTSService();
  
  // 当前使用的服务
  // bool _useSherpaOnnx = false;  // 设置为 true 以使用 sherpa-onnx
  
  TTSService get _currentService => _flutterTtsService;
  // TTSService get _currentService => _useSherpaOnnx ? _sherpaTtsService : _flutterTtsService;

  Future<void> initialize() => _currentService.initialize();
  
  void setOnComplete(VoidCallback? callback) => _currentService.setOnComplete(callback);
  
  void setOnError(Function(String)? callback) => _currentService.setOnError(callback);
  
  void setOnProgress(Function(int, int)? callback) => _currentService.setOnProgress(callback);
  
  Future<void> setLanguage(String language) => _currentService.setLanguage(language);
  
  Future<void> setSpeechRate(double rate) => _currentService.setSpeechRate(rate);
  
  Future<void> setVolume(double volume) => _currentService.setVolume(volume);
  
  Future<void> setPitch(double pitch) => _currentService.setPitch(pitch);
  
  Future<void> speak(String text, {int startPosition = 0}) => 
      _currentService.speak(text, startPosition: startPosition);
  
  Future<void> stop({bool resetPosition = false}) => 
      _currentService.stop(resetPosition: resetPosition);
  
  Future<void> pause() => _currentService.pause();
  
  Future<void> seekBackward(int seconds) => _currentService.seekBackward(seconds);
  
  Future<void> seekForward(int seconds) => _currentService.seekForward(seconds);
  
  Future<void> seekToPosition(int positionInMs) => _currentService.seekToPosition(positionInMs);
  
  int getCurrentPosition() => _currentService.getCurrentPosition();
  
  int getTotalDuration() => _currentService.getTotalDuration();
  
  void dispose() => _currentService.dispose();
}
