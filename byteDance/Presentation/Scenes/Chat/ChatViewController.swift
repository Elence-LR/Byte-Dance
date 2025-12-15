//
//  ChatViewController.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//

import UIKit
import PhotosUI

public final class ChatViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {
    
    // MARK: - UI组件
    private let tableView = UITableView()
    private let inputBar = InputBarView()
    private let viewModel: ChatViewModel
    private let thinkingButton = UIButton(type: .system)
    private let combineButton = UIButton(type: .system)
    
    private var thinkingEnabled: Bool = false { didSet { updateThinkingButtonUI() } }
    private var combineEnabled: Bool = true
    private var inputBarBottomConstraint: NSLayoutConstraint!
    private var renderedMessageCount: Int = 0 // 用于优化刷新
    
    // 模型选择
    fileprivate struct ModelOption {
        let title: String
        let config: AIModelConfig
    }
    private var modelOptions: [ModelOption] = []
    private var currentModelIndex: Int = 0 { didSet { updateModelButtonTitle() } }
    private let modelButton = UIButton(type: .system)
    
    private var currentConfig: AIModelConfig {
        if modelOptions.isEmpty {
            return AIModelConfig(provider: .openAIStyle, modelName: "deepseek-chat", thinking: true)
        }
        return modelOptions[currentModelIndex].config
    }
    
    // 草稿
    private let draftKey = "ChatDraft_"
    private var draftTimer: Timer?
    
    // 语音输入（保留）
    private lazy var speechBridge = SpeechInputBridge(chatViewModel: viewModel)
    
    // MARK: - Init
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 生命周期
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        saveDraft(text: inputBar.textView.text)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.session.title
        
        setupTable()
        setupInput()
        setupModelSwitcher()
        setupThinkingToggle()
        setupCombineToggle()
        setupDraftHandling()
        loadDraft()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        setupOnNewMessageCallback()
        setupOnStreamingStateChanged()
    }
    
    // MARK: - UI事件
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - TableView Setup
    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseId)
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 200
        if #available(iOS 15.0, *) { tableView.isPrefetchingEnabled = false }
        else { tableView.prefetchDataSource = nil }
        view.addSubview(tableView)
    }
    
    // MARK: - InputBar Setup
    private func setupInput() {
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputBar)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        ])
        
        inputBarBottomConstraint = inputBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        inputBarBottomConstraint.isActive = true
        
        inputBar.onSend = { [weak self] text in
            guard let self = self, !text.isEmpty else { return }
            var cfg = self.currentConfig
            cfg.thinking = self.thinkingEnabled
            
            if self.combineEnabled {
                Task {
                    let summary = await self.viewModel.summarizeHistory(config: cfg) ?? ""
                    let finalText = "这是我们之前的聊天内容：\(summary)\n请你结合以上内容，回答一下问题：\(text)"
                    self.viewModel.streamWithCombined(displayText: text, sendText: finalText, config: cfg)
                }
            } else {
                self.viewModel.stream(text: text, config: cfg)
            }
            self.clearDraft()
            self.inputBar.textView.text = ""
            self.inputBar.textView.layoutIfNeeded()
        }
        
        inputBar.onStop = { [weak self] in
            self?.viewModel.cancelCurrentStream()
        }
        
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
    
    // MARK: - 多图发送
    private func sendPickedImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }

        let cfg = self.currentConfig
        
        // 拦截提示：仅允许 qwen3-vl-plus 支持图片
        if cfg.modelName.lowercased() != "qwen3-vl-plus" {
            self.viewModel.addSystemTip("当前模型不支持图片输入，请切换至qwen3-vl-plus")
            return
        }
        
        // 使用输入框文本作为提示词，如果为空使用默认
        let prompt = self.inputBar.textView.text.isEmpty ? "图中描绘的是什么景象？" : self.inputBar.textView.text!

        // 构造 attachments
        var attachments: [MessageAttachment] = []
        for img in images {
            if let data = ImageProcessor.optimizedJpegData(from: img, maxKB: 300) {
                attachments.append(.init(kind: .imageDataURL,
                                         value: "data:image/jpeg;base64,\(data.base64EncodedString())"))
            }
        }

        // 构造用户消息
        let userMsg = Message(role: .user, content: prompt, attachments: attachments)

        // 调用原始 stream(userMessage:) → 保持原版 append 逻辑
        self.viewModel.stream(userMessage: userMsg, config: cfg)

        // ✅ 清空输入框和草稿
        self.clearDraft()
        self.inputBar.textView.text = ""
    }
    
    // MARK: - Draft Handling
    private func setupDraftHandling() {
        inputBar.textView.delegate = self
    }
    
    private func scheduleDraftSave(text: String) {
        draftTimer?.invalidate()
        draftTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.saveDraft(text: text)
        }
    }
    
    private func saveDraft(text: String) {
        let key = draftKey + viewModel.session.id.uuidString
        UserDefaults.standard.set(text, forKey: key)
    }
    
    private func loadDraft() {
        let key = draftKey + viewModel.session.id.uuidString
        if let draftText = UserDefaults.standard.string(forKey: key) {
            inputBar.textView.text = draftText
            inputBar.textView.layoutIfNeeded()
        }
    }
    
    private func clearDraft() {
        let key = draftKey + viewModel.session.id.uuidString
        UserDefaults.standard.removeObject(forKey: key)
        draftTimer?.invalidate()
    }
    
    // MARK: - UITableViewDataSource
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.messages().count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseId, for: indexPath) as! MessageCell
        let message = viewModel.messages()[indexPath.row]
        cell.configure(
            with: message,
            isReasoningExpanded: viewModel.isReasoningExpanded(messageID: message.id),
            showRegenerate: viewModel.canRegenerate(messageID: message.id)
        )
        
        cell.onToggleReasoning = { [weak self] messageID in
            guard let self = self else { return }
            self.viewModel.toggleReasoningExpanded(messageID: messageID)
            if let row = self.viewModel.messages().firstIndex(where: { $0.id == messageID }) {
                self.tableView.performBatchUpdates {
                    self.tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .fade)
                }
            } else {
                self.tableView.reloadData()
            }
        }
        
        cell.onRegenerate = { [weak self] messageID in
            guard let self = self else { return }
            var cfg = self.currentConfig
            cfg.thinking = self.thinkingEnabled
            self.viewModel.regenerate(assistantMessageID: messageID, config: cfg)
            if let row = self.viewModel.messages().firstIndex(where: { $0.id == messageID }) {
                self.tableView.performBatchUpdates {
                    self.tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
                }
            }
        }
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        let msg = viewModel.messages()[indexPath.row]
        let w = tableView.bounds.width
        if let h = viewModel.cachedHeight(messageID: msg.id, width: w) { return h }
        return smartEstimateHeight(for: msg, width: w)
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let msg = viewModel.messages()[indexPath.row]
        let w = tableView.bounds.width
        let h = cell.bounds.height
        viewModel.setCachedHeight(messageID: msg.id, width: w, height: h)
    }
    
    // MARK: - UITextViewDelegate
    public func textViewDidChange(_ textView: UITextView) {
        scheduleDraftSave(text: textView.text)
    }
}
 
