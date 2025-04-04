# Questria AI 聊天助手

Questria 是一个基于 Flutter 开发的跨平台 AI 聊天应用，允许用户与多种 AI 大模型进行对话。

## 功能特点

- 支持多种 AI 模型，包括 OpenAI、Claude、DeepSeek、Qwen 和 Google 的各类模型
- 支持图像分析能力，可上传图片并获取 AI 分析结果（仅部分大模型支持）
- 多对话管理，可创建、切换和删除不同的对话
- 自动生成对话标题，便于回顾和管理
- 网络搜索功能，获取实时信息和更新
- 流式响应，实时显示 AI 回复
- 响应式界面设计，适配不同设备尺寸

## 开始使用

1. 获取 OpenRouter API 密钥 (https://openrouter.ai/settings/keys)
2. 在应用的 API 设置中输入 API 密钥
3. 选择适合您需求的 AI 模型
4. 开始对话！

## 技术栈

- Flutter 框架
- Provider 状态管理
- Dio 网络请求
- Flutter Secure Storage 安全存储

## 注意事项

- 部分模型可能受地区限制，不同地区的可用性可能有所不同
- 标记为"免费"的模型不支持网络搜索功能
- 图片分析仅支持 JPG 和 PNG 格式

## 系统需求

- 支持 Windows、macOS、iOS 和 Android 系统以及 Web
- 需要网络连接以访问 AI 服务
- 部分模型需要魔法
