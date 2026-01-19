import 'package:flutter/material.dart';
import 'dart:math' as math;

class PlaybackControls extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final int currentPosition; // 当前播放位置（秒）
  final int totalDuration; // 总时长（秒）
  final bool hasText;
  final String? fileName; // 文件名
  final ValueChanged<double>? onSeek; // 拖动进度条的回调
  final VoidCallback? onSwitchVoice; // 切换语音的回调
  final String? currentVoiceType; // 当前语音类型（"男声" 或 "女声"）

  const PlaybackControls({
    super.key,
    required this.isPlaying,
    required this.onPlay,
    required this.onPause,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.currentPosition,
    required this.totalDuration,
    required this.hasText,
    this.fileName,
    this.onSeek,
    this.onSwitchVoice,
    this.currentVoiceType,
  });

  @override
  State<PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<PlaybackControls> {
  double? _draggingValue; // 拖动时的临时值

  String _formatTime(int seconds) {
    if (seconds < 0) return '00:00';
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void didUpdateWidget(PlaybackControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果位置发生变化且不是拖动中，清除拖动值
    if (oldWidget.currentPosition != widget.currentPosition && _draggingValue == null) {
      // 位置已更新，保持同步
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在拖动，使用拖动值；否则使用实际播放位置
    final displayValue = _draggingValue ?? widget.currentPosition.clamp(0, widget.totalDuration).toDouble();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 文件标题（如果有）- 使用 GestureDetector 阻止点击事件
            if (widget.fileName != null) ...[
              GestureDetector(
                onTap: () {
                  // 阻止点击事件，防止误触导致切换文件
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.description,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.fileName!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // 播放进度显示（显示在播放键上面）
            if (widget.hasText && widget.totalDuration > 0) ...[
              // 使用 GestureDetector 包裹整个进度区域，阻止事件冒泡
              GestureDetector(
                behavior: HitTestBehavior.opaque, // 确保整个区域都能捕获事件
                onTap: () {
                  // 阻止点击事件冒泡，防止误触
                },
                onTapDown: (_) {
                  // 阻止点击事件冒泡
                },
                child: Column(
                  children: [
                    // 进度条（可拖动）
                    Slider(
                      value: displayValue,
                      min: 0,
                      max: widget.totalDuration > 0 ? widget.totalDuration.toDouble() : 1.0,
                      onChanged: widget.hasText && widget.onSeek != null
                          ? (value) {
                              // 拖动时只更新显示，不跳转
                              setState(() {
                                _draggingValue = value;
                              });
                            }
                          : null,
                      onChangeEnd: widget.hasText && widget.onSeek != null
                          ? (value) {
                              // 拖动结束时跳转到对应位置
                              // 先调用回调更新位置，确保位置立即更新
                              widget.onSeek!(value);
                              // 延迟清除拖动值，等待位置更新完成
                              Future.microtask(() {
                                if (mounted) {
                                  setState(() {
                                    _draggingValue = null;
                                  });
                                }
                              });
                            }
                          : null,
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    // 时间显示
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatTime(displayValue.round()),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          Text(
                            _formatTime(widget.totalDuration),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 切换语音按钮（位于进度条下方）
              if (widget.onSwitchVoice != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Column(
                    children: [
                      _AnimatedVoiceButton(
                        isPlaying: widget.isPlaying,
                        onPressed: widget.onSwitchVoice!,
                      ),
                      if (widget.currentVoiceType != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '当前: ${widget.currentVoiceType}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 16),
            ],
            
            // 控制按钮行
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 后退15秒按钮（左侧）
                IconButton(
                  onPressed: widget.hasText ? widget.onSeekBackward : null,
                  icon: const Icon(Icons.fast_rewind),
                  iconSize: 28,
                  color: widget.hasText
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.grey,
                  tooltip: '后退15秒',
                ),
                const SizedBox(width: 12),
                
                // 播放/暂停按钮（居中）
                IconButton(
                  onPressed: widget.hasText
                      ? (widget.isPlaying ? widget.onPause : widget.onPlay)
                      : null,
                  icon: Icon(
                    widget.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  ),
                  iconSize: 64,
                  color: widget.hasText
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                const SizedBox(width: 12),
                
                // 快进30秒按钮（右侧）
                IconButton(
                  onPressed: widget.hasText ? widget.onSeekForward : null,
                  icon: const Icon(Icons.fast_forward),
                  iconSize: 28,
                  color: widget.hasText
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.grey,
                  tooltip: '快进30秒',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 带动画的语音切换按钮
class _AnimatedVoiceButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _AnimatedVoiceButton({
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  State<_AnimatedVoiceButton> createState() => _AnimatedVoiceButtonState();
}

class _AnimatedVoiceButtonState extends State<_AnimatedVoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2),
        weight: 0.5,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 0.5,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_AnimatedVoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      // 开始播放，启动动画
      _controller.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      // 停止播放，停止动画
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: widget.isPlaying ? _rotationAnimation.value : 0,
          child: Transform.scale(
            scale: widget.isPlaying ? _scaleAnimation.value : 1.0,
            child: IconButton(
              onPressed: widget.onPressed,
              icon: Icon(
                widget.isPlaying ? Icons.record_voice_over : Icons.voice_over_off,
              ),
              iconSize: 24,
              color: Theme.of(context).colorScheme.primary,
              tooltip: '切换语音模型',
            ),
          ),
        );
      },
    );
  }
}
