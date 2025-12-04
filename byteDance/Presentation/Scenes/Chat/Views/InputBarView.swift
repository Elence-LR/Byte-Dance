//
//  InputBarView.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import UIKit

public final class InputBarView: UIView {
    public let textField = UITextField()
    public let sendButton = UIButton(type: .system)
    public var onSend: ((String) -> Void)?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        textField.borderStyle = .roundedRect
        sendButton.setTitle(NSLocalizedString("Send", comment: ""), for: .normal)
        let stack = UIStackView(arrangedSubviews: [textField, sendButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    }

    @objc private func sendTapped() {
        guard let text = textField.text, !text.isEmpty else { return }
        onSend?(text)
        textField.text = ""
    }
}
