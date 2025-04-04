import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/file_attachment.dart';

// 优化后的附件预览项
class AnimatedAttachmentPreviewItem extends StatefulWidget {
  final FileAttachment attachment;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  
  const AnimatedAttachmentPreviewItem({
    super.key, 
    required this.attachment, 
    required this.onRemove,
    required this.onTap,
  });

  @override
  State<AnimatedAttachmentPreviewItem> createState() => _AnimatedAttachmentPreviewItemState();
}

class _AnimatedAttachmentPreviewItemState extends State<AnimatedAttachmentPreviewItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 100,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(51),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (widget.attachment.type.startsWith('image/') && widget.attachment.base64Content != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(
                      base64Decode(widget.attachment.base64Content!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getFileIcon(widget.attachment.type),
                        color: Colors.blue[700],
                        size: 36,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.attachment.name,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              // 底部信息覆盖
              if (widget.attachment.type.startsWith('image/'))
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withAlpha(179),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(11),
                        bottomRight: Radius.circular(11),
                      ),
                    ),
                    child: Text(
                      _formatFileSize(widget.attachment.size),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              // 删除按钮
              Positioned(
                top: 0,
                right: 0,
                child: InkWell(
                  onTap: () {
                    // 添加动画效果
                    _controller.reverse().then((_) => widget.onRemove());
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red[400],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(51),
                          spreadRadius: 1,
                          blurRadius: 1,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatFileSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return Icons.image;
    } else if (mimeType.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (mimeType.contains('word') || mimeType.contains('doc')) {
      return Icons.description;
    } else if (mimeType.contains('excel') || mimeType.contains('sheet')) {
      return Icons.table_chart;
    } else if (mimeType.contains('text')) {
      return Icons.text_snippet;
    }
    return Icons.insert_drive_file;
  }
} 