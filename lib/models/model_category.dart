// 添加模型分类和列表
class ModelCategory {
  final String name;
  final List<ModelInfo> models;
  
  const ModelCategory({required this.name, required this.models});
}

// 模型信息类，包含模型ID和可用性信息
class ModelInfo {
  final String id;
  final bool mayBeRegionRestricted;
  final bool isFree;
  final String? note;
  
  ModelInfo(
    this.id, {
    this.mayBeRegionRestricted = false, 
    this.note,
    // 通过检查ID是否以":free"结尾确定是否为免费模型
    bool? isFree,
  }) : isFree = isFree ?? id.endsWith(':free');
  
  // 不再在显示名称中添加警告文本，我们将在UI中使用图标
  String get displayName => id;
}

// 所有支持的模型列表
final List<ModelCategory> modelCategories = [
  ModelCategory(
    name: 'DeepSeek',
    models: [
      ModelInfo('deepseek/deepseek-chat-v3-0324:free'),
      ModelInfo('deepseek/deepseek-chat-v3-0324'),
      ModelInfo('deepseek/deepseek-chat:free'),
      ModelInfo('deepseek/deepseek-chat'),
      ModelInfo('deepseek/deepseek-r1:free'),
      ModelInfo('deepseek/deepseek-r1'),
    ],
  ),
  ModelCategory(
    name: 'Claude',
    models: [
      ModelInfo('anthropic/claude-3.5-sonnet'),
      ModelInfo('anthropic/claude-3.5-haiku'),
      ModelInfo('anthropic/claude-3.7-sonnet'),
      ModelInfo('anthropic/claude-3.7-sonnet:thinking'),
    ],
  ),
  ModelCategory(
    name: 'Qwen',
    models: [
      ModelInfo('qwen/qwen-2.5-72b-instruct'),
      ModelInfo('qwen/qwen2.5-32b-instruct'),
      ModelInfo('qwen/qwen2.5-vl-72b-instruct:free'),
      ModelInfo('qwen/qwen2.5-vl-72b-instruct'),
      ModelInfo('qwen/qwen2.5-vl-32b-instruct:free'),
      ModelInfo('qwen/qwen-2.5-coder-32b-instruct:free'),
      ModelInfo('qwen/qwen-2.5-coder-32b-instruct'),
    ],
  ),
  ModelCategory(
    name: 'Google',
    models: [
      ModelInfo('google/gemini-2.0-flash-001'),
      ModelInfo('google/gemini-2.0-flash-lite-001'),
      ModelInfo('google/gemini-2.5-pro-exp-03-25:free'),
      ModelInfo('google/gemini-2.0-flash-exp:free'),
      ModelInfo('google/gemini-2.0-flash-thinking-exp-1219:free'),
      ModelInfo('google/gemini-2.0-flash-thinking-exp:free'),
      ModelInfo('google/gemini-2.0-pro-exp-02-05:free'),
    ],
  ),
  ModelCategory(
    name: 'OpenAI',
    models: [
      ModelInfo('openai/gpt-4o-mini'), // 可用
      ModelInfo('openai/gpt-4o'), // 可用
      // 以下模型可能受地区限制
      ModelInfo('openai/gpt-4-turbo', mayBeRegionRestricted: true),
      ModelInfo('openai/o1-preview', mayBeRegionRestricted: true),
      ModelInfo('openai/o1-preview-2024-09-12', mayBeRegionRestricted: true),
      ModelInfo('openai/o1', mayBeRegionRestricted: true),
      ModelInfo('openai/o3-mini', mayBeRegionRestricted: true),
      ModelInfo('openai/o3-mini-high', mayBeRegionRestricted: true),
      ModelInfo('openai/gpt-4.5-preview', mayBeRegionRestricted: true),
      ModelInfo('openai/o1-pro', mayBeRegionRestricted: true),
    ],
  ),
]; 