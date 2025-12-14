//
//  ChatViewController.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import UIKit
import PhotosUI

public final class ChatViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {
    private let tableView = UITableView()
    private let inputBar = InputBarView()
    private let viewModel: ChatViewModel
    private let thinkingButton = UIButton(type: .system)
    private var thinkingEnabled: Bool = false {
        didSet { updateThinkingButtonUI() }
    }
    private var inputBarBottomConstraint: NSLayoutConstraint!
    private var renderedMessageCount: Int = 0  // 优化消息刷新用
    
    // 语音输入
    private lazy var speechBridge = SpeechInputBridge(chatViewModel: viewModel)

    
    // 模型选择
    fileprivate struct ModelOption {
        let title: String
        let config: AIModelConfig
    }

    private var modelOptions: [ModelOption] = []
    private var currentModelIndex: Int = 0 {
        didSet { updateModelButtonTitle() }
    }
    private let modelButton = UIButton(type: .system)
    
    private var currentConfig: AIModelConfig {
        if modelOptions.isEmpty {
            return AIModelConfig(provider: .openAIStyle, modelName: "deepseek-chat", thinking: true)
        }
        return modelOptions[currentModelIndex].config
    }
    
    // 草稿相关
    private let draftKey = "ChatDraft_"
    private var draftTimer: Timer?
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        // 页面消失时保存最后状态的草稿
        saveDraft(text: inputBar.textView.text)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.session.title
        setupTable()
        setupInput()
        setupModelSwitcher()
        setupThinkingToggle()
        setupDraftHandling()
        loadDraft()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        // 消息更新回调，优化刷新逻辑
        viewModel.onNewMessage = { [weak self] message in
            guard let self else { return }
            DispatchQueue.main.async {
                let msgs = self.viewModel.messages()
                let newCount = msgs.count

                // 1) 处理新增行
                if self.renderedMessageCount == 0 {
                    // 首次渲染
                    self.tableView.reloadData()
                    self.renderedMessageCount = newCount
                } else if newCount > self.renderedMessageCount {
                    // 有新消息添加
                    let start = self.renderedMessageCount
                    let end = newCount
                    let indexPaths = (start..<end).map { IndexPath(row: $0, section: 0) }

                    self.tableView.performBatchUpdates {
                        self.tableView.insertRows(at: indexPaths, with: .automatic)
                    }
                    self.renderedMessageCount = newCount
                }

                // 2) 处理某一行更新
                if let row = msgs.firstIndex(where: { $0.id == message.id }) {
                    let ip = IndexPath(row: row, section: 0)
                    if ip.row >= 0 && ip.row < self.tableView.numberOfRows(inSection: 0) {
                        self.tableView.reloadRows(at: [ip], with: .none)
                    } else {
                        self.tableView.reloadData()
                        self.renderedMessageCount = newCount
                    }
                } else {
                    self.tableView.reloadData()
                    self.renderedMessageCount = newCount
                }

                // 3) 滚动到最新消息（如果不在可视区域）
                let rows = self.tableView.numberOfRows(inSection: 0)
                guard rows > 0 else { return }
                let lastIP = IndexPath(row: rows - 1, section: 0)
                let shouldScroll = self.tableView.indexPathsForVisibleRows?.contains(lastIP) == false
                if shouldScroll {
                    self.tableView.scrollToRow(at: lastIP, at: .bottom, animated: true)
                }
            }
            
            viewModel.onDraftUpdated = { [weak self] text in
                DispatchQueue.main.async {
                    self?.inputBar.textView.text = text
                }
            }
            
        }
        
        viewModel.onStreamingStateChanged = { [weak self] streaming in
            guard let self else { return }
            DispatchQueue.main.async {
                self.inputBar.setMode(streaming ? .stop : .send)
            }
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseId)
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 200  // 优化估计行高
        
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
            guard let self else { return }
            var cfg = self.currentConfig
            cfg.thinking = self.thinkingEnabled
            self.viewModel.stream(text: text, config: cfg)
            self.clearDraft()
            self.inputBar.textView.text = ""
            self.inputBar.textView.layoutIfNeeded()
        }
        
        inputBar.onStop = { [weak self] in
            guard let self else { return }
            self.viewModel.cancelCurrentStream()
        }

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
    
    // 草稿处理
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
        viewModel.messages().count
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
        
        cell.onRegenerate = { [weak self] messageID in
            guard let self else { return }
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
    
    // MARK: - UITextViewDelegate
    public func textViewDidChange(_ textView: UITextView) {
        scheduleDraftSave(text: textView.text)
    }
}

// MARK: - PHPickerViewControllerDelegate
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
                    let cfg = self.currentConfig
                    self.viewModel.sendImage(image, prompt: "图中描绘的是什么景象？", config: cfg)
                    self.clearDraft()
                    self.inputBar.textView.text = ""
                    self.inputBar.textView.layoutIfNeeded()
                }
            }
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

// MARK: - 切换思考模式
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

// MARK: - 键盘处理
extension ChatViewController {
    @objc private func keyboardWillShow(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height - view.safeAreaInsets.bottom
        inputBarBottomConstraint.constant = -keyboardHeight
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
        
        scrollToLatestMessage()
    }

    @objc private func keyboardWillHide(_ notification: NSNotification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        
        inputBarBottomConstraint.constant = 0
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    private func scrollToLatestMessage() {
        let count = viewModel.messages().count
        guard count > 0 else { return }
        tableView.scrollToRow(
            at: IndexPath(row: count - 1, section: 0),
            at: .bottom,
            animated: true
        )
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)
    }
}



extension ChatViewController {
    func asrStart(asrApiKey: String) {
        let asrCfg = ASRConfig(
            apiKey: asrApiKey,
            region: .singaporeIntl, // or .beijing
            model: "qwen3-asr-flash-realtime",
            language: "zh",
            inputAudioFormat: "pcm",
            inputSampleRate: 16000,
            enableVAD: true
        )

        // 聊天模型 config：用 ChatViewController 当前选择的模型（currentConfig）
        var chatCfg = self.currentConfig
        chatCfg.thinking = self.thinkingEnabled

        speechBridge.start(asrConfig: asrCfg, chatConfig: chatCfg)

    }


    func asrPushChunk(_ chunk: Data) {
        speechBridge.pushAudioChunk(chunk)
    }

    func asrStop() {
        // enableVAD=true => needCommit = false
        speechBridge.stop(needCommit: false)
    }

}
