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
    
    private let regenerateButton = UIButton(type: .system)
    public var onRegenerate: ((UUID) -> Void)?


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
        
        regenerateButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        regenerateButton.addTarget(self, action: #selector(didTapRegenerate), for: .touchUpInside)
        regenerateButton.tintColor = .secondaryLabel
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
        
        onRegenerate = nil
        regenerateButton.isHidden = true
    }

    @objc private func didTapReasoning() {
        guard let id = currentMessageID else { return }
        onToggleReasoning?(id)
    }

    public func configure(with message: Message, isReasoningExpanded: Bool, showRegenerate: Bool) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        currentMessageID = message.id
        
        if message.role == .assistant, showRegenerate {
            let header = UIStackView()
            header.axis = .horizontal
            header.alignment = .center

            let spacer = UIView()
            header.addArrangedSubview(spacer)

            // 关键：同一个按钮反复被添加到不同 header 前，要先 remove
            regenerateButton.removeFromSuperview()
            regenerateButton.isHidden = false
            header.addArrangedSubview(regenerateButton)

            contentStack.addArrangedSubview(header)
        } else {
            regenerateButton.isHidden = true
            regenerateButton.removeFromSuperview() // 可选：避免残留在旧 header
        }
        
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

        // Attachments (图片) - 替换原有图片处理逻辑
        if let attachments = message.attachments {
            for att in attachments {
                if att.kind == .imageDataURL {
                    // 使用 setupImageView 方法创建图片视图
                    let imageView = setupImageView(for: att)
                    // 添加到内容栈
                    contentStack.addArrangedSubview(imageView)
                    // 加载图片（包含网络图片和Base64图片处理）
                    loadImage(for: imageView, from: att)
                    
                    // 确保图片视图在栈中正确布局
                    imageView.widthAnchor.constraint(lessThanOrEqualTo: contentStack.widthAnchor).isActive = true
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

        var idx = 0
        while idx < lines.count {
            let line = lines[idx]
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
                let header = line
                let nextIdx = idx + 1
                if nextIdx < lines.count {
                    let delim = lines[nextIdx]
                    let isDelim = delim.trimmingCharacters(in: .whitespaces).hasPrefix("|") && delim.contains("-")
                    if isDelim {
                        var rows: [String] = [header, delim]
                        var r = nextIdx + 1
                        while r < lines.count, lines[r].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                            rows.append(lines[r])
                            r += 1
                        }
                        let block = rows.joined(separator: "\n")
                        segments.append((.table, block, nil))
                        idx = r
                        continue
                    }
                }
                segments.append((.text, line, nil))
            } else if line.starts(with: "- ") || line.starts(with: "* ") {
                var rows: [String] = []
                var r = idx
                while r < lines.count, (lines[r].starts(with: "- ") || lines[r].starts(with: "* ")) {
                    rows.append(lines[r])
                    r += 1
                }
                segments.append((.ul, rows.joined(separator: "\n"), nil))
                idx = r
                continue
            } else if line.trimmingCharacters(in: .whitespaces).range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                var rows: [String] = []
                var r = idx
                while r < lines.count, lines[r].trimmingCharacters(in: .whitespaces).range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                    rows.append(lines[r])
                    r += 1
                }
                segments.append((.ol, rows.joined(separator: "\n"), nil))
                idx = r
                continue
            } else if line.starts(with: "---") {
                segments.append((.hr, line, nil))
            } else {
                segments.append((.text, line, nil))
            }
            idx += 1
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
            textView.attributedText = highlight(text: text, lang: lang)
        }
        private func highlight(text: String, lang: String?) -> NSAttributedString {
            let baseFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
            let m = NSMutableAttributedString(string: text, attributes: [
                .font: baseFont,
                .foregroundColor: textColor
            ])
            let lower = (lang ?? "").lowercased()
            func rx(_ pattern: String, _ color: UIColor) {
                guard let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
                let s = m.string
                let range = NSRange(location: 0, length: (s as NSString).length)
                re.enumerateMatches(in: s, options: [], range: range) { match, _, _ in
                    if let r = match?.range { m.addAttribute(.foregroundColor, value: color, range: r) }
                }
            }
            let strD = "\"(?:[^\\\"]|\\.)*\""
            let strS = "'(?:[^\\']|\\.)*'"
            let num  = "\\b\\d+(?:\\.\\d+)?\\b"
            if ["js","ts","javascript","typescript"].contains(lower) {
                rx("//.*", .systemGray)
                rx("/\\*[\\s\\S]*?\\*/", .systemGray)
                rx("\\b(let|const|var|function|return|if|else|for|while|import|from|export|class|extends|new|true|false|null|undefined|async|await|interface|type)\\b", .systemPink)
                rx(strD, .systemGreen)
                rx(strS, .systemGreen)
                rx(num, .systemOrange)
            } else if ["bash","sh","shell"].contains(lower) {
                rx("#.*", .systemGray)
                rx("\\b(cd|git|npm|node|export)\\b", .systemPink)
                rx(strD, .systemGreen)
                rx(strS, .systemGreen)
                rx(num, .systemOrange)
            } else if ["json"].contains(lower) {
                rx(strD, .systemGreen)
                rx("\\b(true|false|null)\\b", .systemPink)
                rx(num, .systemOrange)
            } else if ["env"].contains(lower) {
                rx("#.*", .systemGray)
                rx("\\b[A-Z_][A-Z0-9_]*\\b", .systemPink)
                rx(strD, .systemGreen)
                rx(strS, .systemGreen)
            } else {
                rx(strD, .systemGreen)
                rx(strS, .systemGreen)
                rx(num, .systemOrange)
            }
            return m
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
            guard lines.count >= 2 else { return }
            let header = splitRow(lines[0])
            let bodyStart = 2
            let rows = Array(lines.dropFirst(bodyStart)).map { splitRow($0) }
            addRow(header, bold: true)
            for r in rows { addRow(r, bold: false) }
            applyColors()
        }
        private func splitRow(_ s: String) -> [String] {
            var parts: [String] = []
            var current = ""
            for ch in s {
                if ch == "|" { parts.append(current.trimmingCharacters(in: .whitespaces)); current = "" }
                else { current.append(ch) }
            }
            parts.append(current.trimmingCharacters(in: .whitespaces))
            if !parts.isEmpty { parts.removeFirst() }
            if !parts.isEmpty { parts.removeLast() }
            return parts
        }
        private func addRow(_ cols: [String], bold: Bool) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.distribution = .fillEqually
            for c in cols {
                let l = UILabel()
                l.numberOfLines = 0
                l.font = bold ? .boldSystemFont(ofSize: 16) : .systemFont(ofSize: 16)
                #if canImport(Down)
                if let attr = try? Down(markdownString: c).toAttributedString() { l.attributedText = attr } else { l.text = c }
                #else
                l.text = c
                #endif
                row.addArrangedSubview(l)
            }
            stack.addArrangedSubview(row)
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
            var index = 1
            for line in lines {
                let content: String
                if ordered, let dot = line.firstIndex(of: ".") { content = String(line[line.index(after: dot)...]).trimmingCharacters(in: .whitespaces) }
                else { let drop = line.hasPrefix("- ") ? 2 : (line.hasPrefix("* ") ? 2 : 0); content = drop > 0 ? String(line.dropFirst(drop)).trimmingCharacters(in: .whitespaces) : line }
                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = 8
                row.alignment = .top
                let marker = UILabel()
                marker.font = .systemFont(ofSize: 16)
                marker.textColor = textColor
                marker.text = ordered ? "\(index)." : "•"
                index += 1
                let label = UILabel()
                label.numberOfLines = 0
                label.font = .systemFont(ofSize: 16)
                #if canImport(Down)
                if let attr = try? Down(markdownString: content).toAttributedString() { label.attributedText = attr } else { label.text = content }
                #else
                label.text = content
                #endif
                row.addArrangedSubview(marker)
                row.addArrangedSubview(label)
                marker.setContentHuggingPriority(.required, for: .horizontal)
                marker.setContentCompressionResistancePriority(.required, for: .horizontal)
                label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                stack.addArrangedSubview(row)
            }
            applyColors()
        }

        private func applyColors() {
            for row in stack.arrangedSubviews {
                if let l = row as? UILabel { l.textColor = textColor }
            }
        }

        required init?(coder: NSCoder) { super.init(coder: coder) }
    }
    
    @objc private func didTapRegenerate() {
        guard let id = currentMessageID else { return }
        onRegenerate?(id)
    }
}
