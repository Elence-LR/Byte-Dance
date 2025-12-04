//
//  MessageCell.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import UIKit

public final class MessageCell: UITableViewCell {
    public static let reuseId = "MessageCell"
    private let label = UILabel()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    // 假设您已经有了 Message 和 Role 的定义 (来自前一步)
    public func configure(with message: Message) {
        label.text = message.content
        switch message.role {
        case .user:
            label.textAlignment = .right
        case .assistant:
            label.textAlignment = .left
        case .system:
            label.textAlignment = .center
        }
    }
}
