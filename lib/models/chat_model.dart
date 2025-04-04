import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

import 'chat_message.dart';
import 'chat_conversation.dart';
import 'file_attachment.dart';
import 'model_category.dart';
import '../services/openrouter_service.dart';

class ChatModel with ChangeNotifier {
  List<ChatMessage> _messages = [];
  final List<ChatConversation> _conversations = [ChatConversation(id: 1, title: '新对话', messages: [])];
  int _currentConversationId = 1;
  bool _isLoading = false;
  bool _showApiKey = false;
  bool _enableWebSearch = false;
  String _apiKey = '';
  String _modelName = 'qwen/qwen2.5-vl-72b-instruct:free';
  final _storage = const FlutterSecureStorage();
  final List<FileAttachment> _pendingAttachments = [];
  bool _isFirstMessagePair = true;
  bool _waitingForFirstContent = false;

  // 用于缓存模型免费状态的Map
  final Map<String, bool> _modelFreeStatusCache = {};

  ChatModel() {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    _apiKey = await _storage.read(key: 'api_key') ?? '';
    _modelName = await _storage.read(key: '模型名称') ?? 'qwen/qwen2.5-vl-72b-instruct:free';
    
    // 如果名称不是qwen/qwen2.5-vl-72b-instruct:free，强制恢复为默认模型
    if (_modelName != 'qwen/qwen2.5-vl-72b-instruct:free') {
      _modelName = 'qwen/qwen2.5-vl-72b-instruct:free';
      // 将默认模型保存到存储中
      _storage.write(key: '模型名称', value: _modelName);
    }
    
    notifyListeners();
  }
  
  StreamSubscription<String>? _streamSub;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String get modelName => _modelName;
  List<FileAttachment> get pendingAttachments => _pendingAttachments;
  
  // 添加额外的getter
  List<ChatConversation> get conversations => _conversations;
  int get currentConversationId => _currentConversationId;
  String get apiKey => _apiKey;
  bool get showApiKey => _showApiKey;
  bool get enableWebSearch => _enableWebSearch;
  FlutterSecureStorage get storage => _storage;
  
  // 设置showApiKey
  set showApiKey(bool value) {
    _showApiKey = value;
    notifyListeners();
  }
  
  // 设置apiKey
  set apiKey(String value) {
    _apiKey = value;
    notifyListeners();
  }
  
  // 优化的检查模型是否免费的方法
  bool get isCurrentModelFree {
    // 检查缓存
    if (_modelFreeStatusCache.containsKey(_modelName)) {
      return _modelFreeStatusCache[_modelName]!;
    }
    
    // 计算结果并缓存
    bool result = false;
    
    // 优先使用简单的字符串匹配（向后兼容）
    if (_modelName.endsWith(':free')) {
      result = true;
    } else {
      // 在ModelInfo中查找更准确的信息
      for (final category in modelCategories) {
        for (final modelInfo in category.models) {
          if (modelInfo.id == _modelName) {
            result = modelInfo.isFree;
            break;
          }
        }
        if (result) break;
      }
    }
    
    // 保存到缓存
    _modelFreeStatusCache[_modelName] = result;
    return result;
  }
  
  // 设置modelName
  set modelName(String value) {
    final bool wasModelFree = isCurrentModelFree;
    _modelName = value;
    
    // 清除缓存
    _modelFreeStatusCache.remove(value);
    
    // 获取新模型的免费状态
    final bool isNewModelFree = isCurrentModelFree;
    
    // 只有在从非免费模型切换到免费模型时，才关闭网络搜索
    if (!wasModelFree && isNewModelFree && _enableWebSearch) {
      _enableWebSearch = false;
    }
    
    notifyListeners();
  }

  void sendMessage(String text, {List<FileAttachment>? attachments}) {
    _messages.add(ChatMessage(
      text: text, 
      isUser: true,
      attachments: attachments ?? (_pendingAttachments.isNotEmpty ? List.from(_pendingAttachments) : null),
    ));
    _pendingAttachments.clear();
    _isLoading = true;
    _waitingForFirstContent = true;
    notifyListeners();

    if (_apiKey.isEmpty) {
      _messages.add(ChatMessage(
        text: '错误: 请先设置API密钥',
        isUser: false,
      ));
      _isLoading = false;
      _waitingForFirstContent = false;
      notifyListeners();
      return;
    }

    final openRouter = OpenRouterService();
    _streamSub = openRouter
        .streamChat(
          apiKey: _apiKey,
          messages: _buildMessageHistory(),
          model: _modelName,
          enableWebSearch: _enableWebSearch,
        )
        .listen(
          (content) => _updateLastMessage(content),
          onError: (error) {
            // 保留错误信息打印，但简化格式
            debugPrint('错误: $error');
            _handleError(error);
          },
          onDone: () {
            // 简化完成消息
            debugPrint('聊天流完成');
            _completeLoading();
          },
        );
  }

