import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/model_manager.dart';
import '../services/sherpa_offline_tts_service.dart';

/// 模型下载和状态显示组件
class ModelDownloadWidget extends StatefulWidget {
  final VoidCallback? onModelReady;
  final String? modelDownloadUrl;

  const ModelDownloadWidget({
    super.key,
    this.onModelReady,
    this.modelDownloadUrl,
  });

  @override
  State<ModelDownloadWidget> createState() => _ModelDownloadWidgetState();
}

class _ModelDownloadWidgetState extends State<ModelDownloadWidget> {
  final ModelManager _modelManager = ModelManager();
  final SherpaOfflineTTSService _ttsService = SherpaOfflineTTSService();
  
  ModelDownloadState _state = ModelDownloadState.checking;
  double _downloadProgress = 0.0;
  String _statusText = '检查模型状态...';
  String? _errorMessage;
  String? _extractingFileName;
  int _extractingFileIndex = 0;
  int _totalFiles = 0;
  CancelToken? _cancelToken;
  VoiceType _selectedVoiceType = VoiceType.female; // 当前选择的语音类型

  @override
  void initState() {
    super.initState();
    _initializeVoiceType();
    _checkModelStatus();
  }
  
  /// 初始化语音类型：检查已下载的模型，自动选择
  Future<void> _initializeVoiceType() async {
    try {
      // 检查女声模型是否已下载
      final femaleDownloaded = await _modelManager.isModelDownloaded(voiceType: VoiceType.female);
      // 检查男声模型是否已下载
      final maleDownloaded = await _modelManager.isModelDownloaded(voiceType: VoiceType.male);
      
      if (mounted) {
        setState(() {
          // 如果女声已下载，优先使用女声；否则使用男声；如果都没下载，默认女声
          if (femaleDownloaded) {
            _selectedVoiceType = VoiceType.female;
          } else if (maleDownloaded) {
            _selectedVoiceType = VoiceType.male;
          } else {
            _selectedVoiceType = VoiceType.female; // 默认女声
          }
        });
      }
    } catch (e) {
      // 如果检查失败，使用默认值
      if (mounted) {
        setState(() {
          _selectedVoiceType = VoiceType.female;
        });
      }
    }
  }

