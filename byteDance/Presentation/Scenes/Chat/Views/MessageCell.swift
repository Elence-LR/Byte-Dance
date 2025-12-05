import UIKit
#if canImport(Down)
import Down
#endif

public final class MessageCell: UITableViewCell {
    public static let reuseId = "MessageCell"

    private let bubbleView = UIView()
    private let messageLabel = UILabel()

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var centerConstraint: NSLayoutConstraint!

    private let maxBubbleWidthRatio: CGFloat = 0.78

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 18
        bubbleView.layer.masksToBounds = true
        contentView.addSubview(bubbleView)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textAlignment = .left
        bubbleView.addSubview(messageLabel)

        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        centerConstraint = bubbleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            // 最大宽度，避免整行铺满
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: maxBubbleWidthRatio),

            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
        ])

        // 默认 assistant（左）
        leadingConstraint.isActive = true
        trailingConstraint.isActive = false
        centerConstraint.isActive = false
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        messageLabel.attributedText = nil
        // 复用时把约束状态重置，避免 system 居中残留
        leadingConstraint.isActive = true
        trailingConstraint.isActive = false
        centerConstraint.isActive = false

        bubbleView.backgroundColor = .secondarySystemBackground
        messageLabel.textColor = .label
        messageLabel.textAlignment = .left
    }

    public func configure(with message: Message) {
        var attr: NSAttributedString?
        #if canImport(Down)
        attr = try? Down(markdownString: message.content).toAttributedString()
        #endif

        switch message.role {
        case .user:
            // 右侧气泡
            leadingConstraint.isActive = false
            centerConstraint.isActive = false
            trailingConstraint.isActive = true

            bubbleView.backgroundColor = .systemBlue
            messageLabel.textColor = .white
            messageLabel.textAlignment = .left
            if let a = attr {
                let m = NSMutableAttributedString(attributedString: a)
                m.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: 0, length: m.length))
                messageLabel.attributedText = m
            } else {
                messageLabel.text = message.content
            }

        case .assistant:
            // 左侧气泡
            trailingConstraint.isActive = false
            centerConstraint.isActive = false
            leadingConstraint.isActive = true

            bubbleView.backgroundColor = .secondarySystemBackground
            messageLabel.textColor = .label
            messageLabel.textAlignment = .left
            if let a = attr {
                messageLabel.attributedText = a
            } else {
                messageLabel.text = message.content
            }

        case .system:
            // 居中提示（比如“已清空对话/模型切换”）
            leadingConstraint.isActive = false
            trailingConstraint.isActive = false
            centerConstraint.isActive = true

            bubbleView.backgroundColor = .tertiarySystemFill
            messageLabel.textColor = .secondaryLabel
            messageLabel.textAlignment = .center
            messageLabel.text = message.content
        }
    }
}
