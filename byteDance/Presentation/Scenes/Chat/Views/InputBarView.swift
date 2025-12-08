//
//  InputBarView.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import UIKit

public final class InputBarView: UIView, UITextViewDelegate {
    public let imageButton = UIButton(type: .system)
    public let textView = UITextView()
    public let sendButton = UIButton(type: .system)
    public var onSend: ((String) -> Void)?
    public var onImageButtonTapped: (() -> Void)?

    private var textViewHeightConstraint: NSLayoutConstraint?
    private let minInputHeight: CGFloat = 36
    private let maxInputHeight: CGFloat = 120

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
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
    }

    @objc private func sendTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSend?(text)
        textView.text = ""
        updateTextViewHeight()
    }

    @objc private func imageButtonTapped() {
        onImageButtonTapped?()
    }

    public func textViewDidChange(_ textView: UITextView) {
        updateTextViewHeight()
    }

    private func updateTextViewHeight() {
        let fittingSize = CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
        let targetHeight = max(minInputHeight, textView.sizeThatFits(fittingSize).height)
        let clamped = min(targetHeight, maxInputHeight)
        textView.isScrollEnabled = targetHeight > maxInputHeight
        textViewHeightConstraint?.constant = clamped
        layoutIfNeeded()
    }
}
