//
//  InputBarView.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//

import UIKit
import Foundation

public final class InputBarView: UIView, UITextViewDelegate {
    
    public enum Mode {
        case send
        case stop
    }
    
    // UI
    public let imageButton = UIButton(type: .system)
    public let plusButton = UIButton(type: .system)
    public let textView = UITextView()
    public let sendButton = UIButton(type: .system)
    
    public var onSend: ((String) -> Void)?
    public var onStop: (() -> Void)?
    public var onImageButtonTapped: (() -> Void)?
    public var onToggleThinking: (() -> Void)?
    public var onToggleCombine: (() -> Void)?
    
    private var mode: Mode = .send { didSet { updateSendButtonUI() } }
    
    private var textViewHeightConstraint: NSLayoutConstraint?
    private let minInputHeight: CGFloat = 36
    private let maxInputHeight: CGFloat = 180
    
    // 面板
    private let toolPanel = UIView()
    private let toolRow = UIStackView()
    private var toolPanelHeightConstraint: NSLayoutConstraint?
    private let cameraTile = UIStackView()
    private let cameraIcon = UIButton(type: .system)
    private let cameraLabel = UILabel()
    private let thinkingTile = UIStackView()
    private let thinkingIcon = UIButton(type: .system)
    private let thinkingLabel = UILabel()
    private let combineTile = UIStackView()
    private let combineIcon = UIButton(type: .system)
    private let combineLabel = UILabel()
    
    // 草稿
    private let draftStorage = DraftStorage()
    private var currentSessionID: UUID!
    private var draftTimer: Timer?
    