extension ChatViewController {
    private func smartEstimateHeight(for message: Message, width: CGFloat) -> CGFloat {
        let text = message.content
        let len = text.count
        var h: CGFloat = 96
        let charsPerLine = 26.0
        let lineHeight = 22.0
        let lines = max(1.0, ceil(Double(len) / charsPerLine))
        h += CGFloat(lines * lineHeight)
        let hasCode = text.contains("```")
        let hasTable = text.contains("|") && text.contains("---")
        let listCount = text.split(separator: "\n").filter { $0.hasPrefix("- ") || $0.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil }.count
        if hasCode { h += 220 }
        if hasTable { h += 180 }
        if listCount > 0 { h += CGFloat(min(listCount, 10) * 20) }
        if let atts = message.attachments { h += CGFloat(atts.count) * 220 }
        if message.role == .assistant, message.reasoning != nil { h += 60 }
        if len > 500 { h += 120 }
        let minH: CGFloat = 80
        let maxH: CGFloat = 900
        return min(max(h, minH), maxH)
    }
}

// MARK: - PHPickerViewControllerDelegate
extension ChatViewController: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        let group = DispatchGroup()
        var images: [UIImage] = []
        
        for result in results {
            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
            group.enter()
            provider.loadObject(ofClass: UIImage.self) { object, error in
                if let img = object as? UIImage { images.append(img) }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self, !images.isEmpty else { return }
            self.sendPickedImages(images)
        }
    }
}

// MARK: - 模型选择 & 思考模式 & combine 按钮
extension ChatViewController {
    
