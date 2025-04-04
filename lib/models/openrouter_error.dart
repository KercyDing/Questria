class OpenRouterError {
  final int code;
  final String message;
  final Map<String, dynamic>? metadata;

  OpenRouterError({required this.code, required this.message, this.metadata});

  factory OpenRouterError.fromJson(Map<String, dynamic> json) {
    final error = json['error'];
    return OpenRouterError(
      code: error['code'],
      message: error['message'],
      metadata: error['metadata'],
    );
  }

  String get briefMessage {
    switch (code) {
      case 400: return '无效请求';
      case 401: return '无效凭证';
      case 402: return '账户余额不足';
      case 403: return '内容需要审核';
      case 408: return '请求超时';
      case 429: return '请求过于频繁';
      case 502: return '模型服务异常';
      case 503: return '无可用模型';
      default: return '发生错误';
    }
  }

  bool get isOnlineModel => message.contains(':online');
} 