import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import '../models/playlist_item.dart';

class PlaylistBottomSheet extends StatelessWidget {
  final List<PlaylistItem> playlist;
  final int currentIndex;
  final Function(int) onItemTap;
  final Function(int) onItemDelete;
  final ScrollController? scrollController;
  final VoidCallback? onAddFile; // 添加文件回调
  final bool isLoading; // 是否正在加载

  const PlaylistBottomSheet({
    super.key,
    required this.playlist,
    required this.currentIndex,
    required this.onItemTap,
    required this.onItemDelete,
    this.scrollController,
    this.onAddFile,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                  '播放列表',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${playlist.length} 项',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    if (onAddFile != null) ...[
                      const SizedBox(width: 12),
                      IconButton(
                        icon: isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : const Icon(Icons.add_circle_outline, size: 28),
                        onPressed: isLoading ? null : onAddFile,
                        tooltip: '添加文件',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // 播放列表
          Expanded(
            child: playlist.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.queue_music,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '播放列表为空',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final item = playlist[index];
                      final isCurrent = index == currentIndex;
                      
                      // 获取屏幕宽度
                      final screenWidth = MediaQuery.of(context).size.width;
                      final deleteThreshold = screenWidth / 3; // 删除阈值为屏幕宽度的1/3
                      
                      return Dismissible(
                        key: Key('playlist_item_${item.filePath}_$index'),
                        direction: DismissDirection.endToStart, // 从左向右滑动（endToStart表示从右向左滑动，即左滑）
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(0),
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        // 确认删除对话框
                        confirmDismiss: (direction) async {
                          // 显示删除确认对话框
                          final shouldDelete = await _showDeleteDialog(context, item.fileName);
                          return shouldDelete == true;
                        },
                        // 删除确认后执行
                        onDismissed: (direction) {
                          onItemDelete(index);
                        },
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: isCurrent
                                  ? Icon(
                                      Icons.play_arrow,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      size: 20,
                                    )
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            item.fileName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.text.length} 字',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          onTap: () => onItemTap(index),
                          selected: isCurrent,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 显示删除确认对话框
  Future<bool?> _showDeleteDialog(BuildContext context, String fileName) async {
    if (Platform.isIOS) {
      // iOS 使用 Cupertino 风格
      return showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('删除文件'),
          content: Text('确定要删除 "$fileName" 吗？删除后文件将从File2Speech文件夹中移除。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    } else {
      // Android 使用 Material 风格
      return showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Text('删除文件'),
          content: Text('确定要删除 "$fileName" 吗？删除后文件将从File2Speech文件夹中移除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    }
  }
}
