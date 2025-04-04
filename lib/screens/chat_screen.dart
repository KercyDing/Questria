import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:window_manager/window_manager.dart';

import '../models/chat_model.dart';
import '../models/file_attachment.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/animated_attachment_preview_item.dart';
import '../widgets/attachment_preview_dialog.dart';
import '../widgets/model_selection_dialog.dart';
import '../main.dart'; // 导入WindowStateManager

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _aiJustResponded = false; // 跟踪AI是否刚刚回复
  bool _isShiftPressed = false; // 跟踪Shift键是否按下

  @override
  void initState() {
    super.initState();
    
    // 监听焦点变化
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
    
    // 延迟自动获取焦点
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }
  
  // 处理键盘事件以跟踪Shift键状态和处理Enter键
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // 处理Shift键按下和释放
    if (event.logicalKey == LogicalKeyboardKey.shift) {
      if (event is KeyDownEvent) {
        _isShiftPressed = true;
      } else if (event is KeyUpEvent) {
        _isShiftPressed = false;
      }
      return KeyEventResult.ignored;
    }
    
    // 处理Enter键
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      // 检查Shift键是否被按住
      if (HardwareKeyboard.instance.isShiftPressed || _isShiftPressed) {
        // Shift+Enter组合，允许换行
        return KeyEventResult.ignored;
      } else {
        // 单按Enter键，发送消息
        final model = Provider.of<ChatModel>(context, listen: false);
        if (!model.isLoading) {
          _sendMessage(model, textController);
          // 处理完成，阻止事件继续传递（防止换行符被插入）
          return KeyEventResult.handled;
        }
      }
    }
    
    return KeyEventResult.ignored;
  }
  
  @override
  void dispose() {
    _focusNode.dispose();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ChatModel>();
    
    // 检测AI是否刚刚回复完成
    if (!model.isLoading && model.messages.isNotEmpty && !model.messages.last.isUser) {
      // 只有当AI刚刚回复完成且尚未处理时
      if (!_aiJustResponded) {
        _aiJustResponded = true;
        // 延迟聚焦以避免与用户其他操作冲突
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _focusNode.requestFocus();
          }
        });
      }
    } else if (model.isLoading) {
      // 重置标志，以便下次AI回复完成时再次触发
      _aiJustResponded = false;
    }

    return GestureDetector(
      // 点击空白区域取消焦点
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          leadingWidth: 40,
          automaticallyImplyLeading: false,
          toolbarHeight: 48, // 设置较小的工具栏高度
          title: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) => windowManager.startDragging(),
            onDoubleTap: () {
              // 使用WindowStateManager获取当前状态
              final windowState = Provider.of<WindowStateManager>(context, listen: false);
              if (windowState.isMaximized) {
                windowManager.restore();
              } else {
                windowManager.maximize();
              }
            },
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  // 菜单按钮
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black87),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      tooltip: '打开菜单',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
                  
                  // 标题 - 添加拖拽功能
                  Expanded(
                    flex: 1,
                    child: Text(
                      model.conversations.firstWhere((c) => c.id == model.currentConversationId).title,
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                  ),
                  
                  // 模型选择按钮
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.psychology, size: 18),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              model.modelName.split('/').last.split(':').first,
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (model.isCurrentModelFree)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(51),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '免费',
                                  style: TextStyle(fontSize: 10, color: Colors.green),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () => _showModelSelectionDialog(context, model),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  ),
                  
                  // API按钮
                  Expanded(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 清除当前对话按钮
                        IconButton(
                          icon: const Icon(Icons.delete_sweep, color: Colors.black87, size: 18),
                          onPressed: () {
                            // 确认对话框
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                titlePadding: EdgeInsets.zero,
                                title: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onPanStart: (_) => windowManager.startDragging(),
                                  onDoubleTap: () {
                                    // 使用WindowStateManager获取当前状态
                                    final windowState = Provider.of<WindowStateManager>(context, listen: false);
                                    if (windowState.isMaximized) {
                                      windowManager.restore();
                                    } else {
                                      windowManager.maximize();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                                    child: const Text('清除当前对话'),
                                  ),
                                ),
                                content: const Text('确定要清除当前对话的所有消息吗？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      model.clearCurrentConversation();
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('确定'),
                                  ),
                                ],
                              ),
                            );
                          },
                          tooltip: '清除当前对话',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        
                        IconButton(
                          icon: const Icon(Icons.key, color: Colors.black87, size: 18),
                          onPressed: () {
                            _showApiKeyDialog(context, model);
                          },
                          tooltip: 'API设置',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        
                        // 窗口控制按钮 - 使用原生的方式但提高响应性
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => windowManager.minimize(),
                            child: const SizedBox(
                              width: 36,
                              height: 36,
                              child: Tooltip(
                                message: '最小化',
                                child: Center(
                                  child: Icon(Icons.remove, size: 18),
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        Consumer<WindowStateManager>(
                          builder: (context, windowState, _) {
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  // 直接根据当前状态调用相应函数
                                  if (windowState.isMaximized) {
                                    windowManager.restore();
                                  } else {
                                    windowManager.maximize();
                                  }
                                },
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Tooltip(
                                    message: windowState.isMaximized ? '还原' : '最大化',
                                    child: Center(
                                      child: Icon(
                                        windowState.isMaximized ? Icons.filter_none : Icons.crop_square,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => windowManager.close(),
                            child: const SizedBox(
                              width: 36,
                              height: 36,
                              child: Tooltip(
                                message: '关闭',
                                child: Center(
                                  child: Icon(Icons.close, size: 18),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        drawer: Drawer(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          backgroundColor: Colors.white,
          child: Column(
            children: [
              // 自定义标题栏
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(51),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Text(
                      '历史对话',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // 使用Builder创建正确的上下文
                    Builder(
                      builder: (BuildContext context) {
                        return IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            model.addNewConversation();
                            Scaffold.of(context).closeDrawer();
                          },
                          tooltip: '新建对话',
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: model.conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = model.conversations[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: conversation.id == model.currentConversationId 
                            ? Colors.blue.withAlpha(26)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: conversation.id == model.currentConversationId
                                ? Colors.blue
                                : Colors.black87,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => model.removeConversation(conversation.id),
                          tooltip: '删除对话',
                          color: Colors.grey[600],
                        ),
                        onTap: () {
                          model.switchConversation(conversation.id);
                          Scaffold.of(context).closeDrawer();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFFAF9F5),
        body: Column(
          children: [
            Expanded(
              child: model.messages.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withAlpha(20),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            radius: 28,
                            child: Icon(
                              Icons.waving_hand,
                              size: 30,
                              color: Colors.blue[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Hi！这里是Questria,有求必应~",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: model.messages.length,
                    key: const PageStorageKey('chat_messages'),
                    // 使用cacheExtent提高滚动性能
                    cacheExtent: 1000,
                    // 添加自定义滚动物理效果以提升滚动体验
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    // 使用addAutomaticKeepAlives保持消息状态
                    addAutomaticKeepAlives: true,
                    // 使用addRepaintBoundaries优化重绘
                    addRepaintBoundaries: true,
                    // 使用clipBehavior提高绘制性能
                    clipBehavior: Clip.hardEdge,
                    itemBuilder: (context, index) {
                      final message = model.messages[model.messages.length - 1 - index];
                      return RepaintBoundary(
                        // 添加明确的Key以避免不必要的重建
                        child: ChatBubble(
                          key: ValueKey('${message.timestamp.millisecondsSinceEpoch}_${message.isUser}'),
                          text: message.text,
                          isUser: message.isUser,
                          timestamp: message.timestamp,
                          attachments: message.attachments,
                        ),
                      );
                    },
                  ),
            ),
              if (model.pendingAttachments.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 150, // 将宽度从200减小到150
                    margin: const EdgeInsets.only(left: 8, right: 20, bottom: 4, top: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(77),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 附件预览区域的标题
                        Padding(
                          padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                '附件',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${model.pendingAttachments.length}/1',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: model.pendingAttachments.length,
                            itemBuilder: (context, index) {
                              final attachment = model.pendingAttachments[index];
                              return AnimatedAttachmentPreviewItem(
                                attachment: attachment,
                                onRemove: () => model.removePendingAttachment(index),
                                onTap: () => _previewAttachment(context, attachment),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      maxHeight: 120, // 最大5行左右高度
                      minHeight: 60,  // 默认2行高度
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isFocused ? Colors.blue[400]! : Colors.grey[300]!,
                        width: _isFocused ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isFocused 
                            ? Colors.blue.withAlpha(50) 
                            : Colors.grey.withAlpha(50),
                          spreadRadius: 2,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: RepaintBoundary( // 添加重绘边界，提高性能
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Focus(
                              onKeyEvent: _handleKeyEvent,
                              child: TextField(
                                controller: textController,
                                focusNode: _focusNode,
                                decoration: const InputDecoration(
                                  hintText: '输入消息... (Shift+Enter换行)',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  // 去掉输入框的单独边框，由外层Container控制
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                maxLines: null,
                                minLines: 1,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                onSubmitted: (value) {
                                  // 此处主要用于移动设备
                                  _sendMessage(model, textController);
                                },
                              ),
                            ),
                          ),
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(24),
                                bottomRight: Radius.circular(24),
                              ),
                            ),
                            // 使用RepaintBoundary包裹按钮区域，避免输入时重绘
                            child: RepaintBoundary(
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.image, size: 20),
                                    onPressed: () => _pickFile(context, model),
                                    tooltip: '添加图片',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.language, size: 20),
                                    onPressed: model.apiKey.isNotEmpty && !model.isCurrentModelFree 
                                      ? () => model.toggleWebSearch()
                                      : null,
                                    tooltip: model.isCurrentModelFree 
                                      ? '免费模型不支持网络搜索'
                                      : '网络搜索',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    color: (model.apiKey.isNotEmpty && !model.isCurrentModelFree)
                                      ? (model.enableWebSearch ? Colors.blue : Colors.grey)
                                      : Colors.grey.withAlpha(128),
                                  ),
                                  const Spacer(),
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (model.isLoading)
                                        SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                            backgroundColor: Colors.transparent,
                                          ),
                                        ),
                                      IconButton(
                                        icon: model.isLoading ? const Icon(Icons.stop, size: 20) : const Icon(Icons.send, size: 20),
                                        onPressed: () => model.isLoading ? model.cancelStream() : _sendMessage(model, textController),
                                        tooltip: model.isLoading ? '暂停' : '发送(Enter)',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(ChatModel model, TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isNotEmpty || model.pendingAttachments.isNotEmpty) {
      model.sendMessage(text);
      controller.clear();
      // 重置AI回复标志，确保下一次回复会正确触发自动聚焦
      if (context.mounted) {
        (context as Element).findAncestorStateOfType<_ChatScreenState>()?._aiJustResponded = false;
      }
    }
  }
  
  Future<void> _pickFile(BuildContext context, ChatModel model) async {
    try {
      // 保存上下文引用以便在异步操作后使用
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      
      // 限制为单张图片选择，移除GIF格式
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: false, // 只允许选择一张图片
      );
      
      if (result != null && result.files.isNotEmpty) {
        // 如果已经有附件，先清除
        if (model.pendingAttachments.isNotEmpty) {
          model.clearPendingAttachments();
        }
        
        final file = result.files.first;
        final filePath = file.path;
        
        if (filePath == null) {
          if (context.mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('无法获取文件路径')),
            );
          }
          return;
        }
        
        final fileObj = File(filePath);
        final fileName = file.name;
        final fileSize = await fileObj.length();
        final fileExtension = path.extension(fileName).toLowerCase();
        
        String mimeType;
        switch (fileExtension) {
          case '.jpg':
          case '.jpeg':
            mimeType = 'image/jpeg';
            break;
          case '.png':
            mimeType = 'image/png';
            break;
          default:
            // 跳过非图片文件
            if (context.mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('只支持JPG和PNG格式的图片')),
              );
            }
            return;
        }
        
        // 转换为base64
        final bytes = await fileObj.readAsBytes();
        final base64Content = base64Encode(bytes);
        
        final attachment = FileAttachment(
          path: filePath,
          name: fileName,
          type: mimeType,
          size: fileSize,
          base64Content: base64Content,
        );
        
        model.addPendingAttachment(attachment);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件时出错: $e')),
        );
      }
    }
  }
  
  void _previewAttachment(BuildContext context, FileAttachment attachment) {
    showDialog(
      context: context,
      builder: (context) => AttachmentPreviewDialog(attachment: attachment),
    );
  }
  
  void _showApiKeyDialog(BuildContext context, ChatModel model) {
    // 预先创建控制器，提高响应速度
    final apiKeyController = TextEditingController(text: model.apiKey);
    bool isValidApiKey = model.apiKey.isEmpty || RegExp(r'^sk-or-v1-[a-zA-Z0-9]{64}$').hasMatch(model.apiKey);
    
    // 使用简化的方式显示对话框
    showDialog(
      context: context,
      barrierDismissible: true, // 允许点击外部关闭对话框
      useRootNavigator: false, // 使用当前Navigator而不是根Navigator
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              titlePadding: EdgeInsets.zero,
              title: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: () {
                  final windowState = Provider.of<WindowStateManager>(context, listen: false);
                  if (windowState.isMaximized) {
                    windowManager.restore();
                  } else {
                    windowManager.maximize();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: const Text('API设置'),
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              // 其他对话框内容保持不变
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OpenRouter API密钥', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: apiKeyController,
                      decoration: InputDecoration(
                        hintText: '输入OpenRouter API密钥',
                        border: const OutlineInputBorder(),
                        errorText: !isValidApiKey ? 'API密钥格式错误！' : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            model.showApiKey ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              model.showApiKey = !model.showApiKey;
                            });
                          },
                        ),
                      ),
                      obscureText: !model.showApiKey,
                      onChanged: (value) {
                        setState(() {
                          isValidApiKey = value.isEmpty || RegExp(r'^sk-or-v1-[a-zA-Z0-9]{64}$').hasMatch(value);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: 'https://openrouter.ai/settings/keys'));
                        // 显示简化的复制提示
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制到剪贴板，请在浏览器中打开'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.content_copy, size: 14, color: Colors.blue[700]),
                            const SizedBox(width: 4),
                            Text(
                              '获取API Key',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: isValidApiKey 
                    ? () => _saveApiKey(context, apiKeyController, model)
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade500,
                  ),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _saveApiKey(BuildContext context, TextEditingController apiKeyController, ChatModel model) {
    final apiKey = apiKeyController.text.trim();
    // 再次验证API Key格式
    if (apiKey.isNotEmpty && !RegExp(r'^sk-or-v1-[a-zA-Z0-9]{64}$').hasMatch(apiKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API密钥格式不正确，无法保存')),
      );
      return;
    }
    
    model.apiKey = apiKey;
    
    // 使用Future进行异步存储，但不阻塞UI
    model.storage.write(key: 'api_key', value: model.apiKey);
    model.storage.write(key: '模型名称', value: model.modelName);
    
    // 立即关闭对话框，不等待存储完成
    Navigator.of(context).pop();
  }
  
  void _showModelSelectionDialog(BuildContext context, ChatModel model) {
    // 直接显示对话框，无需等待
    showDialog<String>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: false,
      builder: (context) => ModelSelectionDialog(
        currentModel: model.modelName,
        onModelSelected: (selectedModel) {
          model.modelName = selectedModel;
        },
      ),
    ).then((result) {
      if (result != null) {
        model.modelName = result;
        // 立即保存模型选择，但不阻塞UI
        model.storage.write(key: '模型名称', value: model.modelName);
      }
    });
  }
} 