import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextDisplayCard extends StatefulWidget {
  final String text;
  final bool isLoading;
  final ValueChanged<String> onTextChanged;
  final VoidCallback? onEditingComplete;

  const TextDisplayCard({
    super.key,
    required this.text,
    this.isLoading = false,
    required this.onTextChanged,
    this.onEditingComplete,
  });

  @override
  State<TextDisplayCard> createState() => _TextDisplayCardState();
}

class _TextDisplayCardState extends State<TextDisplayCard> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(TextDisplayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果外部文本改变且不是由于用户编辑，更新控制器
    if (widget.text != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 加载状态
            if (widget.isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else ...[
              // 文字编辑区域（可滚动）
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: (value) {
                      widget.onTextChanged(value);
                    },
                    textInputAction: TextInputAction.done, // 键盘显示"完成"按钮
                    onSubmitted: (_) {
                      // 点击键盘完成按钮时调用
                      _focusNode.unfocus(); // 收起键盘
                      if (widget.onEditingComplete != null) {
                        widget.onEditingComplete!();
                      }
                    },
                    maxLines: null,
                    expands: true, // 允许TextField占满可用空间
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                      hintText: widget.text.isEmpty
                          ? '点击此处编辑文字内容...'
                          : null,
                    ),
                  ),
                ),
              ),
              // 字数显示在文本框下方（Card底部）
              if (_controller.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, right: 4.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_controller.text.length} 字',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
