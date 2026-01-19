import 'package:flutter/material.dart';

class FileUploadCard extends StatelessWidget {
  final VoidCallback onPickFile;
  final String? fileName;
  final bool isLoading;

  const FileUploadCard({
    super.key,
    required this.onPickFile,
    this.fileName,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: isLoading ? null : onPickFile,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                )
              else
                Icon(
                  Icons.upload_file,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              const SizedBox(height: 8),
              Text(
                isLoading
                    ? '正在处理文件...'
                    : fileName != null
                        ? '已选择: $fileName'
                        : '点击选择文件',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isLoading && fileName == null) ...[
                const SizedBox(height: 4),
                Text(
                  '支持格式: PDF, TXT',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
