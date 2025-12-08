import UIKit
#if canImport(Down)
import Down
#endif

public final class MessageCell: UITableViewCell {
    public static let reuseId = "MessageCell"

    private let bubbleView = UIView()
    private let contentStack = UIStackView()

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

            // 最大宽度，避免整行铺满
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: maxBubbleWidthRatio),

            contentStack.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 4),
            contentStack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -4),
        ])

        leftLeading.isActive = true
        leftTrailingMax.isActive = true

        rightTrailing.isActive = false
        rightLeadingMin.isActive = false
        centerConstraint.isActive = false

    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        leftLeading.isActive = true
        leftTrailingMax.isActive = true

        rightTrailing.isActive = false
        rightLeadingMin.isActive = false
        centerConstraint.isActive = false


        bubbleView.backgroundColor = .secondarySystemBackground
        
    }

    public func configure(with message: Message) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
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
                codeView.text = seg.content
                contentStack.addArrangedSubview(codeView)
            }
        }
        #else
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 18)
        label.text = message.content
        contentStack.addArrangedSubview(label)
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
            contentStack.arrangedSubviews.forEach { v in
                if let l = v as? UILabel {
                    l.textColor = .white
                    if let a = l.attributedText {
                        let scaled = scaleAttributedString(a, factor: 1.15)
                        let centered = centerAttributedString(scaled)
                        let m = NSMutableAttributedString(attributedString: centered)
                        m.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: 0, length: m.length))
                        l.attributedText = m
                        l.textAlignment = .center
                    } else {
                        l.font = .systemFont(ofSize: 20)
                        l.textAlignment = .center
                    }
                } else if let cb = v as? CodeBlockView {
                    cb.textColor = .white
                    cb.backgroundColor = UIColor.white.withAlphaComponent(0.15)
                }
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
            contentStack.arrangedSubviews.forEach { v in
                if let l = v as? UILabel {
                    l.textColor = .label
                } else if let cb = v as? CodeBlockView {
                    cb.textColor = .label
                    cb.backgroundColor = UIColor.tertiarySystemFill
                }
            }

        case .system:
            // 居中提示（比如“已清空对话/模型切换”）
            leftLeading.isActive = false
            leftTrailingMax.isActive = false
            rightTrailing.isActive = false
            rightLeadingMin.isActive = false
            centerConstraint.isActive = true


            bubbleView.backgroundColor = .tertiarySystemFill
            contentStack.arrangedSubviews.forEach { v in
                if let l = v as? UILabel {
                    l.textColor = .secondaryLabel
                    l.textAlignment = .center
                } else if let cb = v as? CodeBlockView {
                    cb.textColor = .secondaryLabel
                    cb.backgroundColor = UIColor.tertiarySystemFill
                }
            }
        }
    }

    private func parseSegments(from text: String) -> [(kind: SegmentKind, content: String, lang: String?)] {
        var result: [(SegmentKind, String, String?)] = []
        var i = text.startIndex
        var buffer = ""
        while i < text.endIndex {
            if text[i] == "`" {
                let next = text.index(i, offsetBy: 3, limitedBy: text.endIndex) ?? text.endIndex
                let fence = text[i..<min(next, text.endIndex)]
                if fence == "```" {
                    let langStart = next
                    var lineEnd = langStart
                    while lineEnd < text.endIndex, text[lineEnd] != "\n" { lineEnd = text.index(after: lineEnd) }
                    let lang = langStart < lineEnd ? String(text[langStart..<lineEnd]).trimmingCharacters(in: .whitespaces) : nil
                    let codeStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : lineEnd
                    var search = codeStart
                    var foundEnd: String.Index?
                    while search < text.endIndex {
                        if text[search] == "`" {
                            let n = text.index(search, offsetBy: 3, limitedBy: text.endIndex) ?? text.endIndex
                            if text[search..<min(n, text.endIndex)] == "```" { foundEnd = search; break }
                        }
                        search = text.index(after: search)
                    }
                    if let end = foundEnd {
                        if !buffer.isEmpty { result.append((.text, buffer, nil)); buffer = "" }
                        let code = String(text[codeStart..<end])
                        result.append((.code, code, lang))
                        i = min(text.index(end, offsetBy: 3), text.endIndex)
                        continue
                    }
                }
            }
            buffer.append(text[i])
            i = text.index(after: i)
        }
        if !buffer.isEmpty { result.append((.text, buffer, nil)) }
        return result
    }

    private enum SegmentKind { case text, code }

    private func tightenAttributedString(_ source: NSAttributedString) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: source)
        m.enumerateAttributes(in: NSRange(location: 0, length: m.length), options: []) { attrs, range, _ in
            if let ps = attrs[.paragraphStyle] as? NSParagraphStyle {
                let newPS = ps.mutableCopy() as! NSMutableParagraphStyle
                newPS.lineSpacing = max(0, min(ps.lineSpacing, 1))
                newPS.paragraphSpacing = max(0, min(ps.paragraphSpacing, 2))
                m.addAttribute(.paragraphStyle, value: newPS, range: range)
            }
        }
        return m
    }

    private func scaleAttributedString(_ source: NSAttributedString, factor: CGFloat) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: source)
        m.enumerateAttributes(in: NSRange(location: 0, length: m.length), options: []) { attrs, range, _ in
            if let font = attrs[.font] as? UIFont {
                let newFont = UIFont(descriptor: font.fontDescriptor, size: font.pointSize * factor)
                m.addAttribute(.font, value: newFont, range: range)
            }
        }
        return m
    }

    private func centerAttributedString(_ source: NSAttributedString) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: source)
        m.addAttribute(.paragraphStyle, value: {
            let ps = NSMutableParagraphStyle()
            ps.alignment = .center
            return ps
        }(), range: NSRange(location: 0, length: m.length))
        return m
    }

    private final class CodeBlockView: UIView {
        private let textView = UITextView()
        var text: String = "" { didSet { textView.text = text } }
        var textColor: UIColor = .label { didSet { textView.textColor = textColor } }
        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.cornerRadius = 8
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.backgroundColor = .clear
            textView.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
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
        required init?(coder: NSCoder) { super.init(coder: coder) }
    }
}
