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
    
    public let imageButton = UIButton(type: .system)
    public let textView = UITextView()
    public let sendButton = UIButton(type: .system)
    public var onSend: ((String) -> Void)?
    public var onStop: (() -> Void)?
    public var onImageButtonTapped: (() -> Void)?
    
    private var mode: Mode = .send {
        didSet { updateSendButtonUI() }
    }
    
    private var textViewHeightConstraint: NSLayoutConstraint?
    private let minInputHeight: CGFloat = 36
    private let maxInputHeight: CGFloat = 120
    
    // 草稿功能新增属性
    private let draftStorage = DraftStorage()
    private var currentSessionID: UUID!
    private var draftTimer: Timer?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupDraftLogic() // 初始化草稿相关逻辑
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupDraftLogic() // 初始化草稿相关逻辑
    }

    private func setup() {
        imageButton.setTitle("📷", for: .normal)
        imageButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        imageButton.addTarget(self, action: #selector(imageButtonTapped), for: .touchUpInside)

        textView.isScrollEnabled = false
        textView.delegate = self
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)

        sendButton.setTitle(NSLocalizedString("Send", comment: ""), for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [imageButton, textView, sendButton])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        sendButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        sendButton.setContentHuggingPriority(.required, for: .horizontal)
        imageButton.setContentHuggingPriority(.required, for: .horizontal)
        imageButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        textView.translatesAutoresizingMaskIntoConstraints = false
        textViewHeightConstraint = textView.heightAnchor.constraint(equalToConstant: minInputHeight)
        textViewHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        
        updateSendButtonUI()
    }

    @objc private func sendTapped() {
        switch mode {
        case .send:
            let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            print("InputBar sendTapped length:", text.count)
            onSend?(text)
            clearDraft() // 发送成功后清空草稿
            textView.text = ""
            updateTextViewHeight()

        case .stop:
            print("InputBar stopTapped")
            onStop?()
            // 注意：不在这里清空文本，让取消后用户还能继续编辑/重发
        }
    }


    @objc private func imageButtonTapped() {
        onImageButtonTapped?()
    }

    public func textViewDidChange(_ textView: UITextView) {
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
            // 可选：停止时禁用图片按钮/输入框，这里 send 态恢复
            imageButton.isEnabled = true
            textView.isEditable = true

        case .stop:
            sendButton.setTitle(NSLocalizedString("Stop", comment: ""), for: .normal)
            sendButton.isEnabled = true
            // 可选：流式期间不让继续改输入/选图，避免并发请求
            imageButton.isEnabled = false
            textView.isEditable = false
        }
    }
    
    public func setMode(_ mode: Mode) {
        self.mode = mode
    }
    
    // 草稿功能新增逻辑
    private func setupDraftLogic() {
        // 草稿功能初始化（如果需要额外配置可在此添加）
    }
    
    // 绑定会话ID并加载草稿
    public func bind(to sessionID: UUID) {
        self.currentSessionID = sessionID
        // 加载该会话的草稿
        if let draft = draftStorage.load(for: sessionID) {
            textView.text = draft.text
            updateTextViewHeight() // 恢复草稿后调整输入框高度
        }
    }
    
    // 延迟保存草稿（避免频繁写入）
    private func saveDraftDelayed() {
        draftTimer?.invalidate()
        draftTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self, let sessionID = self.currentSessionID else { return }
            let draft = ChatDraft(
                sessionID: sessionID,
                text: self.textView.text,
                imageData: nil,
                updatedAt: Date()
            )
            self.draftStorage.save(draft: draft)
        }
    }
    
    // 清空当前会话的草稿
    public func clearDraft() {
        guard let sessionID = currentSessionID else { return }
        draftStorage.clear(for: sessionID)
    }
}
