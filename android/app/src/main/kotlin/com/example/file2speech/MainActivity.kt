package com.example.file2speech

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.file2speech/sherpa_onnx_tts"
    private val TAG = "SherpaOnnxTTS"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    try {
                        val modelDir = call.argument<String>("modelDir")
                        val modelPath = call.argument<String>("modelPath")
                        
                        Log.d(TAG, "初始化 Sherpa-ONNX")
                        Log.d(TAG, "模型目录: $modelDir")
                        Log.d(TAG, "模型文件: $modelPath")
                        
                        // TODO: 初始化 Sherpa-ONNX 库
                        // 这里需要：
                        // 1. 加载 libsherpa-onnx.so 库
                        // 2. 初始化 TTS 引擎
                        // 3. 加载模型文件
                        
                        // 临时实现：返回成功（实际需要实现原生库集成）
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "初始化失败", e)
                        result.error("INIT_ERROR", "初始化失败: ${e.message}", null)
                    }
                }
                "synthesize" -> {
                    try {
                        val text = call.argument<String>("text")
                        val modelPath = call.argument<String>("modelPath")
                        val speed = call.argument<Double>("speed") ?: 1.0
                        
                        Log.d(TAG, "合成语音: $text")
                        Log.d(TAG, "模型路径: $modelPath")
                        Log.d(TAG, "语速: $speed")
                        
                        // TODO: 调用 Sherpa-ONNX 进行 TTS 合成
                        // 这里需要：
                        // 1. 调用 sherpa-onnx C++ API 进行合成
                        // 2. 返回音频数据（WAV 格式的字节数组）
                        
                        // 临时实现：返回空数据（实际需要实现原生库集成）
                        result.error(
                            "NOT_IMPLEMENTED",
                            "Sherpa-ONNX 原生库集成尚未完成。\n" +
                            "需要编译或获取 libsherpa-onnx.so 库并实现 JNI 绑定。\n" +
                            "请参考 SHERPA_ONNX_INTEGRATION.md 了解详细步骤。",
                            null
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "合成失败", e)
                        result.error("SYNTHESIS_ERROR", "合成失败: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