    private func setupModelSwitcher() {
        var cfg = UIButton.Configuration.filled()
        cfg.cornerStyle = .capsule
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        cfg.imagePadding = 6
        modelButton.configuration = cfg
        modelButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        modelButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        modelButton.showsMenuAsPrimaryAction = true
        reloadModelOptions()
        rebuildModelMenu()
        updateModelButtonTitle()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: modelButton)
    }
    
    private func reloadModelOptions() {
        var opts: [ModelOption] = [
                    .init(title: "DeepSeek", config: AIModelConfig(provider: .openAIStyle, modelName: "deepseek-chat", thinking: true, apiKey: "sk-24696f0c8e1f490386d913ef1caba425")),
                    .init(title: "Qwen-Plus", config: AIModelConfig(provider: .dashscope, modelName: "qwen-plus", thinking: true, apiKey: "sk-c548943059844079a4cdcb92ed19163a")),
                    .init(title: "Qwen3-VL-Plus", config: AIModelConfig(provider: .dashscope, modelName: "qwen3-vl-plus", thinking: false, apiKey: "sk-c548943059844079a4cdcb92ed19163a")),
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
            UIAction(title: opt.title, state: idx == currentModelIndex ? .on : .off) { [weak self] _ in
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
    
    // 思考模式
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
    
    // Combine全文按钮
    private func setupCombineToggle() {
        combineButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(combineButton)
        var cfg = UIButton.Configuration.filled()
        cfg.cornerStyle = .capsule
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        cfg.imagePadding = 6
        combineButton.configuration = cfg
        combineButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        combineButton.addTarget(self, action: #selector(didTapCombineToggle), for: .touchUpInside)
        updateCombineButtonUI()
        NSLayoutConstraint.activate([
            combineButton.leadingAnchor.constraint(equalTo: thinkingButton.trailingAnchor, constant: 8),
            combineButton.bottomAnchor.constraint(equalTo: thinkingButton.bottomAnchor),
            combineButton.heightAnchor.constraint(equalTo: thinkingButton.heightAnchor)
        ])
    }
    
    @objc private func didTapCombineToggle() {
        combineEnabled.toggle()
        updateCombineButtonUI()
        Task { @MainActor in
            viewModel.addSystemTip(combineEnabled ? "已开启结合全文" : "已关闭结合全文")
        }
    }
    
    private func updateCombineButtonUI() {
        let title = combineEnabled ? "结合全文：开" : "结合全文：关"
        let imageName = combineEnabled ? "text.book.closed" : "text.book.closed.fill"
        combineButton.setTitle(title, for: .normal)
        combineButton.setImage(UIImage(systemName: imageName), for: .normal)
        if #available(iOS 15.0, *) {
            combineButton.configuration?.baseBackgroundColor = combineEnabled ? .systemBlue : .tertiarySystemFill
            combineButton.configuration?.baseForegroundColor = combineEnabled ? .white : .label
        }
    }
}

// MARK: - 键盘处理
extension ChatViewController {
    @objc private func keyboardWillShow(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        let keyboardHeight = keyboardFrame.height - view.safeAreaInsets.bottom
        inputBarBottomConstraint.constant = -keyboardHeight
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
        scrollToLatestMessage()
    }
    
    @objc private func keyboardWillHide(_ notification: NSNotification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        inputBarBottomConstraint.constant = 0
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }
    
    private func scrollToLatestMessage() {
        let count = viewModel.messages().count
        guard count > 0 else { return }
        tableView.scrollToRow(at: IndexPath(row: count - 1, section: 0), at: .bottom, animated: true)
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)
    }
}

// MARK: - 消息回调
extension ChatViewController {
    private func setupOnNewMessageCallback() {
        viewModel.onNewMessage = { [weak self] message in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let msgs = self.viewModel.messages()
                let newCount = msgs.count
                if self.renderedMessageCount == 0 {
                    self.tableView.reloadData()
                    self.renderedMessageCount = newCount
                } else if newCount > self.renderedMessageCount {
                    let start = self.renderedMessageCount
                    let end = newCount
                    let indexPaths = (start..<end).map { IndexPath(row: $0, section: 0) }
                    self.tableView.performBatchUpdates {
                        self.tableView.insertRows(at: indexPaths, with: .automatic)
                    }
                    self.renderedMessageCount = newCount
                }
                // 局部刷新
                if let row = msgs.firstIndex(where: { $0.id == message.id }) {
                    let ip = IndexPath(row: row, section: 0)
                    if ip.row >= 0 && ip.row < self.tableView.numberOfRows(inSection: 0) {
                        self.tableView.reloadRows(at: [ip], with: .none)
                    } else {
                        self.tableView.reloadData()
                        self.renderedMessageCount = newCount
                    }
                }
                let rows = self.tableView.numberOfRows(inSection: 0)
                if rows > 0 {
                    let lastIP = IndexPath(row: rows - 1, section: 0)
                    let shouldScroll = self.tableView.indexPathsForVisibleRows?.contains(lastIP) == false
                    if shouldScroll { self.tableView.scrollToRow(at: lastIP, at: .bottom, animated: true) }
                }
                self.viewModel.onDraftUpdated = { [weak self] text in
                    self?.inputBar.textView.text = text
                }
            }
        }
    }
    
    private func setupOnStreamingStateChanged() {
        viewModel.onStreamingStateChanged = { [weak self] streaming in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.inputBar.setMode(streaming ? .stop : .send)
            }
        }
    }
}
