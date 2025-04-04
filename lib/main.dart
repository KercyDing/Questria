import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:developer' as developer;

import 'models/chat_model.dart';
import 'screens/chat_screen.dart';

// 窗口状态管理类
class WindowStateManager extends ChangeNotifier with WindowListener {
  bool _isMaximized = false;
  bool _isProcessing = false; // 防止并发状态变更
  DateTime _lastUpdate = DateTime.now(); // 用于防抖
  
  WindowStateManager() {
    windowManager.addListener(this);
    // 初始化时立即同步一次状态，但不等待结果
    _initState();
  }
  
  // 初始化状态，不通知监听器
  void _initState() {
    windowManager.isMaximized().then((value) {
      _isMaximized = value;
    }).catchError((e) {
      developer.log("窗口状态初始化错误", error: e, name: 'WindowStateManager');
    });
  }
  
  // 使用防抖更新状态
  Future<void> _updateState(bool newState) async {
    // 如果正在处理中或状态未变，则跳过
    if (_isProcessing || _isMaximized == newState) return;
    
    // 防抖处理：判断距离上次更新时间是否小于100ms
    final now = DateTime.now();
    if (now.difference(_lastUpdate).inMilliseconds < 100) return;
    
    _isProcessing = true;
    _lastUpdate = now;
    
    try {
      _isMaximized = newState;
      notifyListeners();
    } finally {
      _isProcessing = false;
    }
  }
  
  bool get isMaximized => _isMaximized;
  
  @override
  void onWindowMaximize() {
    _updateState(true);
  }
  
  @override
  void onWindowUnmaximize() {
    _updateState(false);
  }
  
  @override
  void onWindowRestore() {
    // 使用微任务延迟处理，避免在UI刷新周期内多次更新
    Future.microtask(() {
      windowManager.isMaximized().then((value) {
        if (_isMaximized != value) {
          _updateState(value);
        }
      });
    });
  }
  
  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
}

// 全局拖拽检测器，用于拖拽窗口
class DragToMoveArea extends StatelessWidget {
  final Widget child;
  const DragToMoveArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
      child: child,
    );
  }
}

void main() {
  // 先初始化Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // 初始化窗口管理器
  windowManager.ensureInitialized();
  
  // 配置窗口参数 - 使用无需等待的方式设置
  const windowOptions = WindowOptions(
    title: 'Questria',
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    size: Size(1000, 700),
  );
  
  // 设置窗口选项 - 使用无需等待的方式
  windowManager.waitUntilReadyToShow(windowOptions, () {
    windowManager.show();
    windowManager.focus();
  });
  
  // 应用可以先启动，无需等待窗口完全准备好
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ChatModel()),
        ChangeNotifierProvider(create: (context) => WindowStateManager()),
      ],
      child: const ChatApp(),
    );
  }
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Questria',
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(),
      home: const ChatScreen(),
    );
  }
  
  // 分离主题配置
  ThemeData _buildAppTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      // 添加其他性能优化配置
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
