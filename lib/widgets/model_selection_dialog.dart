import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/model_category.dart';
import 'package:window_manager/window_manager.dart';

// 模型选择对话框
class ModelSelectionDialog extends StatefulWidget {
  final String currentModel;
  final Function(String) onModelSelected;

  const ModelSelectionDialog({
    super.key,
    required this.currentModel,
    required this.onModelSelected,
  });

  @override
  State<ModelSelectionDialog> createState() => _ModelSelectionDialogState();
}

class _ModelSelectionDialogState extends State<ModelSelectionDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customModelController = TextEditingController();
  String _searchQuery = '';
  // 当前选中的模型，初始化为widget传入的值
  late String _selectedModel;
  
  // 创建一个所有模型的列表
  final List<ModelInfo> _allModels = [];

  @override
  void initState() {
    super.initState();
    
    // 初始化选中的模型
    _selectedModel = widget.currentModel;
    
    // 初始化全部模型列表
    for (var category in modelCategories) {
      _allModels.addAll(category.models);
    }
    
    _tabController = TabController(length: modelCategories.length + 2, vsync: this); // +2 for "All" and "Custom"
    
    // 检查当前模型是否为自定义模型
    bool foundInCategories = false;
    for (var category in modelCategories) {
      for (var modelInfo in category.models) {
        if (modelInfo.id == widget.currentModel) {
          foundInCategories = true;
          break;
        }
      }
      if (foundInCategories) break;
    }
    
    if (!foundInCategories) {
      _customModelController.text = widget.currentModel;
      _tabController.animateTo(modelCategories.length + 1); // 切换到自定义选项卡
    }
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 500,
        height: 500,
        child: DefaultTabController(
          length: modelCategories.length + 2, // +2 for "All" and "Custom"
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight + 48), // 常规高度+标签高度
                child: GestureDetector(
                  onPanStart: (details) {
                    windowManager.startDragging();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(26),
                          spreadRadius: 1,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 标题栏部分
                        Container(
                          height: kToolbarHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Text(
                                '选择模型',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(_selectedModel),
                                style: IconButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 标签栏部分
                        TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                          padding: EdgeInsets.zero,
                          tabs: [
                            const Tab(text: '全部'), // 新增"全部"标签
                            ...modelCategories.map((category) => Tab(text: category.name)),
                            const Tab(text: '自定义'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              body: Column(
                children: [
                  // 条件性显示搜索框，只在非自定义标签页中显示
                  ValueListenableBuilder<double>(
                    valueListenable: _tabController.animation!,
                    builder: (context, value, child) {
                      // 当前标签索引（四舍五入以获取整数索引）
                      final currentIndex = value.round();
                      // 自定义标签的索引
                      final customTabIndex = modelCategories.length + 1;
                      
                      // 如果是自定义标签页，则不显示搜索框
                      if (currentIndex == customTabIndex) {
                        return const SizedBox.shrink();
                      }
                      
                      // 其他标签页显示搜索框
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: '搜索模型...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAllModelsList(), // 新增"全部"标签页视图
                        ...modelCategories.map((category) => _buildModelList(category)),
                        _buildCustomModelInput(),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.content_copy, size: 16),
                          label: const Text('更多模型名称'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(
                              text: 'https://openrouter.ai/models'
                            ));
                            
                            // 在对话框内显示临时提示，而不是使用Scaffold的Snackbar
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
                                      '已复制到剪贴板，请在浏览器中打开',
                                      style: TextStyle(color: Colors.white, fontSize: 14),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 构建全部模型列表
  Widget _buildAllModelsList() {
    final filteredModels = _searchQuery.isEmpty
        ? _allModels
        : _allModels.where((model) => model.id.toLowerCase().contains(_searchQuery) || 
                               (model.note?.toLowerCase().contains(_searchQuery) ?? false)).toList();

    if (filteredModels.isEmpty) {
      return const Center(child: Text('没有找到匹配的模型'));
    }

    return Column(
      children: [
        // 在列表顶部添加提示信息
        if (filteredModels.any((model) => model.mayBeRegionRestricted))
          Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(51),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '标记为"可能受地区限制"的模型在某些地区可能无法访问。如果选择后无法获得响应，请尝试选择其他模型。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (filteredModels.any((model) => model.isFree))
          Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(26),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '标记为"免费"的模型不支持联网搜索功能。如需使用联网搜索，请选择非免费模型。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredModels.length,
            itemBuilder: (context, index) {
              final modelInfo = filteredModels[index];
              final isSelected = modelInfo.id == _selectedModel;
              
              // 确定模型所属的分类
              String? category;
              for (var cat in modelCategories) {
                if (cat.models.contains(modelInfo)) {
                  category = cat.name;
                  break;
                }
              }

              return ListTile(
                title: Text(modelInfo.displayName),
                subtitle: Row(
                  children: [
                    if (modelInfo.isFree) 
                      const Text('免费 ', style: TextStyle(color: Colors.green)),
                    if (modelInfo.mayBeRegionRestricted)
                      const Tooltip(
                        message: '此模型在某些地区可能不可用',
                        child: Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                        ),
                      ),
                    if (category != null)
                      Text(category, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                selected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedModel = modelInfo.id;
                  });
                  widget.onModelSelected(modelInfo.id);
                  Navigator.of(context).pop(modelInfo.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModelList(ModelCategory category) {
    final filteredModels = _searchQuery.isEmpty
        ? category.models
        : category.models.where((model) => model.id.toLowerCase().contains(_searchQuery) || 
                               (model.note?.toLowerCase().contains(_searchQuery) ?? false)).toList();

    if (filteredModels.isEmpty) {
      return const Center(child: Text('没有找到匹配的模型'));
    }

    return Column(
      children: [
        // 在列表顶部添加提示信息
        if (filteredModels.any((model) => model.mayBeRegionRestricted))
          Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(51),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '标记为"可能受地区限制"的模型在某些地区可能无法访问。如果选择后无法获得响应，请尝试选择其他模型。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (filteredModels.any((model) => model.isFree))
          Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(26),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '标记为"免费"的模型不支持联网搜索功能。如需使用联网搜索，请选择非免费模型。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredModels.length,
            itemBuilder: (context, index) {
              final modelInfo = filteredModels[index];
              final isSelected = modelInfo.id == _selectedModel;
              
              // 确定模型所属的分类
              String? category;
              for (var cat in modelCategories) {
                if (cat.models.contains(modelInfo)) {
                  category = cat.name;
                  break;
                }
              }

              return ListTile(
                title: Text(modelInfo.displayName),
                subtitle: Row(
                  children: [
                    if (modelInfo.isFree) 
                      const Text('免费 ', style: TextStyle(color: Colors.green)),
                    if (modelInfo.mayBeRegionRestricted)
                      const Tooltip(
                        message: '此模型在某些地区可能不可用',
                        child: Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                        ),
                      ),
                    if (category != null)
                      Text(category, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                selected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedModel = modelInfo.id;
                  });
                  widget.onModelSelected(modelInfo.id);
                  Navigator.of(context).pop(modelInfo.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomModelInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '输入自定义模型名称',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customModelController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '提示: 模型格式通常为 提供商/模型名(:版本)',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Text(
                '例如: meta-llama/llama-3.3-70b-instruct',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              if (_customModelController.text.trim().isNotEmpty) {
                final customModel = _customModelController.text.trim();
                setState(() {
                  _selectedModel = customModel;
                });
                widget.onModelSelected(customModel);
                Navigator.of(context).pop(customModel);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('应用自定义模型'),
          ),
        )
      ],
    );
  }
} 