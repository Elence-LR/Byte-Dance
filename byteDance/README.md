# Byte-Dance

一个分层清晰、可扩展的 iOS 聊天应用模板，采用依赖倒置与 MVVM 架构，支持同步与流式（SSE）模型响应、基础持久化与本地化。

## 项目结构

```
Byte-Dance/
 ├── App/
 ├── Domain/
 ├── Data/
 ├── Presentation/
 ├── Infrastructure/
 └── Resources/
```

## 分层说明

- App 层
  - 入口与导航路由。
  - `App/AppDelegate.swift:1` 应用生命周期配置。
  - `App/SceneDelegate.swift:1` 窗口与场景管理，启动协调器。
  - `App/AppCoordinator.swift:1` 路由与首屏控制，进入会话列表页。

- Domain 层（业务逻辑，不依赖 UIKit）
  - Entities：数据模型
    - `Domain/Entities/Message.swift:1` 消息体（角色、内容、时间）。
    - `Domain/Entities/Session.swift:1` 会话（标题、消息、归档标记）。
    - `Domain/Entities/AIModelConfig.swift:1` 模型配置（温度、Token 上限、API Key 等）。
  - Interfaces：核心协议
    - `Domain/Interfaces/LLMServiceProtocol.swift:1` 模型统一接口，定义发送与流式响应。
    - `Domain/Interfaces/ChatRepositoryProtocol.swift:1` 聊天记录仓储接口。
  - UseCases：业务用例
    - `Domain/UseCases/SendMessageUseCase.swift:1` 发送消息，写入仓储，请求模型，记录回复；支持流式。
    - `Domain/UseCases/ManageSessionUseCase.swift:1` 会话的新建、重命名、归档与查询。

- Data 层（对 Domain 的实现）
  - Networking：网络工具
    - `Data/Networking/HTTPClient.swift:1` 基础请求（`URLSession` + async/await）。
    - `Data/Networking/SSEHandler.swift:1` Server-Sent Events 流封装为 `AsyncStream<String>`。
    - `Data/Networking/APIEndpoints.swift:1` 统一接口路径生成。
  - Services：模型适配器
    - `Data/Services/OpenAIAdapter.swift:1` OpenAI 风格实现，适配统一协议。
    - `Data/Services/DeepSeekAdapter.swift:1` DeepSeek 风格实现。
    - `Data/Services/MockLLMService.swift:1` 测试用回声服务。
  - Repositories：仓储实现
    - `Data/Repositories/ChatRepository.swift:1` 内存型聊天记录 CRUD。
    - `Data/Repositories/FileStorage.swift:1` 简易 JSON 持久化读写（可与仓储结合）。

- Presentation 层（UI）
  - Common：通用基础类
    - `Presentation/Common/BaseViewController.swift:1` 基础控制器，统一外观。
  - Scenes：页面
    - Chat：聊天核心页
      - `Presentation/Scenes/Chat/ChatViewModel.swift:1` MVVM 视图模型，封装用例并提供消息输出。
      - `Presentation/Scenes/Chat/ChatViewController.swift:1` 聊天页，表格展示消息、输入发送。
      - `Presentation/Scenes/Chat/Views/InputBarView.swift:1` 输入栏（文本 + 发送）。
      - `Presentation/Scenes/Chat/Views/MessageCell.swift:1` 消息气泡（左右对齐区分角色）。
    - SessionList：会话列表页
      - `Presentation/Scenes/SessionList/SessionListViewController.swift:1` 列表、创建并跳转至聊天页。
    - Settings：设置页
      - `Presentation/Scenes/Settings/SettingsViewController.swift:1` 模型名与 API Key 的简单存取。
  - Components：组件
    - MarkdownRenderer
      - `Presentation/Components/MarkdownRenderer/MarkdownParser.swift:1` 解析 ``` 代码块并渲染等宽字体与背景。
      - `Presentation/Components/MarkdownRenderer/CodeBlockView.swift:1` 代码块视图，支持一键复制。

- Infrastructure 层（基础设施）
  - `Infrastructure/Logger.swift:1` 简易线程安全日志工具。
  - `Infrastructure/AudioManager.swift:1` 基础录音（开始/结束，`AVAudioRecorder`）。
  - `Infrastructure/ImageProcessor.swift:1` 图片压缩到指定大小。

- Resources（资源）
  - `Resources/Localizable.strings:1` 本地化文案："发送"、"会话"、"设置"、"保存"、"复制"。

## 运行与配置

- 将当前源文件加入你的 Xcode iOS App Target，iOS 13+ 使用 `SceneDelegate` 启动。
- 默认首页为会话列表页，可点击右上角 + 新建会话并进入聊天页。
- 切换到真实模型服务：在 `SessionListViewController` 中替换 `service` 为 `OpenAIAdapter` 或 `DeepSeekAdapter`，并在设置页填写 `API Key` 与 `Model Name`（存储于 `UserDefaults`）。
- 持久化：将 `ChatRepository` 与 `FileStorage` 集成，在 CRUD 后调用 `save`，启动时调用 `load`。

## 数据流与依赖倒置

- UI 通过 ViewModel 调用 UseCase。
- UseCase 依赖 `ChatRepositoryProtocol` 与 `LLMServiceProtocol`，不关心具体实现（Data 层注入）。
- 服务适配器将统一的 Domain 请求映射为具体 HTTP/SSE 调用，返回 Domain 的 `Message`。

## 可扩展点

- 模型切换：新增适配器实现 `LLMServiceProtocol`，在注入处替换即可。
- 渲染增强：在 `MarkdownParser` 中扩展更多 Markdown 语法与主题。
- 存储升级：替换 `FileStorage` 为 Core Data 或 SQLite。
- UI 优化：引入差分数据源、消息局部刷新、下拉加载历史等。
