import Foundation

enum Splitter {
    /// Splits text into two halves, cutting at the paragraph or sentence break
    /// nearest the middle (or the nearest space if there's no good break).
    static func split(_ text: String) -> (String, String) {
        let chars = Array(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard chars.count > 1 else { return (String(chars), "") }
        let mid = chars.count / 2
        func nearest(within window: Int, _ isCut: (Int) -> Bool) -> Int? {
            var best: Int?
            for i in 1..<chars.count where isCut(i) {
                if abs(i - mid) <= window, best == nil || abs(i - mid) < abs(best! - mid) { best = i }
            }
            return best
        }

        let enders: Set<Character> = [".", "!", "?", "\u{2026}", "\""]
        // A paragraph break only if it's close to the middle; otherwise a sentence end.
        let n = chars.count
        let cut = nearest(within: n / 8) { chars[$0 - 1] == "\n" }
            ?? nearest(within: n / 4) { enders.contains(chars[$0 - 1]) && chars[$0].isWhitespace }
            ?? nearest(within: n) { chars[$0].isWhitespace }
            ?? mid

        let a = String(chars[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
        let b = String(chars[cut...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (a, b)
    }
}
