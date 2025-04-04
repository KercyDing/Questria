import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class OpenRouterService {
  // 使用单例模式优化服务实例
  static final OpenRouterService _instance = OpenRouterService._internal();
  factory OpenRouterService() => _instance;
  
  // 私有构造函数
  OpenRouterService._internal() {
    _initDio();
  }
  
  // Dio实例
  late final Dio _dio;
  
  // 初始化Dio并添加拦截器
  void _initDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'HTTP-Referer': 'https://openrouterwerewolf.com',
        'X-Title': 'OpenRouter Werewolf',
        'Content-Type': 'application/json',
      },
    ));
    
    // 添加请求重试拦截器
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: debugPrint,
        retries: 2,
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 3),
        ],
      ),
    );
  }

  Stream<String> streamChat({
    required String apiKey,
    required List<Map<String, String>> messages,
    required String model,
    bool enableWebSearch = false,
    bool isModelForTitle = false,
  }) async* {
    // 检查模型是否有效
    if (model.isEmpty) {
      throw Exception('模型名称不能为空');
    }
    
    // 如果启用了网络搜索，修改模型ID
    final effectiveModel = enableWebSearch && !model.endsWith(':web') 
        ? '$model:web' 
        : model;
    
    // 创建请求体
    final Map<String, dynamic> requestBody = {
      'model': effectiveModel,
      'messages': messages,
      'stream': true,
    };
    
    // 添加特定于标题模型的参数
    if (isModelForTitle) {
      requestBody['max_tokens'] = 120;
      requestBody['temperature'] = 0.7;
    }
    
    // 添加API密钥到请求头
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'HTTP-Referer': 'https://github.com/Questria',
      'X-Title': 'Questria',
    };
    
    try {
      // 发送请求
      final response = await _dio.post(
        'https://openrouter.ai/api/v1/chat/completions',
        data: requestBody,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
      );
      
      // 处理响应流
      yield* _processResponseStream(response, model, isModelForTitle);
      
    } catch (e) {
      if (e is DioException) {
        // 处理网络错误
        if (e.response?.statusCode == 403) {
          throw Exception('OpenRouter API访问被拒绝，可能是API密钥无效或权限不足');
        } else {
          throw Exception('OpenRouter API请求失败');
        }
      } else {
        // 处理其他错误
        throw Exception('发送消息时出错');
      }
    }
  }
  
  // 处理响应流
  Stream<String> _processResponseStream(
    Response response, 
    String model,
    bool isModelForTitle,
  ) async* {
    final responseBody = response.data as ResponseBody;
    
    String buffer = '';
    final byteBuffer = <int>[];
    int emptyResponseCount = 0;
    const int maxEmptyResponses = 5;
    
    await for (final chunk in responseBody.stream) {
      try {
        // 检测空响应
        if (chunk.isEmpty) {
          emptyResponseCount++;
          if (emptyResponseCount >= maxEmptyResponses) {
            break;
          }
          continue;
        }
        
        // 重置计数器
        emptyResponseCount = 0;
        
        byteBuffer.addAll(chunk);
        final decoded = utf8.decode(byteBuffer);
        buffer += decoded;
        byteBuffer.clear();
        
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') continue;

            try {
              final json = jsonDecode(data);
              
              // 检查错误
              if (json['error'] != null) {
                yield* _handleErrorResponse(json);
                return;
              }
              
              // 处理正常响应
              if (json['choices'] != null) {
                final content = _extractContent(json);
                if (content != null) {
                  yield content;
                }
              }
            } catch (e) {
              // 检查是否是我们自己抛出的异常
              if (e is Exception && e.toString().contains('模型错误')) {
                rethrow;
              }
              // 忽略其他JSON解析错误
            }
          }
        }
      } on FormatException {
        // 处理不完整的UTF-8序列
        continue;
      }
    }
  }
  
  // 处理错误响应
  Stream<String> _handleErrorResponse(Map<String, dynamic> json) async* {
    final errorInfo = json['error'];
    String errorMessage = '模型错误';
    
    // 处理区域限制错误
    if (errorInfo['metadata'] != null && 
        errorInfo['metadata']['raw'] != null &&
        errorInfo['metadata']['raw'].toString().contains('unsupported_country_region')) {
      errorMessage = '此模型在您的地区不可用，请选择其他模型。';
    } else if (errorInfo['message'] != null) {
      errorMessage = '模型错误: ${errorInfo['message']}';
    }
    
    throw Exception(errorMessage);
  }
  
  // 优化的内容提取逻辑，使用更高效的结构
  String? _extractContent(Map<String, dynamic> json) {
    // 使用嵌套的try-catch块，避免深层次的null检查提高性能
    try {
      // 标准OpenAI格式（最常见）
      return json['choices'][0]['delta']['content'];
    } catch (_) {}
    
    try {
      // 检查choices[0].text格式
      return json['choices'][0]['text'];
    } catch (_) {}
    
    try {
      // 检查choices[0].message.content格式
      return json['choices'][0]['message']['content'];
    } catch (_) {}
    
    try {
      // 检查tokens.text格式
      return json['tokens']['text'];
    } catch (_) {}
    
    try {
      // 检查content_blocks[0].text
      return json['content_blocks'][0]['text'];
    } catch (_) {}
    
    // 如果找不到已知格式，返回null但不打印调试信息
    return null;
  }
}

// 自定义重试拦截器
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final Function(String message) logPrint;
  final int retries;
  final List<Duration> retryDelays;
  
  RetryInterceptor({
    required this.dio,
    required this.logPrint,
    this.retries = 3,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 3),
    ],
  });
  
  @override
  Future onError(DioException err, ErrorInterceptorHandler handler) async {
    // 从错误中获取请求信息
    final options = err.requestOptions;
    
    // 从选项中获取当前重试次数，如果没有则初始化为0
    options.extra['retryCount'] ??= 0;
    int currentRetry = options.extra['retryCount'];
    
    // 如果是流式响应或已超出最大重试次数，不进行重试
    if (options.responseType == ResponseType.stream || currentRetry >= retries) {
      return handler.next(err);
    }
    
    // 仅重试网络错误和超时错误
    if ([
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.badResponse,
      DioExceptionType.connectionError,
    ].contains(err.type)) {
      // 增加重试计数
      options.extra['retryCount'] = currentRetry + 1;
      
      // 延迟后重试
      final delay = currentRetry < retryDelays.length
          ? retryDelays[currentRetry]
          : retryDelays.last;
          
      await Future.delayed(delay);
      
      // 克隆原始请求
      final response = await dio.fetch(options);
      return handler.resolve(response);
    }
    
    return handler.next(err);
  }
} 