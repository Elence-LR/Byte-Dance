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

    // MARK: - TableView
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

    // MARK: - InputBar
    private func setupInput() {
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputBar)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        ])
        
        // 文本发送
        inputBar.onSend = { [weak self] text in
            guard let self else { return }
            var cfg = self.currentConfig
            cfg.thinking = self.thinkingEnabled
            self.viewModel.stream(text: text, config: cfg)
        }

        // 图片按钮点击 -> 弹出 PHPicker 支持多选
        inputBar.onImageButtonTapped = { [weak self] in
            guard let self = self else { return }
            var pickerConfig = PHPickerConfiguration()
            pickerConfig.filter = .images
            pickerConfig.selectionLimit = 0 // 多选
            let picker = PHPickerViewController(configuration: pickerConfig)
            picker.delegate = self
            self.present(picker, animated: true)
        }
    }

    // MARK: - 一次性发送多张图片
    private func sendPickedImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        
        let cfg = self.currentConfig
        // 仅允许 qwen3-vl-plus 发送图片
        guard cfg.modelName.lowercased() == "qwen3-vl-plus" else {
            self.viewModel.addSystemTip("该模型不支持图片")
            return
        }

        let prompt = self.inputBar.textView.text ?? "图中描绘的是什么景象？"

        // 将多张图片合并为一条 message
        var attachments: [MessageAttachment] = []
        for img in images {
            if let data = ImageProcessor.jpegData(from: img, maxKB: 300) {
                let base64 = data.base64EncodedString()
                attachments.append(.init(kind: .imageDataURL, value: "data:image/jpeg;base64,\(base64)"))
            }
        }

        let userMsg = Message(role: .user, content: prompt, attachments: attachments)
        
        // 一次性发送，模型只会回复一次
        self.viewModel.stream(userMessage: userMsg, config: cfg)
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

// MARK: - PHPicker Delegate
extension ChatViewController: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        var images: [UIImage] = []
        let group = DispatchGroup()
        
        for result in results {
            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
            
            group.enter()
            provider.loadObject(ofClass: UIImage.self) { object, error in
                if let img = object as? UIImage {
                    images.append(img)
                }
                group.leave()
            }
        }
        
        // 等待所有图片加载完成后一次性发送
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.sendPickedImages(images)
        }
    }
}


// MARK: - 模型选择
extension ChatViewController {
    
    private func setupModelSwitcher() {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        config.imagePlacement = .trailing
        config.imagePadding = 6
        modelButton.configuration = config
        modelButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        modelButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
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
        rebuildModelMenu()
    }

    private func switchModel(to index: Int) {
        guard index != currentModelIndex else { return }
        currentModelIndex = index
        Task { @MainActor in
            viewModel.addSystemTip("已切换到：\(modelOptions[index].title)")
        }
    }
}

// MARK: - 思考模式切换
extension ChatViewController {
    
    private func setupThinkingToggle() {
        thinkingButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thinkingButton)
        var cfg = UIButton.Configuration.filled()
        cfg.cornerStyle = .capsule
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        cfg.imagePadding = 6
        thinkingButton.configuration = cfg
        thinkingButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        thinkingButton.addTarget(self, action: #selector(didTapThinkingToggle), for: .touchUpInside)
        thinkingEnabled = currentConfig.thinking

        NSLayoutConstraint.activate([
            thinkingButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            thinkingButton.bottomAnchor.constraint(equalTo: inputBar.topAnchor, constant: -8),
            thinkingButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func didTapThinkingToggle() {
        thinkingEnabled.toggle()
        Task { @MainActor in
            viewModel.addSystemTip(thinkingEnabled ? "已开启思考模式" : "已关闭思考模式")
        }
    }

    private func updateThinkingButtonUI() {
        let title = thinkingEnabled ? "思考：开" : "思考：关"
        let imageName = thinkingEnabled ? "brain.head.profile" : "brain"
        thinkingButton.setTitle(title, for: .normal)
        thinkingButton.setImage(UIImage(systemName: imageName), for: .normal)
        if #available(iOS 15.0, *) {
            thinkingButton.configuration?.baseBackgroundColor = thinkingEnabled ? .systemGreen : .tertiarySystemFill
            thinkingButton.configuration?.baseForegroundColor = thinkingEnabled ? .white : .label
        }
    }
}
