//
//  ChatViewController.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import UIKit
import PhotosUI

public final class ChatViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private let inputBar = InputBarView()
    private let viewModel: ChatViewModel
    private let thinkingButton = UIButton(type: .system)
    private var thinkingEnabled: Bool = false {
        didSet { updateThinkingButtonUI() }
    }

    // 模型选择
    fileprivate struct ModelOption {
            let title: String        // 按钮展示名
            let config: AIModelConfig
        }

    private var modelOptions: [ChatViewController.ModelOption] = []

    private var currentModelIndex: Int = 0 {
        didSet { updateModelButtonTitle() }
    }

    private var currentConfig: AIModelConfig {
        if modelOptions.isEmpty {
            return AIModelConfig(provider: .openAIStyle, modelName: "deepseek-chat", thinking: true)
        }
        return modelOptions[currentModelIndex].config
    }

    private let modelButton = UIButton(type: .system)
    
    

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.session.title
        setupTable()
        setupInput()
        setupModelSwitcher()
        setupThinkingToggle()
        
        // 消息更新回调，用于刷新 UI
        viewModel.onNewMessage = { [weak self] m in
            DispatchQueue.main.async {
                guard let self else { return }
                print("ChatVC onNewMessage role:", m.role.rawValue, "contentLen:", m.content.count, "reasoningLen:", m.reasoning?.count ?? 0)
                self.tableView.reloadData()
                let count = self.viewModel.messages().count
                if count > 0 {
                    self.tableView.scrollToRow(at: IndexPath(row: count - 1, section: 0),
                                               at: .bottom,
                                               animated: true)
                }
            }
        }
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseId)
        tableView.separatorStyle = .none
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        
        if #available(iOS 15.0, *) {
            tableView.isPrefetchingEnabled = false
        } else {
            tableView.prefetchDataSource = nil
        }

        view.addSubview(tableView)
    }


    private func setupInput() {
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputBar)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // TableView 顶部到安全区域
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // InputBar 位于底部安全区域
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // TableView 底部连接到 InputBar 顶部
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        ])
        
        // 文本发送按钮逻辑：调用 ViewModel 发送消息
        inputBar.onSend = { [weak self] text in
            guard let self else { return }
            var cfg = self.currentConfig
            cfg.thinking = self.thinkingEnabled
            print("ChatVC onSend text length:", text.count)
            print("ChatVC config provider:", cfg.provider.rawValue, "model:", cfg.modelName, "baseURL:", cfg.baseURL ?? "nil", "apiKey:", (cfg.apiKey?.isEmpty == false))
            self.viewModel.stream(text: text, config: cfg)
        }

        //李相瑜新增：图片按钮点击 -> 弹 picker
        inputBar.onImageButtonTapped = { [weak self] in
            guard let self = self else { return }
            var pickerConfig = PHPickerConfiguration()
            pickerConfig.filter = .images
            pickerConfig.selectionLimit = 1
            let picker = PHPickerViewController(configuration: pickerConfig)
            picker.delegate = self
            self.present(picker, animated: true)
        }
    }

    // MARK: - UITableViewDataSource
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.messages().count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseId, for: indexPath) as! MessageCell
        let message = viewModel.messages()[indexPath.row]

        cell.configure(with: message, isReasoningExpanded: viewModel.isReasoningExpanded(messageID: message.id))

        cell.onToggleReasoning = { [weak self] messageID in
            guard let self else { return }
            self.viewModel.toggleReasoningExpanded(messageID: messageID)

            //  局部刷新这一行（避免整表闪）
            if let row = self.viewModel.messages().firstIndex(where: { $0.id == messageID }) {
                self.tableView.performBatchUpdates {
                    self.tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .fade)
                }
            } else {
                self.tableView.reloadData()
            }
        }

        return cell
    }

}

// 李相瑜新增：MARK: - 图片选择器回调
extension ChatViewController: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self = self else { return }
            if let image = object as? UIImage {
                DispatchQueue.main.async {
//                    self.viewModel.sendImage(image)
                    let cfg = self.currentConfig
//                    cfg.thinking = self.thinkingEnabled

                    // 目前只有qwen3-vl-plus支持图像输入
                    // 可以在做拦截提示：如果当前是 DeepSeek，就提示“该模型不支持图片”
                    // prompt应该从用户输入框拿
                    self.viewModel.sendImage(image, prompt: "图中描绘的是什么景象？", config: cfg)

                }
            }
        }
    }
}

