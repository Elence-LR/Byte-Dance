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
        
        // ✅ Reasoning UI setup (insert into setup())
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

        // 默认隐藏（无 reasoning 时不显示；收起时隐藏正文）
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

        if message.role == .assistant,
           let reasoning = message.reasoning,
           !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

            reasoningContainer.isHidden = false
            reasoningLabel.text = reasoning
            reasoningLabel.isHidden = !isReasoningExpanded

            let imgName = isReasoningExpanded ? "chevron.up" : "chevron.down"
            reasoningButton.setImage(UIImage(systemName: imgName), for: .normal)

            // 放在气泡内容最上面
            contentStack.addArrangedSubview(reasoningContainer)
        } else {
            reasoningContainer.isHidden = true
            reasoningLabel.isHidden = true
        }
        
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
        
        // 先全部关掉（用 deactivate 避免瞬间同时 active）
        NSLayoutConstraint.deactivate([leftLeading, leftTrailingMax, rightTrailing, rightLeadingMin, centerConstraint])

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

            NSLayoutConstraint.activate([rightTrailing, rightLeadingMin])

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
                } else if let hr = v as? HorizontalRuleView {
                    hr.backgroundColor = UIColor.white.withAlphaComponent(0.6)
                } else if let tv = v as? MarkdownTableView {
                    tv.textColor = .white
                    tv.backgroundColor = UIColor.white.withAlphaComponent(0.15)
                } else if let lv = v as? MarkdownListView {
                    lv.textColor = .white
                    lv.backgroundColor = .clear
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
            
            NSLayoutConstraint.activate([leftLeading, leftTrailingMax])

            bubbleView.backgroundColor = .secondarySystemBackground
            contentStack.arrangedSubviews.forEach { v in
                if let l = v as? UILabel {
                    l.textColor = .label
                } else if let cb = v as? CodeBlockView {
                    cb.textColor = .label
                    cb.backgroundColor = UIColor.tertiarySystemFill
                } else if let hr = v as? HorizontalRuleView {
                    hr.backgroundColor = .separator
                } else if let tv = v as? MarkdownTableView {
                    tv.textColor = .label
                    tv.backgroundColor = UIColor.tertiarySystemFill
                } else if let lv = v as? MarkdownListView {
                    lv.textColor = .label
                    lv.backgroundColor = .clear
                }
            }
            
            reasoningContainer.backgroundColor = UIColor.tertiarySystemFill
            reasoningLabel.textColor = .secondaryLabel

        case .system:
            // 居中提示（比如“已清空对话/模型切换”）
            leftLeading.isActive = false
            leftTrailingMax.isActive = false
            rightTrailing.isActive = false
            rightLeadingMin.isActive = false
            centerConstraint.isActive = true
            
            NSLayoutConstraint.activate([centerConstraint])

            bubbleView.backgroundColor = .tertiarySystemFill
            contentStack.arrangedSubviews.forEach { v in
                if let l = v as? UILabel {
                    l.textColor = .secondaryLabel
                    l.textAlignment = .center
                } else if let cb = v as? CodeBlockView {
                    cb.textColor = .secondaryLabel
                    cb.backgroundColor = UIColor.tertiarySystemFill
                } else if let hr = v as? HorizontalRuleView {
                    hr.backgroundColor = .separator
                } else if let tv = v as? MarkdownTableView {
                    tv.textColor = .secondaryLabel
                    tv.backgroundColor = UIColor.tertiarySystemFill
                } else if let lv = v as? MarkdownListView {
                    lv.textColor = .secondaryLabel
                    lv.backgroundColor = .clear
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
            if text[i] == "|" {
                let atLineStart = (i == text.startIndex) || text[text.index(before: i)] == "\n"
                if atLineStart {
                    var headerEnd = i
                    while headerEnd < text.endIndex, text[headerEnd] != "\n" { headerEnd = text.index(after: headerEnd) }
                    let headerLine = String(text[i..<headerEnd]).trimmingCharacters(in: .whitespaces)
                    let delimStart = headerEnd < text.endIndex ? text.index(after: headerEnd) : headerEnd
                    var delimEnd = delimStart
                    while delimEnd < text.endIndex, text[delimEnd] != "\n" { delimEnd = text.index(after: delimEnd) }
                    let delimLine = delimStart < text.endIndex ? String(text[delimStart..<delimEnd]).trimmingCharacters(in: .whitespaces) : ""
                    let isDelimiter = delimLine.hasPrefix("|") && delimLine.contains("-")
                    if isDelimiter {
                        var rowsEnd = delimEnd
                        var rows: [String] = [headerLine, delimLine]
                        while rowsEnd < text.endIndex {
                            let rowStart = rowsEnd < text.endIndex ? text.index(after: rowsEnd) : rowsEnd
                            var rowEnd = rowStart
                            while rowEnd < text.endIndex, text[rowEnd] != "\n" { rowEnd = text.index(after: rowEnd) }
                            if rowStart >= text.endIndex { break }
                            let rowLine = String(text[rowStart..<rowEnd]).trimmingCharacters(in: .whitespaces)
                            if rowLine.hasPrefix("|") { rows.append(rowLine); rowsEnd = rowEnd } else { break }
                        }
                        if !buffer.isEmpty { result.append((.text, buffer, nil)); buffer = "" }
                        let block = rows.joined(separator: "\n")
                        result.append((.table, block, nil))
                        i = rowsEnd
                        if i < text.endIndex { i = text.index(after: i) }
                        continue
                    }
                }
            }
            if text[i] == "-" {
                let atLineStart = (i == text.startIndex) || text[text.index(before: i)] == "\n"
                if atLineStart {
                    var lineEnd = i
                    while lineEnd < text.endIndex, text[lineEnd] != "\n" { lineEnd = text.index(after: lineEnd) }
                    let rawLine = String(text[i..<lineEnd]).trimmingCharacters(in: .whitespaces)
                    if rawLine == "---" {
                        if !buffer.isEmpty { result.append((.text, buffer, nil)); buffer = "" }
                        result.append((.hr, "", nil))
                        i = lineEnd
                        if i < text.endIndex { i = text.index(after: i) }
                        continue
                    }
                    if rawLine.hasPrefix("- ") || rawLine.hasPrefix("* ") {
                        var rowsEnd = lineEnd
                        var rows: [String] = []
                        var cursor = i
                        while cursor < text.endIndex {
                            var rEnd = cursor
                            while rEnd < text.endIndex, text[rEnd] != "\n" { rEnd = text.index(after: rEnd) }
                            let rLine = String(text[cursor..<rEnd]).trimmingCharacters(in: .whitespaces)
                            if rLine.hasPrefix("- ") || rLine.hasPrefix("* ") {
                                rows.append(rLine)
                                rowsEnd = rEnd
                                cursor = rEnd < text.endIndex ? text.index(after: rEnd) : rEnd
                            } else { break }
                        }
                        if !rows.isEmpty {
                            if !buffer.isEmpty { result.append((.text, buffer, nil)); buffer = "" }
                            let block = rows.joined(separator: "\n")
                            result.append((.ul, block, nil))
                            i = rowsEnd
                            if i < text.endIndex { i = text.index(after: i) }
                            continue
                        }
                    }
                }
            }
            if text[i].isNumber {
                let atLineStart = (i == text.startIndex) || text[text.index(before: i)] == "\n"
                if atLineStart {
                    var lineEnd = i
                    while lineEnd < text.endIndex, text[lineEnd] != "\n" { lineEnd = text.index(after: lineEnd) }
                    let rawLine = String(text[i..<lineEnd]).trimmingCharacters(in: .whitespaces)
                    if let dot = rawLine.firstIndex(of: "."), dot > rawLine.startIndex {
                        var rowsEnd = lineEnd
                        var rows: [String] = []
                        var cursor = i
                        while cursor < text.endIndex {
                            var rEnd = cursor
                            while rEnd < text.endIndex, text[rEnd] != "\n" { rEnd = text.index(after: rEnd) }
                            let rLine = String(text[cursor..<rEnd]).trimmingCharacters(in: .whitespaces)
                            if let d = rLine.firstIndex(of: "."), d > rLine.startIndex {
                                rows.append(rLine)
                                rowsEnd = rEnd
                                cursor = rEnd < text.endIndex ? text.index(after: rEnd) : rEnd
                            } else { break }
                        }
                        if !rows.isEmpty {
                            if !buffer.isEmpty { result.append((.text, buffer, nil)); buffer = "" }
                            let block = rows.joined(separator: "\n")
                            result.append((.ol, block, nil))
                            i = rowsEnd
                            if i < text.endIndex { i = text.index(after: i) }
                            continue
                        }
                    }
                }
            }
            buffer.append(text[i])
            i = text.index(after: i)
        }
        if !buffer.isEmpty { result.append((.text, buffer, nil)) }
        return result
    }

    private enum SegmentKind { case text, code, hr, table, ul, ol }

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
        var lang: String?
        var text: String = "" { didSet { render() } }
        var textColor: UIColor = .label { didSet { render() } }
        override init(frame: CGRect) {
            super.init(frame: frame)
            // no container styling for lists
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
            let attributed = highlight(text: text, lang: lang)
            textView.attributedText = attributed
        }
        private func highlight(text: String, lang: String?) -> NSAttributedString {
            let baseFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
            let m = NSMutableAttributedString(string: text, attributes: [
                .font: baseFont,
                .foregroundColor: textColor
            ])
            let lower = (lang ?? "").lowercased()
            if ["js","ts","javascript","typescript"].contains(lower) {
                applyRegex(m, pattern: "//.*", color: .systemGray)
                applyRegex(m, pattern: "/\\*[\\s\\S]*?\\*/", color: .systemGray)
                applyRegex(m, pattern: "\\b(let|const|var|function|return|if|else|for|while|import|from|export|class|extends|new|true|false|null|undefined|async|await|interface|type)\\b", color: .systemPink)
                applyRegex(m, pattern: "\"(?:\\\\.|[^\"\\])*\"|'(?:\\\\.|[^'\\])*'", color: .systemGreen)
                applyRegex(m, pattern: "\\b[0-9]+(?:\\.[0-9]+)?\\b", color: .systemOrange)
            } else if ["bash","sh","shell"].contains(lower) {
                applyRegex(m, pattern: "#.*", color: .systemGray)
                applyRegex(m, pattern: "\\b(cd|git|npm|node|export)\\b", color: .systemPink)
                applyRegex(m, pattern: "\"(?:\\\\.|[^\"\\])*\"|'(?:\\\\.|[^'\\])*'", color: .systemGreen)
                applyRegex(m, pattern: "\\b[0-9]+(?:\\.[0-9]+)?\\b", color: .systemOrange)
            } else if ["json"].contains(lower) {
                applyRegex(m, pattern: "\"(?:\\\\.|[^\"\\])*\"", color: .systemGreen)
                applyRegex(m, pattern: "\\b(true|false|null)\\b", color: .systemPink)
                applyRegex(m, pattern: "\\b[0-9]+(?:\\.[0-9]+)?\\b", color: .systemOrange)
            } else if ["env"].contains(lower) {
                applyRegex(m, pattern: "#.*", color: .systemGray)
                applyRegex(m, pattern: "\\b[A-Z_][A-Z0-9_]*\\b", color: .systemPink)
                applyRegex(m, pattern: "\"(?:\\\\.|[^\"\\])*\"|'(?:\\\\.|[^'\\])*'", color: .systemGreen)
            } else {
                applyRegex(m, pattern: "\"(?:\\\\.|[^\"\\])*\"|'(?:\\\\.|[^'\\])*'", color: .systemGreen)
                applyRegex(m, pattern: "\\b[0-9]+(?:\\.[0-9]+)?\\b", color: .systemOrange)
            }
            return m
        }
        private func applyRegex(_ m: NSMutableAttributedString, pattern: String, color: UIColor) {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
            let text = m.string
            let range = NSRange(location: 0, length: (text as NSString).length)
            re.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let r = match?.range { m.addAttribute(.foregroundColor, value: color, range: r) }
            }
        }
        required init?(coder: NSCoder) { super.init(coder: coder) }
    }
    private final class HorizontalRuleView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: 1)
            ])
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
            let lines = text.split(separator: "\n").map { String($0) }
            guard lines.count >= 2 else { return }
            let header = splitRow(lines[0])
            let bodyStart = 2
            let rows = lines.dropFirst(bodyStart).map { splitRow($0) }
            addRow(header, bold: true)
            for r in rows { addRow(r, bold: false) }
            applyColors()
        }
        private func splitRow(_ s: String) -> [String] {
            var parts: [String] = []
            var current = ""
            for ch in s {
                if ch == "|" {
                    parts.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                } else { current.append(ch) }
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
                l.text = c
                row.addArrangedSubview(l)
            }
            stack.addArrangedSubview(row)
        }
        private func applyColors() {
            for v in stack.arrangedSubviews {
                if let row = v as? UIStackView {
                    for cell in row.arrangedSubviews {
                        if let l = cell as? UILabel { l.textColor = textColor }
                    }
                }
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
            let lines = items.split(separator: "\n").map { String($0) }
            var index = 1
            for line in lines {
                let content: String
                if ordered, let dot = line.firstIndex(of: ".") {
                    content = String(line[line.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    let drop = line.hasPrefix("- ") ? 2 : (line.hasPrefix("* ") ? 2 : 0)
                    content = drop > 0 ? String(line.dropFirst(drop)).trimmingCharacters(in: .whitespaces) : line
                }
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
                if let attr = try? Down(markdownString: content).toAttributedString() {
                    label.attributedText = attr
                } else { label.text = content }
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
            for v in stack.arrangedSubviews {
                if let row = v as? UIStackView {
                    for cell in row.arrangedSubviews {
                        if let l = cell as? UILabel { l.textColor = textColor }
                    }
                }
            }
        }
        required init?(coder: NSCoder) { super.init(coder: coder) }
    }
}
