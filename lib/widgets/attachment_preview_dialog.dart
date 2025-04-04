import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../models/file_attachment.dart';

// 附件预览对话框
class AttachmentPreviewDialog extends StatefulWidget {
  final FileAttachment attachment;
  
  const AttachmentPreviewDialog({super.key, required this.attachment});
  
  @override
  State<AttachmentPreviewDialog> createState() => _AttachmentPreviewDialogState();
}

class _AttachmentPreviewDialogState extends State<AttachmentPreviewDialog> {
  final TransformationController _transformationController = TransformationController();
  late bool _isImage;
  
  @override
  void initState() {
    super.initState();
    _isImage = widget.attachment.type.startsWith('image/') && widget.attachment.base64Content != null;
  }
  
  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // 计算对话框的最大尺寸，以确保图片不会太大
    final Size screenSize = MediaQuery.of(context).size;
    final double maxWidth = screenSize.width * 0.85;
    final double maxHeight = screenSize.height * 0.7;
    
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 自定义标题栏
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(26),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.attachment.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: _isImage
                ? _buildImagePreview(context)
                : ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildFilePreview(),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImagePreview(BuildContext context) {
    final imageBytes = base64Decode(widget.attachment.base64Content!);
    
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          maxScale: 5.0,
          minScale: 0.1,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          clipBehavior: Clip.none,
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain,
            width: null,
            height: null,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _getFileIcon(widget.attachment.type),
          size: 80,
          color: Colors.blue[700],
        ),
        const SizedBox(height: 16),
        Text(
          widget.attachment.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '类型: ${widget.attachment.type}\n大小: ${_formatFileSize(widget.attachment.size)}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Text(
          '此文件类型无法在应用内预览',
          style: TextStyle(color: Colors.grey),
        ),
      ],
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