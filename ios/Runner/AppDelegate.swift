import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 注册平台通道
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.text2voice/sherpa_onnx_tts",
      binaryMessenger: controller.binaryMessenger
    )
    
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "initialize":
        self.handleInitialize(call: call, result: result)
      case "synthesize":
        self.handleSynthesize(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
  
  private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let modelDir = args["modelDir"] as? String,
          let modelPath = args["modelPath"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "参数错误", details: nil))
      return
    }
    
    print("🎤 初始化 Sherpa-ONNX")
    print("模型目录: \(modelDir)")
    print("模型文件: \(modelPath)")
    
    // TODO: 初始化 Sherpa-ONNX 库
    // 这里需要：
    // 1. 加载 Sherpa-ONNX framework
    // 2. 初始化 TTS 引擎
    // 3. 加载模型文件
    
    // 临时实现：返回成功（实际需要实现原生库集成）
    result(true)
  }
  
  private func handleSynthesize(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let text = args["text"] as? String,
          let modelPath = args["modelPath"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "参数错误", details: nil))
      return
    }
    
    let speed = args["speed"] as? Double ?? 1.0
    
    print("🎤 合成语音: \(text)")
    print("模型路径: \(modelPath)")
    print("语速: \(speed)")
    
    // TODO: 调用 Sherpa-ONNX 进行 TTS 合成
    // 这里需要：
    // 1. 调用 sherpa-onnx C++ API 进行合成
    // 2. 返回音频数据（WAV 格式的字节数组）
    
    // 临时实现：返回错误（实际需要实现原生库集成）
    result(FlutterError(
      code: "NOT_IMPLEMENTED",
      message: "Sherpa-ONNX 原生库集成尚未完成。\n需要编译或获取 Sherpa-ONNX framework 并实现绑定。\n请参考 SHERPA_ONNX_INTEGRATION.md 了解详细步骤。",
      details: nil
    ))
  }
}
