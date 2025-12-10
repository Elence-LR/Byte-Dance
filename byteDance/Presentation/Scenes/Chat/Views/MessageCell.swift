import UIKit
#if canImport(Down)
import Down
#endif

public final class MessageCell: UITableViewCell {
    public static let reuseId = "MessageCell"

    private let bubbleView = UIView()
    private let contentStack = UIStackView()

    // Reasoning UI
    private let reasoningContainer = UIView()
    private let reasoningStack = UIStackView()
    private let reasoningButton = UIButton(type: .system)
    private let reasoningLabel = UILabel()

    // 用于回调定位 message
    private var currentMessageID: UUID?
    public var onToggleReasoning: ((UUID) -> Void)?

    private var leftLeading: NSLayoutConstraint!
    private var leftTrailingMax: NSLayoutConstraint!
    private var rightTrailing: NSLayoutConstraint!
    private var rightLeadingMin: NSLayoutConstraint!
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

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 2
        bubbleView.addSubview(contentStack)

        leftLeading = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        leftTrailingMax = bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -64)

        rightTrailing = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        rightLeadingMin = bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 64)

        centerConstraint = bubbleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: maxBubbleWidthRatio),

            contentStack.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 4),
            contentStack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -4),
        ])

        // ✅ Reasoning UI
        reasoningContainer.translatesAutoresizingMaskIntoConstraints = false
        reasoningContainer.layer.cornerRadius = 10
        reasoningContainer.layer.masksToBounds = true
        reasoningContainer.backgroundColor = .tertiarySystemFill

        reasoningStack.translatesAutoresizingMaskIntoConstraints = false
        reasoningStack.axis = .vertical
        reasoningStack.spacing = 6
        reasoningContainer.addSubview(reasoningStack)

        NSLayoutConstraint.activate([
            reasoningStack.topAnchor.constraint(equalTo: reasoningContainer.topAnchor, constant: 8),
            reasoningStack.leadingAnchor.constraint(equalTo: reasoningContainer.leadingAnchor, constant: 10),
            reasoningStack.trailingAnchor.constraint(equalTo: reasoningContainer.trailingAnchor, constant: -10),
            reasoningStack.bottomAnchor.constraint(equalTo: reasoningContainer.bottomAnchor, constant: -8),
        ])

        reasoningButton.contentHorizontalAlignment = .leading
        reasoningButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        reasoningButton.setTitleColor(.secondaryLabel, for: .normal)
        reasoningButton.setTitle("思考过程", for: .normal)
        reasoningButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        reasoningButton.semanticContentAttribute = .forceRightToLeft
        reasoningButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
        reasoningButton.addTarget(self, action: #selector(didTapReasoning), for: .touchUpInside)

        reasoningLabel.numberOfLines = 0
        reasoningLabel.font = .systemFont(ofSize: 13)
        reasoningLabel.textColor = .secondaryLabel

        reasoningStack.addArrangedSubview(reasoningButton)
        reasoningStack.addArrangedSubview(reasoningLabel)

        reasoningContainer.isHidden = true
        reasoningLabel.isHidden = true

        leftLeading.isActive = true
        leftTrailingMax.isActive = true
        rightTrailing.isActive = false
        rightLeadingMin.isActive = false
        centerConstraint.isActive = false
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        currentMessageID = nil
        onToggleReasoning = nil
        reasoningContainer.isHidden = true
        reasoningLabel.isHidden = true
        reasoningLabel.text = nil

        leftLeading.isActive = true
        leftTrailingMax.isActive = true
        rightTrailing.isActive = false
        rightLeadingMin.isActive = false
        centerConstraint.isActive = false

        bubbleView.backgroundColor = .secondarySystemBackground
    }

    @objc private func didTapReasoning() {
        guard let id = currentMessageID else { return }
        onToggleReasoning?(id)
    }

    public func configure(with message: Message, isReasoningExpanded: Bool) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        currentMessageID = message.id

        // Reasoning
        if message.role == .assistant,
           let reasoning = message.reasoning,
           !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reasoningContainer.isHidden = false
            reasoningLabel.text = reasoning
            reasoningLabel.isHidden = !isReasoningExpanded
            let imgName = isReasoningExpanded ? "chevron.up" : "chevron.down"
            reasoningButton.setImage(UIImage(systemName: imgName), for: .normal)
            contentStack.addArrangedSubview(reasoningContainer)
        } else {
            reasoningContainer.isHidden = true
            reasoningLabel.isHidden = true
        }

        // Text segments
        let segments = parseSegments(from: message.content)
        #if canImport(Down)
        for seg in segments {
            switch seg.kind {
            case .text:
                let text = try? Down(markdownString: seg.content).toAttributedString()
                let label = UILabel()
                label.numberOfLines = 0
                label.font = .systemFont(ofSize: 18)
                if let t = text { label.attributedText = tightenAttributedString(t) } else { label.text = seg.content }
                contentStack.addArrangedSubview(label)
            case .code:
                let codeView = CodeBlockView()
                codeView.lang = seg.lang
                codeView.text = seg.content
                contentStack.addArrangedSubview(codeView)
            case .hr:
                let hr = HorizontalRuleView()
                contentStack.addArrangedSubview(hr)
            case .table:
                let tv = MarkdownTableView()
                tv.text = seg.content
                contentStack.addArrangedSubview(tv)
            case .ul:
                let lv = MarkdownListView()
                lv.ordered = false
                lv.items = seg.content
                contentStack.addArrangedSubview(lv)
            case .ol:
                let lv = MarkdownListView()
                lv.ordered = true
                lv.items = seg.content
                contentStack.addArrangedSubview(lv)
            }
        }
        #else
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 18)
        label.text = message.content
        contentStack.addArrangedSubview(label)
        #endif

        // Attachments (图片)
        if let attachments = message.attachments {
            for att in attachments {
                if att.kind == .imageDataURL {
                    let imageView = UIImageView()
                    imageView.contentMode = .scaleAspectFit
                    imageView.clipsToBounds = true
                    imageView.layer.cornerRadius = 8
                    if att.value.hasPrefix("data:image") {
                        // Base64
                        if let data = Data(base64Encoded: att.value.components(separatedBy: ",").last ?? ""),
                           let img = UIImage(data: data) {
                            imageView.image = img
                        }
                    } else if let url = URL(string: att.value) {
                        // 网络 URL
                        // 可以使用 SDWebImage / URLSession
                        URLSession.shared.dataTask(with: url) { data, _, _ in
                            if let d = data, let img = UIImage(data: d) {
                                DispatchQueue.main.async { imageView.image = img }
                            }
                        }.resume()
                    }
                    contentStack.addArrangedSubview(imageView)
                }
            }
        }

        // Layout constraints
        NSLayoutConstraint.deactivate([leftLeading, leftTrailingMax, rightTrailing, rightLeadingMin, centerConstraint])

        switch message.role {
        case .user:
            leftLeading.isActive = false
            leftTrailingMax.isActive = false
            rightTrailing.isActive = true
            rightLeadingMin.isActive = true
            bubbleView.backgroundColor = .systemBlue
            applyTextColor(.white)

        case .assistant:
            leftLeading.isActive = true
            leftTrailingMax.isActive = true
            bubbleView.backgroundColor = .secondarySystemBackground
            applyTextColor(.label)
            reasoningContainer.backgroundColor = UIColor.tertiarySystemFill
            reasoningLabel.textColor = .secondaryLabel

        case .system:
            centerConstraint.isActive = true
            bubbleView.backgroundColor = .tertiarySystemFill
            applyTextColor(.secondaryLabel)
        }
    }

    private func applyTextColor(_ color: UIColor) {
        for v in contentStack.arrangedSubviews {
            if let l = v as? UILabel {
                l.textColor = color
            } else if let cb = v as? CodeBlockView {
                cb.textColor = color
            } else if let hr = v as? HorizontalRuleView {
                hr.backgroundColor = color.withAlphaComponent(0.6)
            } else if let tv = v as? MarkdownTableView {
                tv.textColor = color
            } else if let lv = v as? MarkdownListView {
                lv.textColor = color
            }
        }
    }

    // MARK: - Segment parsing
    private func parseSegments(from text: String) -> [(kind: SegmentKind, content: String, lang: String?)] {
        // 简单示例实现，可根据原代码增强
        var segments: [(SegmentKind, String, String?)] = []
        let lines = text.components(separatedBy: "\n")
        var buffer = ""
        var codeLang: String? = nil
        var inCode = false

        for line in lines {
            if line.starts(with: "```") {
                if inCode {
                    segments.append((.code, buffer, codeLang))
                    buffer = ""
                    codeLang = nil
                    inCode = false
                } else {
                    inCode = true
                    codeLang = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                }
            } else if inCode {
                buffer += line + "\n"
            } else if line.starts(with: "|") {
                segments.append((.table, line, nil))
            } else if line.starts(with: "- ") {
                segments.append((.ul, line, nil))
            } else if line.starts(with: "1. ") {
                segments.append((.ol, line, nil))
            } else if line.starts(with: "---") {
                segments.append((.hr, line, nil))
            } else {
                segments.append((.text, line, nil))
            }
        }

        if inCode {
            segments.append((.code, buffer, codeLang))
        }

        return segments
    }

    private enum SegmentKind { case text, code, hr, table, ul, ol }

    private func tightenAttributedString(_ source: NSAttributedString) -> NSAttributedString { return source }

    // MARK: - Nested Private Classes
    private final class CodeBlockView: UIView {
        private let textView = UITextView()
        var lang: String?
        var text: String = "" { didSet { render() } }
        var textColor: UIColor = .label { didSet { render() } }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.backgroundColor = .clear
            textView.textContainerInset = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
            addSubview(textView)
            textView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textView.topAnchor.constraint(equalTo: topAnchor),
                textView.leadingAnchor.constraint(equalTo: leadingAnchor),
                textView.trailingAnchor.constraint(equalTo: trailingAnchor),
                textView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        private func render() {
            textView.attributedText = NSAttributedString(string: text, attributes: [.foregroundColor: textColor, .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)])
        }

        required init?(coder: NSCoder) { super.init(coder: coder) }
    }

    private final class HorizontalRuleView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            translatesAutoresizingMaskIntoConstraints = false
            heightAnchor.constraint(equalToConstant: 1).isActive = true
            backgroundColor = .separator
        }
        required init?(coder: NSCoder) { super.init(coder: coder) }
    }

    private final class MarkdownTableView: UIView {
        private let stack = UIStackView()
        var textColor: UIColor = .label { didSet { applyColors() } }
        var text: String = "" { didSet { render() } }

        override init(frame: CGRect) {
            super.init(frame: frame)
            stack.axis = .vertical
            stack.spacing = 4
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
            ])
            layer.cornerRadius = 8
        }

        private func render() {
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            let lines = text.components(separatedBy: "\n")
            for line in lines {
                let label = UILabel()
                label.font = .systemFont(ofSize: 14)
                label.numberOfLines = 0
                label.text = line
                label.textColor = textColor
                stack.addArrangedSubview(label)
            }
        }

        private func applyColors() {
            for row in stack.arrangedSubviews {
                if let l = row as? UILabel { l.textColor = textColor }
            }
        }

        required init?(coder: NSCoder) { super.init(coder: coder) }
    }

    private final class MarkdownListView: UIView {
        private let stack = UIStackView()
        var ordered: Bool = false { didSet { render() } }
        var textColor: UIColor = .label { didSet { applyColors() } }
        var items: String = "" { didSet { render() } }

        override init(frame: CGRect) {
            super.init(frame: frame)
            stack.axis = .vertical
            stack.spacing = 4
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
            ])
            layer.cornerRadius = 8
        }

        private func render() {
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            let lines = items.components(separatedBy: "\n")
            for (idx, line) in lines.enumerated() {
                let label = UILabel()
                label.font = .systemFont(ofSize: 14)
                label.numberOfLines = 0
                label.textColor = textColor
                label.text = ordered ? "\(idx+1). \(line)" : "• \(line)"
                stack.addArrangedSubview(label)
            }
        }

        private func applyColors() {
            for row in stack.arrangedSubviews {
                if let l = row as? UILabel { l.textColor = textColor }
            }
        }

        required init?(coder: NSCoder) { super.init(coder: coder) }
    }
}