  /// 检查模型状态
  Future<void> _checkModelStatus() async {
    setState(() {
      _state = ModelDownloadState.checking;
      _statusText = '检查模型状态...';
    });

    try {
      // 更新 ModelManager 的语音类型
      _modelManager.setVoiceType(_selectedVoiceType);
      
      // 检查当前选择的语音类型是否已下载
      final isDownloaded = await _modelManager.isModelDownloaded(voiceType: _selectedVoiceType);
      
      if (mounted) {
        setState(() {
          if (isDownloaded) {
            _state = ModelDownloadState.ready;
            _statusText = '${_getVoiceTypeName(_selectedVoiceType)}模型已就绪';
          } else {
            _state = ModelDownloadState.notDownloaded;
            _statusText = '${_getVoiceTypeName(_selectedVoiceType)}模型未下载';
          }
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = ModelDownloadState.error;
          _statusText = '检查失败';
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  /// 获取语音类型名称
  String _getVoiceTypeName(VoiceType voiceType) {
    return voiceType == VoiceType.male ? '男声' : '女声';
  }
  
  /// 切换语音类型
  Future<void> _switchVoiceType(VoiceType newVoiceType) async {
    if (_selectedVoiceType == newVoiceType) return;
    
    setState(() {
      _selectedVoiceType = newVoiceType;
    });
    
    // 重新检查新语音类型的模型状态
    await _checkModelStatus();
  }

  /// 开始下载模型
  Future<void> _downloadModel() async {
    setState(() {
      _state = ModelDownloadState.downloading;
      _statusText = '准备下载${_getVoiceTypeName(_selectedVoiceType)}模型...';
      _downloadProgress = 0.0;
      _errorMessage = null;
      _cancelToken = CancelToken();
    });

    try {
      // 确保 ModelManager 使用当前选择的语音类型
      _modelManager.setVoiceType(_selectedVoiceType);
      
      await _modelManager.downloadModel(
        cancelToken: _cancelToken,
        onProgress: (downloaded, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = total > 0 ? downloaded / total : 0.0;
              
              // 当下载进度达到100%时，显示"正在解压..."
              if (_downloadProgress >= 1.0 && _state == ModelDownloadState.downloading) {
                _state = ModelDownloadState.extracting;
                _statusText = '正在解压...';
                _downloadProgress = 0.0; // 重置进度，等待解压进度更新
              } else if (_state == ModelDownloadState.downloading) {
                _statusText = '下载中: ${(_downloadProgress * 100).toStringAsFixed(1)}%';
              }
            });
          }
        },
        onExtracting: (currentFile, currentFileIndex, totalFiles) {
          if (mounted) {
            setState(() {
              _state = ModelDownloadState.extracting;
              _extractingFileName = currentFile;
              _extractingFileIndex = currentFileIndex;
              _totalFiles = totalFiles;
              _downloadProgress = totalFiles > 0 ? currentFileIndex / totalFiles : 0.0;
              final fileName = currentFile.length > 30 
                  ? '${currentFile.substring(0, 27)}...'
                  : currentFile;
              _statusText = '解压中: ($currentFileIndex/$totalFiles) $fileName';
            });
          }
        },
      );

      // 下载和解压完成，校验模型
      if (mounted) {
        setState(() {
          _state = ModelDownloadState.ready;
          _statusText = '模型已就绪';
          _downloadProgress = 1.0;
          _extractingFileName = null;
        });
        
        // 通知父组件模型已就绪
        widget.onModelReady?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('取消')) {
            _state = ModelDownloadState.notDownloaded;
            _statusText = '下载已取消';
          } else {
            _state = ModelDownloadState.error;
            _statusText = '下载失败';
            _errorMessage = e.toString();
          }
        });
      }
    }
  }

  /// 取消下载
  void _cancelDownload() {
    _cancelToken?.cancel('用户取消下载');
    setState(() {
      _state = ModelDownloadState.notDownloaded;
      _statusText = '下载已取消';
      _downloadProgress = 0.0;
    });
  }

  /// 删除模型
  Future<void> _deleteModel() async {
    try {
      await _modelManager.deleteModel();
      if (mounted) {
        await _checkModelStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('模型已删除'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 语音类型选择器
            Row(
              children: [
                Icon(
                  Icons.record_voice_over,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  '语音类型:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<VoiceType>(
                    segments: const [
                      ButtonSegment<VoiceType>(
                        value: VoiceType.female,
                        label: Text('女声'),
                        icon: Icon(Icons.woman, size: 18),
                      ),
                      ButtonSegment<VoiceType>(
                        value: VoiceType.male,
                        label: Text('男声'),
                        icon: Icon(Icons.man, size: 18),
                      ),
                    ],
                    selected: {_selectedVoiceType},
                    onSelectionChanged: (Set<VoiceType> newSelection) {
                      if (newSelection.isNotEmpty) {
                        _switchVoiceType(newSelection.first);
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 状态文字
            Row(
              children: [
                Icon(
                  _getStateIcon(),
                  color: _getStateColor(),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _getStateColor(),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 进度条（在下载中或解压中显示）
            if (_state == ModelDownloadState.downloading || _state == ModelDownloadState.extracting) ...[
              LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            
            // 错误信息（如果有）
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // 操作按钮
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton() {
    switch (_state) {
      case ModelDownloadState.checking:
        return ElevatedButton(
          onPressed: null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('检查中...'),
            ],
          ),
        );
      
      case ModelDownloadState.notDownloaded:
        return ElevatedButton.icon(
          onPressed: _downloadModel,
          icon: const Icon(Icons.download),
          label: const Text('下载模型'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        );
      
      case ModelDownloadState.downloading:
        return ElevatedButton.icon(
          onPressed: _cancelDownload,
          icon: const Icon(Icons.cancel),
          label: const Text('取消下载'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
        );
      
      case ModelDownloadState.extracting:
        return ElevatedButton(
          onPressed: null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('解压中，请稍候...'),
            ],
          ),
        );
      
      case ModelDownloadState.ready:
        return ElevatedButton.icon(
          onPressed: () {
            widget.onModelReady?.call();
          },
          icon: const Icon(Icons.check_circle),
          label: const Text('模型已就绪'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        );
      
      case ModelDownloadState.error:
        return ElevatedButton.icon(
          onPressed: _downloadModel,
          icon: const Icon(Icons.refresh),
          label: const Text('重试下载'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
        );
    }
  }

  /// 获取状态图标
  IconData _getStateIcon() {
    switch (_state) {
      case ModelDownloadState.checking:
        return Icons.hourglass_empty;
      case ModelDownloadState.notDownloaded:
        return Icons.cloud_download;
      case ModelDownloadState.downloading:
        return Icons.downloading;
      case ModelDownloadState.extracting:
        return Icons.archive;
      case ModelDownloadState.ready:
        return Icons.check_circle;
      case ModelDownloadState.error:
        return Icons.error;
    }
  }

  /// 获取状态颜色
  Color _getStateColor() {
    switch (_state) {
      case ModelDownloadState.checking:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
      case ModelDownloadState.notDownloaded:
        return Theme.of(context).colorScheme.primary;
      case ModelDownloadState.downloading:
        return Theme.of(context).colorScheme.primary;
      case ModelDownloadState.extracting:
        return Colors.orange;
      case ModelDownloadState.ready:
        return Colors.green;
      case ModelDownloadState.error:
        return Theme.of(context).colorScheme.error;
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }
}

/// 模型下载状态
enum ModelDownloadState {
  checking,        // 检查中
  notDownloaded,   // 未下载
  downloading,     // 下载中
  extracting,      // 解压中
  ready,           // 已就绪
  error,           // 错误
}
