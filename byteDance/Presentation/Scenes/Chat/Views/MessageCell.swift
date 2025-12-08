import UIKit
#if canImport(Down)
import Down
#endif

public final class MessageCell: UITableViewCell {
    public static let reuseId = "MessageCell"

    private let bubbleView = UIView()
    private let messageLabel = UILabel()

    private var leftLeading: NSLayoutConstraint!
    private var leftTrailingMax: NSLayoutConstraint!   // <=
    private var rightTrailing: NSLayoutConstraint!
    private var rightLeadingMin: NSLayoutConstraint!   // >=
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

        leftLeading = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        leftTrailingMax = bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -64)

        rightTrailing = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        rightLeadingMin = bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 64)

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

        leftLeading.isActive = true
        leftTrailingMax.isActive = true

        rightTrailing.isActive = false
        rightLeadingMin.isActive = false
        centerConstraint.isActive = false

    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        messageLabel.attributedText = nil
        
        leftLeading.isActive = true
        leftTrailingMax.isActive = true

        rightTrailing.isActive = false
        rightLeadingMin.isActive = false
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
            // 先全部关掉，防止复用短暂同时 active
            leftLeading.isActive = false
            leftTrailingMax.isActive = false
            rightTrailing.isActive = false
            rightLeadingMin.isActive = false
            centerConstraint.isActive = false

            // 右侧开启：trailing == -16 + leading >= 64
            rightTrailing.isActive = true
            rightLeadingMin.isActive = true


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
            leftLeading.isActive = false
            leftTrailingMax.isActive = false
            rightTrailing.isActive = false
            rightLeadingMin.isActive = false
            centerConstraint.isActive = false

            // 左侧开启：leading == 16 + trailing <= -64
            leftLeading.isActive = true
            leftTrailingMax.isActive = true


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
            leftLeading.isActive = false
            leftTrailingMax.isActive = false
            rightTrailing.isActive = false
            rightLeadingMin.isActive = false
            centerConstraint.isActive = true


            bubbleView.backgroundColor = .tertiarySystemFill
            messageLabel.textColor = .secondaryLabel
            messageLabel.textAlignment = .center
            messageLabel.text = message.content
        }
    }
}
