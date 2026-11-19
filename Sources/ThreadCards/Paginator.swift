import UIKit

/// Breaks a post that's too long for one card into several cards, keeping the
/// text size. Breaks go at sentence ends (paragraphs kept together where
/// possible); a single sentence longer than a card is broken between words.
enum Paginator {
    private static var font: UIFont { .systemFont(ofSize: 15.5) }
    private static let textWidth = Look.cardWidth - 21   // card minus its side padding
    private static let lineGap: CGFloat = 2.2            // lineSpacing on the card
    private static let paragraphGap: CGFloat = 6
    /// Text height that fits on a 1080 x 1920 card with the header, pill and stats.
    private static let maxHeight: CGFloat = 455

    static func pages(_ text: String) -> [String] {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return [] }
        if fits(t) { return [t] }

        var pages: [String] = []
        var current = ""
        for token in tokens(t) {
            let candidate = join(current, token)
            if fits(candidate) {
                current = candidate
                continue
            }
            if !current.isEmpty {
                pages.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            }
            let alone = join("", token)
            if fits(alone) {
                current = alone
            } else {
                // One sentence longer than a whole card: fill cards word by word.
                for word in token.text.split(separator: " ", omittingEmptySubsequences: true) {
                    let next = current.isEmpty ? String(word) : current + " " + word
                    if fits(next) || current.isEmpty {
                        current = next
                    } else {
                        pages.append(current)
                        current = String(word)
                    }
                }
            }
        }
        let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { pages.append(last) }
        return pages
    }

    // MARK: - Pieces

    private struct Token {
        var text: String
        var newParagraph: Bool
    }

    /// Sentences, each marked if it starts a new paragraph.
    private static func tokens(_ text: String) -> [Token] {
        var out: [Token] = []
        let paragraphs = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let re = try? NSRegularExpression(pattern: #"[^.!?…]+(?:[.!?…]+["”’)\]]*)?\s*"#)
        for para in paragraphs {
            let ns = para as NSString
            let matches = re?.matches(in: para, range: NSRange(location: 0, length: ns.length)) ?? []
            var sentences = matches.map { ns.substring(with: $0.range) }
            if sentences.joined() != para { sentences = [para] } // safety: never lose text
            for (i, s) in sentences.enumerated() where !s.trimmingCharacters(in: .whitespaces).isEmpty {
                out.append(Token(text: s, newParagraph: i == 0))
            }
        }
        return out
    }

    private static func join(_ current: String, _ token: Token) -> String {
        if current.isEmpty { return token.text }
        if token.newParagraph { return current.trimmingCharacters(in: .whitespaces) + "\n" + token.text }
        return current + token.text
    }

    private static func fits(_ text: String) -> Bool {
        height(text.trimmingCharacters(in: .whitespacesAndNewlines)) <= maxHeight
    }

    /// Height of the text as the card lays it out.
    private static func height(_ text: String) -> CGFloat {
        let paras = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var total: CGFloat = 0
        for p in paras {
            let h = (p as NSString).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font], context: nil).height
            let lines = max(1, (h / font.lineHeight).rounded())
            total += lines * font.lineHeight + (lines - 1) * lineGap
        }
        total += CGFloat(max(0, paras.count - 1)) * paragraphGap
        return total
    }
}
