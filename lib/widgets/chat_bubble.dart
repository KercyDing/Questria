import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../models/file_attachment.dart';
import 'attachment_preview_dialog.dart';

// 将复制函数提取为全局函数，减少创建匿名函数的开销
void _copyToClipboard(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  // 显示自定义样式的提示
  showDialog(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    builder: (context) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
      return Dialog(
        insetPadding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '已复制到剪贴板',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      );
    },
  );
}

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<FileAttachment>? attachments;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.attachments,
  });

  @override
  Widget build(BuildContext context) {
    final bool isError = !isUser && text.startsWith('错误:');
    final String displayText = isError ? text.substring(4).trim() : text;
    final model = Provider.of<ChatModel>(context, listen: false);
    
    // 缓存常用值，减少计算
    final timestampFormatted = DateFormat('HH:mm').format(timestamp);
    final hasAttachments = attachments != null && attachments!.isNotEmpty;
    final bubbleColor = isUser 
        ? Colors.blue 
        : (isError ? Colors.red[50] : Colors.white);
    final textColor = isUser 
        ? Colors.white 
        : (isError ? Colors.red : Colors.black87);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 优化头像显示，减少条件判断
          if (!isUser) _buildAvatar(isUser: false),
          
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A9E9E9E),  // 优化: 使用Color代替颜色计算
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  child: Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (hasAttachments)
                        KeyedSubtree(
                          key: ValueKey('attachments-${timestamp.millisecondsSinceEpoch}'),
                          child: _buildAttachmentsPreview(context),
                        ),
                      if (displayText.isNotEmpty)
                        SelectableText(
                          displayText,
                          style: TextStyle(
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildActionRow(context, model, displayText, timestampFormatted),
              ],
            ),
          ),
          
          // 优化头像显示，减少条件判断
          if (isUser) _buildAvatar(isUser: true),
        ],
      ),
    );
  }
  
  // 提取头像构建函数
  Widget _buildAvatar({required bool isUser}) {
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 8 : 0,
        right: isUser ? 0 : 8,
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: isUser ? Colors.blue[200] : Colors.blue[100],
        child: Icon(
          isUser ? Icons.person : Icons.smart_toy, 
          color: isUser ? Colors.white : Colors.blue, 
          size: 20,
        ),
      ),
    );
  }
  
  // 提取操作栏构建函数
  Widget _buildActionRow(BuildContext context, ChatModel model, String displayText, String formattedTime) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isUser) ...[
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => _handleResend(model),
            tooltip: '重新提问',
          ),
          _buildCopyButton(context, displayText),
          _buildDeleteButton(model),
        ],
        
        Text(
          formattedTime,
          style: TextStyle(
            color: isUser ? Colors.blue[600] : Colors.grey[600],
            fontSize: 10,
          ),
        ),
        
        if (!isUser) ...[
          const SizedBox(width: 8),
          _buildCopyButton(context, displayText),
          _buildDeleteButton(model),
        ],
      ],
    );
  }
  
  // 提取复制按钮构建函数
  Widget _buildCopyButton(BuildContext context, String text) {
    return IconButton(
      icon: const Icon(Icons.content_copy, size: 16),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      onPressed: () => _copyToClipboard(context, text),
      tooltip: '复制',
    );
  }
  
  // 提取删除按钮构建函数
  Widget _buildDeleteButton(ChatModel model) {
    return IconButton(
      icon: const Icon(Icons.delete, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      onPressed: () => model.removeMessage(text, timestamp),
      tooltip: '删除',
    );
  }
  
  // 处理重新发送逻辑
  void _handleResend(ChatModel model) {
    // 找到当前消息的下一条消息（AI回复）
    final messages = model.messages;
    final currentIndex = messages.indexWhere((msg) => 
      msg.text == text && msg.timestamp == timestamp);
    
    // 如果找到当前消息，且它不是最后一条，且下一条是AI回复
    if (currentIndex != -1 && currentIndex < messages.length - 1 && !messages[currentIndex + 1].isUser) {
      // 保存当前消息的内容和附件以便重新发送
      final messageText = text;
      final userAttachments = attachments != null ? List<FileAttachment>.from(attachments!) : null;
      
      // 先删除AI回复
      model.removeMessage(messages[currentIndex + 1].text, messages[currentIndex + 1].timestamp);
      
      // 再删除用户原始提问
      model.removeMessage(text, timestamp);
      
      // 重新发送用户消息
      model.sendMessage(messageText, attachments: userAttachments);
    }
  }
  
  Widget _buildAttachmentsPreview(BuildContext context) {
    if (attachments == null || attachments!.isEmpty) return Container();
    
    // 如果只有一个附件，显示完整预览
    if (attachments!.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAttachmentPreview(context, attachments!.first),
          // 仅当同时有文字和附件时才添加间距
          if (text.isNotEmpty) const SizedBox(height: 8),
        ],
      );
    }
    
    // 多个附件，显示网格
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: attachments!.map((attachment) {
            return GestureDetector(
              onTap: () => _showAttachmentPreview(context, attachment),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Stack(
                  children: [
                    if (attachment.type.startsWith('image/') && attachment.base64Content != null)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.memory(
                            base64Decode(attachment.base64Content!),
                            fit: BoxFit.cover,
                            // 防止重新加载时闪烁
                            gaplessPlayback: true,
                            // 使用缓存
                            cacheWidth: 100,
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getFileIcon(attachment.type),
                              size: 36,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              attachment.name,
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        // 仅当同时有文字和附件时才添加间距
        if (text.isNotEmpty) const SizedBox(height: 8),
      ],
    );
  }
  
  Widget _buildAttachmentPreview(BuildContext context, FileAttachment attachment) {
    if (attachment.type.startsWith('image/') && attachment.base64Content != null) {
      // 使用缓存图片组件，防止在流式更新过程中频繁重建图片
      final imageBytes = base64Decode(attachment.base64Content!);
      
      return GestureDetector(
        onTap: () => _showAttachmentPreview(context, attachment),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
            maxHeight: 300,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            // 使用Image.memory并添加正确的缓存参数
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
              // 关键：使用gaplessPlayback防止重载时闪烁
              gaplessPlayback: true,
              // 缓存图片避免重复解码
              cacheWidth: (MediaQuery.of(context).size.width * 0.6).toInt(),
              // 设置frameBuilder以添加淡入效果，提升用户体验
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
              // 添加错误处理，在图像解码失败时显示错误提示
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  color: Colors.grey[200],
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.red[300], size: 32),
                      const SizedBox(height: 6),
                      const Text('图片加载失败', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else {
      // 非图片文件
      return GestureDetector(
        onTap: () => _showAttachmentPreview(context, attachment),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          margin: const EdgeInsets.only(bottom: 0),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(attachment.type),
                color: Colors.blue[700],
                size: 24,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatFileSize(attachment.size),
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  
  void _showAttachmentPreview(BuildContext context, FileAttachment attachment) {
    showDialog(
      context: context,
      builder: (context) => AttachmentPreviewDialog(attachment: attachment),
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