  List<Map<String, String>> _buildMessageHistory() {
    final messages = <Map<String, String>>[];
    
    // 系统消息
    messages.add({'role': 'system', 'content': ''});
    
    // 获取用户消息历史
    final userMessages = _messages.where((m) => m.isUser).toList();
    
    for (int i = 0; i < userMessages.length; i++) {
      final message = userMessages[i];
      
      if (message.attachments != null && message.attachments!.isNotEmpty) {
        // 单张图片处理 - 需要使用JSON序列化为字符串
        try {
          // 将复杂的内容结构序列化为JSON字符串
          final contentObject = [
            {
              'type': 'text',
              'text': message.text.isEmpty ? '请分析这张图片' : message.text
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${message.attachments![0].type};base64,${message.attachments![0].base64Content}',
              }
            }
          ];
          messages.add({
            'role': 'user',
            'content': jsonEncode(contentObject),
          });
        } catch (e) {
          // 保留错误信息，但简化
          debugPrint('图片处理错误: $e');
          messages.add({
            'role': 'user',
            'content': message.text.isEmpty ? '请帮我分析一下' : message.text,
          });
        }
      } else {
        // 普通文本消息
        messages.add({'role': 'user', 'content': message.text});
      }
    }
    
    return messages;
  }

  void _updateLastMessage(String content) {
    if (_waitingForFirstContent) {
      _waitingForFirstContent = false;
      _messages.add(ChatMessage(text: content, isUser: false));
      notifyListeners();
      return;
    }
    
    if (_messages.isEmpty || _messages.last.isUser) return;
    
    final last = _messages.last;
    // 使用key值作为附件标识，避免附件被重新渲染
    final updatedMessage = last.copyWith(
      text: last.text + content,
      // 保持原有的附件引用不变
      preserveAttachments: true
    );
    _messages[_messages.length - 1] = updatedMessage;
    notifyListeners();
  }

  void _handleError(dynamic error) {
    _isLoading = false;
    _waitingForFirstContent = false;
    
    String errorMessage;
    if (error is DioException) {
      errorMessage = '网络请求失败: ${error.message}';
    } else {
      errorMessage = error.toString();
    }
    _messages.add(ChatMessage(
      text: '错误: $errorMessage',
      isUser: false,
    ));
    notifyListeners();
  }

  void _completeLoading() {
    _isLoading = false;
    
    // 检查是否需要生成对话标题
    // 优化标题生成逻辑，确保在有用户消息和AI回复时生成标题
    // 条件：是第一次消息对且消息列表中至少有一条用户消息和一条AI消息
    if (_isFirstMessagePair && 
        _messages.any((m) => m.isUser) && 
        _messages.any((m) => !m.isUser)) {
      _isFirstMessagePair = false;
      // 在后台生成标题，不阻塞UI
      _generateConversationTitleAsync();
    }
    
    notifyListeners();
  }

  // 异步生成对话标题，不阻塞主线程
  void _generateConversationTitleAsync() {
    // 使用Future.microtask将标题生成任务放入事件队列的末尾
    // 这样不会阻塞UI线程，用户可以继续进行操作
    Future.microtask(() => _generateConversationTitle());
  }

  // 生成对话标题
  Future<void> _generateConversationTitle() async {
    if (_messages.isEmpty) return;
    
    try {
      // 获取用户的第一条消息
      final userMessage = _messages.firstWhere((m) => m.isUser).text;
      final currentId = _currentConversationId; // 保存当前会话ID，以便稍后检查

      // 保持提示词不变，仍然要求模型生成最多10个字的标题
      // 但在实际应用中，我们不再强制截断标题
      final prompt = "请根据以下用户消息，生成一个简洁的对话标题，必须是完整的一句话，最多10个汉字：\"$userMessage\"";
      
      // 发送请求生成标题
      final openRouter = OpenRouterService();
      
      // 简化标题生成相关打印
      debugPrint('生成对话标题...');
      
      // 创建一个单独的Stream，改为使用通义千问模型
      final titleStream = openRouter.streamChat(
        apiKey: _apiKey,
        messages: [
          {'role': 'system', 'content': '你是一个对话标题生成助手。你的任务是生成简短的标题，要求：1.完整表达核心内容；2.字数控制在10个汉字以内；3.不要有标点符号；4.不要有"标题："、"主题："等前缀。'},
          {'role': 'user', 'content': prompt}
        ],
        model: 'qwen/qwen2.5-vl-72b-instruct:free', // 改为使用此模型生成标题
        enableWebSearch: false,
        isModelForTitle: true, // 标记这是标题生成模型
      );
      
      // 收集所有的返回内容
      String generatedTitle = '';
      await for (final chunk in titleStream) {
        generatedTitle += chunk;
      }
      
      // 简化标题生成结果打印
      debugPrint('标题生成完成: $generatedTitle');
      
      // 处理生成的标题
      generatedTitle = generatedTitle.trim()
          .replaceAll('"', '') // 移除引号
          .replaceAll('标题：', '') // 移除可能的前缀
          .replaceAll('主题：', '')
          .replaceAll('：', ''); // 移除冒号
      
      // 删除智能截断的代码，不再限制标题长度
      // 只有当标题为空时才使用默认值
      if (generatedTitle.isEmpty) {
        generatedTitle = '新对话';
      }
      
      // 更新对话标题
      // 使用异步更新UI，避免在后台线程直接修改UI状态
      Future.microtask(() {
        // 确保用户没有切换到其他会话
        if (_currentConversationId == currentId) {
          final conversation = _conversations.firstWhere(
            (c) => c.id == currentId, 
            orElse: () => ChatConversation(id: -1, title: '', messages: [])
          );
          
          // 如果找到了会话，则更新标题
          if (conversation.id != -1) {
            final index = _conversations.indexOf(conversation);
            _conversations[index] = ChatConversation(
              id: conversation.id,
              title: generatedTitle,
              messages: conversation.messages,
            );
            notifyListeners();
          }
        }
      });
    } catch (e) {
      // 保留错误信息
      debugPrint('标题生成错误: $e');
    }
  }

  void cancelStream() {
    _streamSub?.cancel();
    _isLoading = false;
    _waitingForFirstContent = false;
    notifyListeners();
  }

  void removeMessage(String text, DateTime timestamp) {
    _messages.removeWhere((m) => m.text == text && m.timestamp == timestamp);
    notifyListeners();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  void switchConversation(int id) {
    _currentConversationId = id;
    _messages = _conversations.firstWhere((c) => c.id == id).messages;
    _isFirstMessagePair = _messages.isEmpty;
    notifyListeners();
  }

  void removeConversation(int id) {
    if (_conversations.length <= 1) return;
    
    _conversations.removeWhere((c) => c.id == id);
    if (_currentConversationId == id) {
      _currentConversationId = _conversations.first.id;
      _messages = _conversations.first.messages;
    }
    notifyListeners();
  }

  void addNewConversation() {
    // 检查是否已存在"新对话"
    final hasNewConversation = _conversations.any((conv) => conv.title == '新对话');
    
    if (hasNewConversation) {
      // 如果已存在"新对话"，就先切换到它
      final newConv = _conversations.firstWhere((conv) => conv.title == '新对话');
      switchConversation(newConv.id);
    } else {
      // 如果不存在"新对话"，则创建一个新的
      final newId = _conversations.isEmpty ? 1 : _conversations.last.id + 1;
    _conversations.add(ChatConversation(
      id: newId,
        title: '新对话',
      messages: [],
    ));
      _currentConversationId = newId;
      _messages = [];
      _isFirstMessagePair = true;
      notifyListeners();
    }
  }

  void addPendingAttachment(FileAttachment attachment) {
    _pendingAttachments.add(attachment);
    notifyListeners();
  }

  void removePendingAttachment(int index) {
    if (index >= 0 && index < _pendingAttachments.length) {
      _pendingAttachments.removeAt(index);
      notifyListeners();
    }
  }

  void clearPendingAttachments() {
    _pendingAttachments.clear();
    notifyListeners();
  }

  void clearCurrentConversation() {
    // 清除消息
    _messages.clear();
    
    // 重置对话标题为"新对话"
    final conversation = _conversations.firstWhere((c) => c.id == _currentConversationId);
    final index = _conversations.indexOf(conversation);
    _conversations[index] = ChatConversation(
      id: conversation.id,
      title: '新对话',
      messages: [],
    );
    
    // 重置首次消息对标志
    _isFirstMessagePair = true;
    
    notifyListeners();
  }

  void toggleWebSearch() {
    _enableWebSearch = !_enableWebSearch;
    notifyListeners();
  }
} 