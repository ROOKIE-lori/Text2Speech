import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/text_extractor.dart';
import '../services/tts_service.dart';
import '../services/file_backup_service.dart';
import '../widgets/text_display_card.dart';
import '../widgets/playback_controls.dart';
import '../widgets/minimized_playback_controls.dart';
import '../widgets/playlist_bottom_sheet.dart';
import '../widgets/model_download_widget.dart';
import '../models/playlist_item.dart';
import '../services/sherpa_offline_tts_service.dart';
import '../services/model_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _extractedText = '';
  String _originalText = ''; // 原始文本，用于检测是否有修改
  String? _selectedFileName;
  String? _selectedFilePath;
  bool _isLoading = false;
  final TTSService _ttsService = TTSService();
  final SherpaOfflineTTSService _sherpaTtsService = SherpaOfflineTTSService();
  final ModelManager _modelManager = ModelManager();
  bool _useSherpaOnnx = false; // 是否使用 Sherpa-ONNX（当前暂未实现，自动回退到 flutter_tts）
  bool _isPlaying = false;
  bool _isMinimized = false; // 是否最小化播放控制
  int _currentPosition = 0; // 当前播放位置（秒）
  int _totalDuration = 0; // 总时长（秒）
  List<PlaylistItem> _playlist = []; // 播放列表
  int _currentPlaylistIndex = -1; // 当前播放的列表索引
  VoiceType _currentVoiceType = VoiceType.female; // 当前使用的语音类型

  @override
  void initState() {
    super.initState();
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    await _ttsService.initialize();
    await _ttsService.setLanguage('zh-CN'); // 设置中文
    // 确保初始速度设置为1.0x（正常速度）
    await _ttsService.setSpeechRate(1.0);
    
    // 设置播放完成回调
    _ttsService.setOnComplete(() {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = 0;
        });
        // 自动播放下一个文件
        _playNext();
      }
    });
    
    // 设置进度回调
    _ttsService.setOnProgress((currentPosition, totalDuration) {
      if (mounted) {
        setState(() {
          _currentPosition = (currentPosition / 1000).round(); // 转换为秒
          _totalDuration = (totalDuration / 1000).round(); // 转换为秒
        });
      }
    });
    
    // 设置错误回调
    _ttsService.setOnError((msg) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放错误: $msg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
          _selectedFileName = result.files.single.name;
        });

        final filePath = result.files.single.path!;
        final file = File(filePath);
        
        // 提取文字
        final text = await TextExtractor.extractText(file, filePath);
        
        if (text.isNotEmpty) {
          // 备份文件到 Text2Voice 文件夹
          String? backupFilePath;
          try {
            backupFilePath = await FileBackupService.backupFile(
              result.files.single.name,
              text,
            );
          } catch (e) {
            // 备份失败不影响主流程，只记录错误
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('文件备份失败: $e'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
          
          // 添加到播放列表的第一个位置
          final playlistItem = PlaylistItem(
            fileName: result.files.single.name,
            filePath: backupFilePath ?? filePath, // 使用备份路径，如果备份失败则使用原路径
            text: text,
            addedAt: DateTime.now(),
          );
          
          setState(() {
            _playlist.insert(0, playlistItem);
            _extractedText = text;
            _originalText = text; // 保存原始文本
            _selectedFileName = result.files.single.name;
            _selectedFilePath = backupFilePath ?? filePath;
            _currentPlaylistIndex = 0; // 设置为当前播放项
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('未能从文件中提取文字，请检查文件格式'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文件处理失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _playText() async {
    if (_extractedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择并提取文字内容'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isPlaying = true;
    });

    // 从当前位置继续播放（如果已播放过，从暂停位置继续）
    int startPosition = _currentPosition * 1000; // 转换为毫秒
    
    // 根据当前使用的 TTS 服务选择不同的实现
    if (_useSherpaOnnx) {
      // 使用 Sherpa-ONNX 服务（当前暂未实现，自动回退到 flutter_tts）
      try {
        await _sherpaTtsService.speak(_extractedText, startPosition: startPosition);
        // 立即更新一次进度，确保UI显示正确
        setState(() {
          _currentPosition = (startPosition / 1000).round();
          _totalDuration = (_sherpaTtsService.getTotalDuration() / 1000).round();
        });
      } catch (e) {
        // 如果 Sherpa-ONNX 未实现，自动回退到 flutter_tts
        print('⚠️ Sherpa-ONNX 不可用，自动回退到系统 TTS: $e');
        setState(() {
          _useSherpaOnnx = false; // 自动禁用 Sherpa-ONNX
          _isPlaying = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sherpa-ONNX 功能暂未实现，已切换到系统 TTS。\n'
                '模型已下载，但需要原生库集成才能使用。'
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        
        // 使用系统 TTS 继续播放
        await _ttsService.speak(_extractedText, startPosition: startPosition);
        setState(() {
          _isPlaying = true;
          _currentPosition = (startPosition / 1000).round();
          _totalDuration = (_ttsService.getTotalDuration() / 1000).round();
        });
        return;
      }
    } else {
      // 使用默认 TTS 服务
      await _ttsService.speak(_extractedText, startPosition: startPosition);
      // 立即更新一次进度，确保UI显示正确
      setState(() {
        _currentPosition = (startPosition / 1000).round();
        _totalDuration = (_ttsService.getTotalDuration() / 1000).round();
      });
    }
    
    // 注意：播放状态会在完成回调中更新
  }

  Future<void> _pausePlayback() async {
    if (_useSherpaOnnx) {
      await _sherpaTtsService.pause();
    } else {
      await _ttsService.pause();
    }
    setState(() {
      _isPlaying = false;
    });
    // 保持当前位置，以便恢复播放
  }

  Future<void> _seekBackward() async {
    if (_extractedText.isEmpty) return;
    
    bool wasPlaying = _isPlaying;
    
    // 停止当前播放
    await _ttsService.stop();
    setState(() {
      _isPlaying = false;
    });
    
    // 后退15秒
    await _ttsService.seekBackward(15);
    
    // 更新位置
    setState(() {
      _currentPosition = (_ttsService.getCurrentPosition() / 1000).round();
      _totalDuration = (_ttsService.getTotalDuration() / 1000).round();
    });
    
    // 如果之前在播放，继续播放
    if (wasPlaying) {
      setState(() {
        _isPlaying = true;
      });
      int startPos = _ttsService.getCurrentPosition();
      await _ttsService.speak(_extractedText, startPosition: startPos);
      // 立即更新一次进度，确保UI显示正确
      setState(() {
        _currentPosition = (startPos / 1000).round();
        _totalDuration = (_ttsService.getTotalDuration() / 1000).round();
      });
    }
  }

  Future<void> _seekForward() async {
    if (_extractedText.isEmpty) return;
    
    bool wasPlaying = _isPlaying;
    
    // 停止当前播放
    await _ttsService.stop();
    setState(() {
      _isPlaying = false;
    });
    
    // 快进30秒
    await _ttsService.seekForward(30);
    
    // 更新位置
    setState(() {
      _currentPosition = (_ttsService.getCurrentPosition() / 1000).round();
      _totalDuration = (_ttsService.getTotalDuration() / 1000).round();
    });
    
    // 如果之前在播放，继续播放
    if (wasPlaying) {
      setState(() {
        _isPlaying = true;
      });
      int startPos = _ttsService.getCurrentPosition();
      await _ttsService.speak(_extractedText, startPosition: startPos);
      // 立即更新一次进度，确保UI显示正确
      setState(() {
        _currentPosition = (startPos / 1000).round();
        _totalDuration = (_ttsService.getTotalDuration() / 1000).round();
      });
    }
  }

  Future<void> _onSeek(double positionInSeconds) async {
    if (_extractedText.isEmpty) return;
    
    bool wasPlaying = _isPlaying;
    
    // 立即更新位置，确保UI立即显示拖动的位置
    int newPositionSeconds = positionInSeconds.round().clamp(0, _totalDuration);
    int positionInMs = (newPositionSeconds * 1000);
    
    // 检查是否拖动到结束位置（距离结束小于1秒视为结束位置）
    bool isAtEnd = _totalDuration > 0 && newPositionSeconds >= (_totalDuration - 1);
    
    // 先更新UI位置，让滑块保持在拖动位置
    setState(() {
      _currentPosition = newPositionSeconds;
      _isPlaying = false;
    });
    
    // 停止当前播放和进度追踪
    await _ttsService.stop();
    
    // 再次确保位置正确（防止被stop()重置）
    setState(() {
      _currentPosition = newPositionSeconds;
    });
    
    // 如果之前在播放，且不是拖动到结束位置，从新位置继续播放
    // 如果拖动到结束位置，不自动播放，避免立即触发完成回调导致切换到下一个文件
    if (wasPlaying && !isAtEnd) {
      // 从新位置开始播放
      await _ttsService.speak(_extractedText, startPosition: positionInMs);
      // 确保播放状态和位置正确
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _currentPosition = newPositionSeconds;
        });
      }
    } else {
      // 如果没有在播放，或者拖动到结束位置，只更新位置，不播放
      await _ttsService.seekToPosition(positionInMs);
      // 确保位置正确
      if (mounted) {
        setState(() {
          _currentPosition = newPositionSeconds;
        });
      }
    }
  }

  void _toggleMinimize() {
    setState(() {
      _isMinimized = !_isMinimized;
    });
  }

  /// 显示模型下载底部弹窗
  void _showModelDownloadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // 拖拽指示器
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '语音模型下载',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // 模型下载组件
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16.0),
                  child: ModelDownloadWidget(
                    onModelReady: () async {
                      // 模型下载完成后，自动切换到新模型
                      if (mounted) {
                        // 获取当前选择的语音类型（从 ModelManager）
                        final selectedVoiceType = _modelManager.currentVoiceType;
                        
                        Navigator.pop(context); // 关闭底部弹窗
                        
                        // 更新当前语音类型
                        setState(() {
                          _currentVoiceType = selectedVoiceType;
                        });
                        
                        // 设置 TTS 服务的语音类型
                        _sherpaTtsService.setVoiceType(selectedVoiceType);
                        
                        // 尝试初始化 Sherpa-ONNX，如果成功则启用，否则保持使用系统 TTS
                        try {
                          await _initializeSherpaTTS();
                          // 初始化成功，启用 Sherpa-ONNX
                          if (mounted) {
                            setState(() {
                              _useSherpaOnnx = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${_getVoiceTypeName(selectedVoiceType)}模型已下载并切换成功，已启用 Sherpa-ONNX'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          // 如果初始化失败，保持使用系统 TTS（不启用 Sherpa-ONNX）
                          if (mounted) {
                            setState(() {
                              _useSherpaOnnx = false; // 确保不启用
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '模型已下载，但初始化失败，继续使用系统 TTS。\n'
                                  '错误: $e'
                                ),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取语音类型名称
  String _getVoiceTypeName(VoiceType voiceType) {
    return voiceType == VoiceType.male ? '男声' : '女声';
  }
  
  /// 初始化 Sherpa-ONNX TTS 服务
  Future<void> _initializeSherpaTTS() async {
    try {
      await _sherpaTtsService.initialize();
      // 设置回调
      _sherpaTtsService.setOnComplete(() {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentPosition = 0;
          });
          _playNext();
        }
      });
      _sherpaTtsService.setOnProgress((currentPosition, totalDuration) {
        if (mounted) {
          setState(() {
            _currentPosition = (currentPosition / 1000).round();
            _totalDuration = (totalDuration / 1000).round();
          });
        }
      });
      _sherpaTtsService.setOnError((msg) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('播放错误: $msg'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化语音模型失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPlaylist() async {
    // 打开播放列表时，加载备份文件夹中的文件
    await _loadBackedUpFiles();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) => PlaylistBottomSheet(
            playlist: _playlist,
            currentIndex: _currentPlaylistIndex,
            scrollController: scrollController,
            onAddFile: () async {
              // 添加文件功能
              await _pickFile();
              // 更新 bottom sheet 的状态，使其刷新显示
              if (mounted) {
                setModalState(() {});
              }
            },
            isLoading: _isLoading,
            onItemTap: (index) async {
              // 先关闭 bottom sheet
              Navigator.pop(context);
              // 等待一下，确保 bottom sheet 完全关闭
              await Future.delayed(const Duration(milliseconds: 200));
              // 然后处理点击事件（包括弹窗提示）
              if (mounted) {
                await _handlePlaylistItemTap(index);
              }
            },
          onItemDelete: (index) async {
            if (index < 0 || index >= _playlist.length) return;
            
            final item = _playlist[index];
            
            // 如果是备份文件，删除备份
            if (item.filePath.contains('Text2Voice')) {
              try {
                await FileBackupService.deleteBackupFile(item.filePath);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('删除文件失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return; // 删除失败，不继续
              }
            }
            
            // 从播放列表中移除
            if (mounted) {
              setState(() {
                _playlist.removeAt(index);
                // 如果删除的是当前播放项，调整索引
                if (index == _currentPlaylistIndex) {
                  _currentPlaylistIndex = -1;
                  _extractedText = '';
                  _originalText = '';
                  _selectedFileName = null;
                  _selectedFilePath = null;
                  _isPlaying = false;
                  _currentPosition = 0;
                  _totalDuration = 0;
                  _ttsService.stop();
                } else if (index < _currentPlaylistIndex) {
                  _currentPlaylistIndex--;
                }
              });
              
              // 更新 bottom sheet 的状态，使其刷新显示
              setModalState(() {});
              
              // 显示删除成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已删除 "${item.fileName}"'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          ),
        ),
      ),
    );
  }

  /// 加载备份文件夹中的文件
  Future<void> _loadBackedUpFiles() async {
    try {
      final backedUpFiles = await FileBackupService.loadBackedUpFiles();
      
      // 将备份文件添加到播放列表（排除已存在的文件）
      for (final backupItem in backedUpFiles) {
        // 检查是否已存在于播放列表中（通过文件路径判断）
        final exists = _playlist.any((item) => item.filePath == backupItem.filePath);
        
        if (!exists) {
          final playlistItem = PlaylistItem(
            fileName: backupItem.fileName,
            filePath: backupItem.filePath,
            text: backupItem.textContent,
            addedAt: backupItem.addedAt,
          );
          
          setState(() {
            _playlist.add(playlistItem);
          });
        }
      }
      
      // 按添加时间排序，最新的在前
      setState(() {
        _playlist.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        // 重新设置当前播放索引
        if (_currentPlaylistIndex >= 0 && _currentPlaylistIndex < _playlist.length) {
          // 找到当前文件的新索引
          final currentItem = _currentPlaylistIndex < _playlist.length 
              ? _playlist[_currentPlaylistIndex] 
              : null;
          if (currentItem != null) {
            _currentPlaylistIndex = _playlist.indexWhere(
              (item) => item.filePath == currentItem.filePath,
            );
          }
        }
      });
    } catch (e) {
      // 加载失败不影响主流程
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载备份文件失败: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handlePlaylistItemTap(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    if (!mounted) return;
    
    // 如果点击的是当前正在播放的项，不做任何操作
    if (index == _currentPlaylistIndex && _isPlaying) {
      return;
    }
    
    // 保存之前的播放状态
    bool wasPlaying = _isPlaying;
    
    // 如果当前正在播放其他文件，弹出确认对话框
    if (_isPlaying && index != _currentPlaylistIndex) {
      final shouldSwitch = await _showPlatformDialog(
        context: context,
        title: '切换播放',
        message: '当前正在播放 "${_playlist[_currentPlaylistIndex].fileName}"，是否切换到 "${_playlist[index].fileName}"？',
        confirmText: '确定',
        cancelText: '取消',
      );
      
      if (shouldSwitch != true || !mounted) {
        return; // 用户取消切换
      }
    }
    
    // 先停止当前播放
    if (wasPlaying) {
      await _ttsService.stop();
    }
    
    // 切换到选中的文件（等待切换完成）
    await _switchToPlaylistItem(index);
    
    // 如果之前在播放，继续播放新文件
    if (wasPlaying && mounted) {
      // 等待一下，确保状态更新完成
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        await _playText();
      }
    }
  }

  /// 切换到播放列表中的指定项（不自动播放）
  Future<void> _switchToPlaylistItem(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    
    // 如果当前文件有未保存的修改，先提示保存
    if (_hasUnsavedChanges()) {
      final shouldSave = await _showSaveDialog();
      if (shouldSave == true) {
        await _saveCurrentFile();
      }
      // 如果用户取消保存，不切换文件
      if (shouldSave == null) {
        return;
      }
    }
    
    final item = _playlist[index];
    
    // 先停止当前播放（如果正在播放）
    if (_isPlaying) {
      await _ttsService.stop();
    }
    
    // 更新状态，确保UI立即显示新的文件内容
    if (mounted) {
      setState(() {
        _currentPlaylistIndex = index;
        _extractedText = item.text;
        _originalText = item.text; // 保存原始文本
        _selectedFileName = item.fileName;
        _selectedFilePath = item.filePath;
        _currentPosition = 0;
        _totalDuration = 0; // 重置总时长
        _isPlaying = false;
      });
    }
  }

  void _playPlaylistItem(int index) {
    if (index < 0 || index >= _playlist.length) return;
    
    // 先切换到该文件
    _switchToPlaylistItem(index);
    
    // 然后开始播放
    Future.microtask(() {
      if (mounted) {
        _playText();
      }
    });
  }

  void _playNext() {
    if (_currentPlaylistIndex >= 0 && _currentPlaylistIndex < _playlist.length - 1) {
      // 播放下一个
      _playPlaylistItem(_currentPlaylistIndex + 1);
    } else {
      // 播放列表结束
      setState(() {
        _isPlaying = false;
        _currentPosition = 0;
      });
    }
  }

  /// 检查是否有未保存的修改
  bool _hasUnsavedChanges() {
    return _extractedText != _originalText && _selectedFilePath != null;
  }

  /// 检查并保存更改
  Future<void> _checkAndSaveChanges() async {
    if (_hasUnsavedChanges() && _selectedFilePath != null) {
      final shouldSave = await _showSaveDialog();
      if (shouldSave == true) {
        await _saveCurrentFile();
      }
    }
  }

  /// 显示保存对话框
  Future<bool?> _showSaveDialog() async {
    if (!mounted) return false;
    return await _showPlatformDialog(
      context: context,
      title: '保存更改',
      message: '文件内容已修改，是否保存？',
      confirmText: '保存',
      cancelText: '不保存',
    );
  }

  /// 保存当前文件
  Future<void> _saveCurrentFile() async {
    if (_selectedFilePath == null || !_hasUnsavedChanges()) return;
    
    try {
      // 检查是否是备份文件
      if (_selectedFilePath!.contains('Text2Voice')) {
        // 更新备份文件
        await FileBackupService.updateBackupFile(_selectedFilePath!, _extractedText);
        
        // 更新播放列表中的文本
        if (_currentPlaylistIndex >= 0 && _currentPlaylistIndex < _playlist.length) {
          setState(() {
            _playlist[_currentPlaylistIndex] = PlaylistItem(
              fileName: _playlist[_currentPlaylistIndex].fileName,
              filePath: _playlist[_currentPlaylistIndex].filePath,
              text: _extractedText,
              addedAt: _playlist[_currentPlaylistIndex].addedAt,
            );
          });
        }
        
        // 更新原始文本
        setState(() {
          _originalText = _extractedText;
        });
      } else {
        // 如果不是备份文件，创建新的备份
        final backupFilePath = await FileBackupService.backupFile(
          _selectedFileName ?? 'untitled.txt',
          _extractedText,
        );
        
        // 更新播放列表中的文件路径
        if (_currentPlaylistIndex >= 0 && _currentPlaylistIndex < _playlist.length) {
          setState(() {
            _playlist[_currentPlaylistIndex] = PlaylistItem(
              fileName: _playlist[_currentPlaylistIndex].fileName,
              filePath: backupFilePath,
              text: _extractedText,
              addedAt: _playlist[_currentPlaylistIndex].addedAt,
            );
            _selectedFilePath = backupFilePath;
            _originalText = _extractedText;
          });
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('文件已保存'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 根据平台显示不同的对话框风格
  Future<bool?> _showPlatformDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = '确定',
    String cancelText = '取消',
  }) async {
    if (Platform.isIOS) {
      // iOS 使用 Cupertino 风格，使用 rootNavigator 确保对话框显示在最上层
      return showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelText),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmText),
            ),
          ],
        ),
      );
    } else {
      // Android 使用 Material 风格，使用 rootNavigator 确保对话框显示在最上层
      return showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmText),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _extractedText.isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.queue_music, size: 28),
          onPressed: _showPlaylist,
          tooltip: '播放列表',
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        title: const Text(
          'Text2Voice',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          // 文件选择按钮
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.add_circle_outline, size: 28),
            onPressed: _isLoading ? null : _pickFile,
            tooltip: '添加文件',
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // 点击空白处收起键盘
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            // 主要内容（固定布局，不可滑动）
            SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: hasText && _isMinimized ? 80.0 : 16.0, // 为底部最小化控制留出空间
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 文字显示卡片（如果有文字内容）- 内容区域可滚动和编辑
                    if (hasText || _isLoading)
                      Expanded(
                        child: TextDisplayCard(
                          text: _extractedText,
                          isLoading: _isLoading,
                          onTextChanged: (text) {
                            setState(() {
                              _extractedText = text;
                            });
                          },
                          onEditingComplete: () {
                            // 编辑完成时，检查是否有修改并提示保存
                            _checkAndSaveChanges();
                          },
                        ),
                      ),
                    
                    // 完整的播放控制（只在非最小化时显示）
                    if (!_isMinimized)
                      AnimatedScale(
                        scale: _isMinimized ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: PlaybackControls(
                          isPlaying: _isPlaying,
                          onPlay: _playText,
                          onPause: _pausePlayback,
                          onSeekBackward: _seekBackward,
                          onSeekForward: _seekForward,
                          currentPosition: _currentPosition,
                          totalDuration: _totalDuration,
                          hasText: hasText,
                          fileName: _selectedFileName,
                          onSeek: _onSeek,
                          onSwitchVoice: _showModelDownloadSheet,
                          currentVoiceType: _useSherpaOnnx ? _getVoiceTypeName(_currentVoiceType) : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          // 底部最小化播放控制（只在有文字且最小化时显示）
          if (hasText && _isMinimized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: _isMinimized ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: AnimatedScale(
                  scale: _isMinimized ? 1.0 : 0.8,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: MinimizedPlaybackControls(
                    isPlaying: _isPlaying,
                    onPlay: _playText,
                    onPause: _pausePlayback,
                    onExpand: _toggleMinimize,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