    // MARK: - Init
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupDraftLogic()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupDraftLogic()
    }
    
    // MARK: - Setup UI
    private func setup() {
        // 加号按钮（放置在输入框左侧）
        plusButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        plusButton.tintColor = .label
        plusButton.addTarget(self, action: #selector(plusTapped), for: .touchUpInside)
        
        // 图片按钮移入面板
        imageButton.setImage(UIImage(systemName: "camera"), for: .normal)
        imageButton.tintColor = .label
        imageButton.addTarget(self, action: #selector(imageButtonTapped), for: .touchUpInside)
        
        // 文本输入
        textView.isScrollEnabled = false
        textView.delegate = self
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        
        // 发送按钮
        sendButton.setTitle(NSLocalizedString("Send", comment: ""), for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [plusButton, textView, sendButton])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        sendButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        sendButton.setContentHuggingPriority(.required, for: .horizontal)
        plusButton.setContentHuggingPriority(.required, for: .horizontal)
        plusButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textViewHeightConstraint = textView.heightAnchor.constraint(equalToConstant: minInputHeight)
        textViewHeightConstraint?.isActive = true
        
        // 工具面板（默认隐藏）
        toolPanel.translatesAutoresizingMaskIntoConstraints = false
        toolPanel.backgroundColor = .tertiarySystemBackground
        toolPanel.layer.cornerRadius = 10
        toolPanel.layer.masksToBounds = true
        addSubview(toolPanel)
        
        // 面板内横向排列三项
        toolRow.axis = .horizontal
        toolRow.spacing = 16
        toolRow.alignment = .center
        toolRow.distribution = .fillEqually
        toolRow.translatesAutoresizingMaskIntoConstraints = false
        toolPanel.addSubview(toolRow)
        
        // 相机 Tile
        cameraTile.axis = .vertical
        cameraTile.alignment = .center
        cameraTile.spacing = 6
        cameraTile.translatesAutoresizingMaskIntoConstraints = false
        cameraIcon.setImage(UIImage(systemName: "camera"), for: .normal)
        cameraIcon.tintColor = .label
        cameraIcon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        cameraIcon.heightAnchor.constraint(equalToConstant: 28).isActive = true
        cameraIcon.addTarget(self, action: #selector(imageButtonTapped), for: .touchUpInside)
        cameraLabel.text = "图片"
        cameraLabel.font = .systemFont(ofSize: 12)
        cameraLabel.textColor = .secondaryLabel
        cameraTile.addArrangedSubview(cameraIcon)
        cameraTile.addArrangedSubview(cameraLabel)
        
        // 思考 Tile
        thinkingTile.axis = .vertical
        thinkingTile.alignment = .center
        thinkingTile.spacing = 6
        thinkingTile.translatesAutoresizingMaskIntoConstraints = false
        thinkingIcon.setImage(UIImage(systemName: "brain"), for: .normal)
        thinkingIcon.tintColor = .label
        thinkingIcon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        thinkingIcon.heightAnchor.constraint(equalToConstant: 28).isActive = true
        thinkingIcon.addTarget(self, action: #selector(thinkingTapped), for: .touchUpInside)
        thinkingLabel.text = "思考"
        thinkingLabel.font = .systemFont(ofSize: 12)
        thinkingLabel.textColor = .secondaryLabel
        thinkingTile.addArrangedSubview(thinkingIcon)
        thinkingTile.addArrangedSubview(thinkingLabel)
        
        // 结合全文 Tile
        combineTile.axis = .vertical
        combineTile.alignment = .center
        combineTile.spacing = 6
        combineTile.translatesAutoresizingMaskIntoConstraints = false
        combineIcon.setImage(UIImage(systemName: "text.book.closed"), for: .normal)
        combineIcon.tintColor = .label
        combineIcon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        combineIcon.heightAnchor.constraint(equalToConstant: 28).isActive = true
        combineIcon.addTarget(self, action: #selector(combineTapped), for: .touchUpInside)
        combineLabel.text = "结合全文"
        combineLabel.font = .systemFont(ofSize: 12)
        combineLabel.textColor = .secondaryLabel
        combineTile.addArrangedSubview(combineIcon)
        combineTile.addArrangedSubview(combineLabel)
        
        toolRow.addArrangedSubview(cameraTile)
        toolRow.addArrangedSubview(thinkingTile)
        toolRow.addArrangedSubview(combineTile)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            toolPanel.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 8),
            toolPanel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            toolPanel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            toolRow.topAnchor.constraint(equalTo: toolPanel.topAnchor, constant: 10),
            toolRow.leadingAnchor.constraint(equalTo: toolPanel.leadingAnchor, constant: 10),
            toolRow.trailingAnchor.constraint(equalTo: toolPanel.trailingAnchor, constant: -10),
            toolRow.bottomAnchor.constraint(equalTo: toolPanel.bottomAnchor, constant: -10),
            toolPanel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        
        toolPanelHeightConstraint = toolPanel.heightAnchor.constraint(equalToConstant: 0)
        toolPanelHeightConstraint?.isActive = true
        
        updateSendButtonUI()
        updateTextViewHeight()
        NotificationCenter.default.addObserver(self, selector: #selector(onTextDidChange(_:)), name: UITextView.textDidChangeNotification, object: textView)
    }
    
    // MARK: - Actions
    @objc private func sendTapped() {
        switch mode {
        case .send:
            let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            onSend?(text)
            clearDraft()
            textView.text = ""
            updateTextViewHeight()
        case .stop:
            onStop?()
        }
    }
    
    @objc private func imageButtonTapped() {
        onImageButtonTapped?()
    }
    
    @objc private func plusTapped() {
        let show = (toolPanelHeightConstraint?.constant ?? 0) == 0
        toolPanelHeightConstraint?.constant = show ? 96 : 0
        UIView.animate(withDuration: 0.25) {
            self.layoutIfNeeded()
        }
    }
    
    @objc private func thinkingTapped() {
        onToggleThinking?()
    }
    
    @objc private func combineTapped() {
        onToggleCombine?()
    }
    
    // MARK: - UITextViewDelegate
    public func textViewDidChange(_ textView: UITextView) {
        updateTextViewHeight()
        saveDraftDelayed()
    }
    
    @objc private func onTextDidChange(_ note: Notification) {
        updateTextViewHeight()
        saveDraftDelayed()
    }
    
    private func updateTextViewHeight() {
        let fittingSize = CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
        let targetHeight = max(minInputHeight, textView.sizeThatFits(fittingSize).height)
        let clamped = min(targetHeight, maxInputHeight)
        textView.isScrollEnabled = targetHeight > maxInputHeight
        textViewHeightConstraint?.constant = clamped
        layoutIfNeeded()
    }
    
    private func updateSendButtonUI() {
        switch mode {
        case .send:
            sendButton.setTitle(NSLocalizedString("Send", comment: ""), for: .normal)
            sendButton.isEnabled = true
            imageButton.isEnabled = true
            plusButton.isEnabled = true
            textView.isEditable = true
        case .stop:
            sendButton.setTitle(NSLocalizedString("Stop", comment: ""), for: .normal)
            sendButton.isEnabled = true
            imageButton.isEnabled = false
            plusButton.isEnabled = false
            textView.isEditable = false
        }
    }
    
    public func setMode(_ mode: Mode) {
        self.mode = mode
    }
    
    public func setThinkingEnabled(_ enabled: Bool) {
        let color: UIColor = enabled ? .systemGreen : .label
        thinkingIcon.tintColor = enabled ? .white : .label
        thinkingTile.backgroundColor = enabled ? color.withAlphaComponent(0.2) : .clear
        thinkingTile.layer.cornerRadius = 8
    }
    
    public func setCombineEnabled(_ enabled: Bool) {
        let color: UIColor = enabled ? .systemBlue : .label
        combineIcon.tintColor = enabled ? .white : .label
        combineTile.backgroundColor = enabled ? color.withAlphaComponent(0.2) : .clear
        combineTile.layer.cornerRadius = 8
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 草稿逻辑
    private func setupDraftLogic() {
        // 可扩展草稿逻辑初始化
    }
    
    public func bind(to sessionID: UUID) {
        self.currentSessionID = sessionID
        if let draft = draftStorage.load(for: sessionID) {
            textView.text = draft.text
            updateTextViewHeight()
        }
    }
    
    private func saveDraftDelayed() {
        draftTimer?.invalidate()
        draftTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self, let sessionID = self.currentSessionID else { return }
            let draft = ChatDraft(sessionID: sessionID, text: self.textView.text, imageData: nil, updatedAt: Date())
            self.draftStorage.save(draft: draft)
        }
    }
    
    public func clearDraft() {
        guard let sessionID = currentSessionID else { return }
        draftStorage.clear(for: sessionID)
    }
}