// MARK: 模型选择
extension ChatViewController {
    
    private func setupModelSwitcher() {
        // 胶囊样式按钮
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        config.imagePlacement = .trailing
        config.imagePadding = 6
        modelButton.configuration = config

        modelButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        modelButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)

        // iOS 14+：点按钮直接弹出菜单
        modelButton.showsMenuAsPrimaryAction = true
        reloadModelOptions()
        rebuildModelMenu()
        updateModelButtonTitle()

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: modelButton)
    }

    private func reloadModelOptions() {
        var opts: [ChatViewController.ModelOption] = [
            .init(title: "DeepSeek", config: AIModelConfig(provider: .openAIStyle, modelName: "deepseek-chat", thinking: true, apiKey: "sk-24696f0c8e1f490386d913ef1caba425")),
            .init(title: "Qwen-Plus",   config: AIModelConfig(provider: .dashscope, modelName: "qwen-plus", thinking: true, apiKey: "sk-c548943059844079a4cdcb92ed19163a")),
            .init(title: "Qwen3-VL-Plus",   config: AIModelConfig(provider: .dashscope, modelName: "qwen3-vl-plus", thinking: false, apiKey: "sk-c548943059844079a4cdcb92ed19163a")),
        ]
        if let data = UserDefaults.standard.data(forKey: "custom_models"),
           let arr = try? JSONDecoder().decode([AIModelConfig].self, from: data) {
            for m in arr {
                let title = m.modelName + " (Custom)"
                opts.append(.init(title: title, config: m))
            }
        }
        modelOptions = opts
        if currentModelIndex >= modelOptions.count { currentModelIndex = 0 }
    }

    
    private func rebuildModelMenu() {
        reloadModelOptions()
        let actions = modelOptions.enumerated().map { idx, opt in
            UIAction(title: opt.title, state: (idx == currentModelIndex ? .on : .off)) { [weak self] _ in
                self?.switchModel(to: idx)
            }
        }
        modelButton.menu = UIMenu(title: "选择模型", children: actions)
    }

    
    private func updateModelButtonTitle() {
        guard !modelOptions.isEmpty else { return }
        modelButton.setTitle(modelOptions[currentModelIndex].title, for: .normal)
        rebuildModelMenu() // 让“对勾”状态刷新
    }

    
    private func switchModel(to index: Int) {
        guard index != currentModelIndex else { return }
        currentModelIndex = index
        Task { @MainActor in
            viewModel.addSystemTip("已切换到：\(modelOptions[index].title)")
        }
    }

}


// MARK: 切换思考模式
extension ChatViewController {
    
    private func setupThinkingToggle() {
        thinkingButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thinkingButton)

        // 样式：小胶囊
        var cfg = UIButton.Configuration.filled()
        cfg.cornerStyle = .capsule
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        cfg.imagePadding = 6
        thinkingButton.configuration = cfg
        thinkingButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)

        thinkingButton.addTarget(self, action: #selector(didTapThinkingToggle), for: .touchUpInside)

        // 初始值：与当前模型的 config.thinking 对齐（为空时使用默认）
        thinkingEnabled = currentConfig.thinking

        NSLayoutConstraint.activate([
            // 放在 inputBar 上方，左下角位置（你也可以放右侧）
            thinkingButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            thinkingButton.bottomAnchor.constraint(equalTo: inputBar.topAnchor, constant: -8),
            thinkingButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func didTapThinkingToggle() {
        thinkingEnabled.toggle()

        // 你也可以提示一下（你工程里已有 system tip）
        Task { @MainActor in
            viewModel.addSystemTip(thinkingEnabled ? "已开启思考模式" : "已关闭思考模式")
        }
    }

    private func updateThinkingButtonUI() {
        // 这里用“brain”图标 + 文案，开关态一眼能看出
        let title = thinkingEnabled ? "思考：开" : "思考：关"
        let imageName = thinkingEnabled ? "brain.head.profile" : "brain"
        thinkingButton.setTitle(title, for: .normal)
        thinkingButton.setImage(UIImage(systemName: imageName), for: .normal)

        // 轻微区分一下状态（不想改颜色也行）
        if #available(iOS 15.0, *) {
            thinkingButton.configuration?.baseBackgroundColor = thinkingEnabled ? .systemGreen : .tertiarySystemFill
            thinkingButton.configuration?.baseForegroundColor = thinkingEnabled ? .white : .label
        }
    }

}
