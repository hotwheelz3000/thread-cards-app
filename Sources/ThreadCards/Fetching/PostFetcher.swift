import Foundation

/// What could be read from a Threads post page. Anything nil wasn't found.
struct FetchedPost: Sendable {
    var username: String?
    var text: String?
    var avatarURL: String?
    var verified: Bool?
    var takenAt: Date?
    // Display-ready counts ("531", "1.2K").
    var likes: String?
    var replies: String?
    var reposts: String?
    var shares: String?

    var missingDetails: Bool {
        username == nil || verified == nil || takenAt == nil || likes == nil
    }
}

enum FetchError: LocalizedError {
    case badLink
    case nothingFound

    var errorDescription: String? {
        switch self {
        case .badLink: return "That doesn't look like a Threads post link."
        case .nothingFound: return "Couldn't read the post. Type or paste the text below."
        }
    }
}

enum PostFetcher {
    private static let userAgents = [
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
        "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
    ]

    /// Pulls the first http(s) link out of whatever was pasted and drops the query string.
    static func postURL(from input: String) -> URL? {
        guard let start = input.range(of: "http") else { return nil }
        var s = String(input[start.lowerBound...])
        if let end = s.firstIndex(where: { $0.isWhitespace }) { s = String(s[..<end]) }
        guard var comps = URLComponents(string: s),
              let host = comps.host?.lowercased(),
              host.contains("threads.") else { return nil }
        comps.query = nil
        comps.fragment = nil
        return comps.url
    }

    static func username(from url: URL) -> String? {
        for part in url.pathComponents where part.hasPrefix("@") {
            return String(part.dropFirst())
        }
        return nil
    }

    static func fetch(_ input: String) async throws -> FetchedPost {
        guard let url = postURL(from: input) else { throw FetchError.badLink }
        var best = FetchedPost()
        best.username = username(from: url)

        for agent in userAgents {
            var request = URLRequest(url: url, timeoutInterval: 20)
            request.setValue(agent, forHTTPHeaderField: "User-Agent")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            guard let result = try? await URLSession.shared.data(for: request),
                  let html = String(data: result.0, encoding: .utf8) else { continue }
            var found = parse(html)
            // A short link redirects to the full /@name/post/... address.
            if let final = result.1.url, let name = username(from: final) { found.username = name }
            best = merge(best, found)
            if found.text != nil && !best.missingDetails { break }
        }

        // The embed page (what Threads shows on other websites) has the name,
        // checkmark, time and counts.
        if best.missingDetails {
            let embedURL = url.appendingPathComponent("embed")
            var request = URLRequest(url: embedURL, timeoutInterval: 20)
            request.setValue(userAgents[0], forHTTPHeaderField: "User-Agent")
            if let result = try? await URLSession.shared.data(for: request),
               let html = String(data: result.0, encoding: .utf8) {
                var found = parse(html)
                found.text = nil // keep the main page's text; the embed's may be cut short
                best = merge(best, found)
                best = merge(best, parseEmbed(html))
            }
        }

        guard let text = best.text, !text.isEmpty else { throw FetchError.nothingFound }
        best.text = text
        return best
    }

    /// Keeps what we already have, fills gaps, and prefers the longer text
    /// (the page's meta description can be cut short).
    private static func merge(_ a: FetchedPost, _ b: FetchedPost) -> FetchedPost {
        var r = a
        r.username = a.username ?? b.username
        if (b.text?.count ?? 0) > (a.text?.count ?? 0) { r.text = b.text }
        r.avatarURL = a.avatarURL ?? b.avatarURL
        r.verified = a.verified ?? b.verified
        r.takenAt = a.takenAt ?? b.takenAt
        r.likes = a.likes ?? b.likes
        r.replies = a.replies ?? b.replies
        r.reposts = a.reposts ?? b.reposts
        r.shares = a.shares ?? b.shares
        return r
    }

    static func parse(_ html: String) -> FetchedPost {
        var p = FetchedPost()

        // 1. The JSON the page embeds for its own scripts (full text and counts).
        let jsonString = #""((?:\\.|[^"\\])*)""#
        if let raw = firstMatch(#""caption":\{(?:[^{}"]|"(?:\\.|[^"\\])*")*?"text":"# + jsonString, in: html) {
            p.text = decodeJSONString(raw)
        }
        if let raw = firstMatch(#""profile_pic_url":"# + jsonString, in: html) {
            p.avatarURL = decodeJSONString(raw)
        }
        if let v = firstMatch(#""is_verified":(true|false)"#, in: html) { p.verified = (v == "true") }
        if let t = firstMatch(#""taken_at":(\d+)"#, in: html), let secs = Double(t) {
            p.takenAt = Date(timeIntervalSince1970: secs)
        }
        p.likes = firstMatch(#""like_count":(\d+)"#, in: html).flatMap { Int($0) }.map(formatCount)
        p.replies = firstMatch(#""direct_reply_count":(\d+)"#, in: html).flatMap { Int($0) }.map(formatCount)
        p.reposts = firstMatch(#""repost_count":(\d+)"#, in: html).flatMap { Int($0) }.map(formatCount)
        p.shares = firstMatch(#""reshare_count":(\d+)"#, in: html).flatMap { Int($0) }.map(formatCount)
        if let raw = firstMatch(#""username":"# + jsonString, in: html) {
            p.username = decodeJSONString(raw)
        }

        // 2. The link-preview meta tags.
        let meta = metaTags(html)
        if let d = meta["og:description"] ?? meta["description"], (p.text?.count ?? 0) < d.count {
            p.text = d
        }
        if p.avatarURL == nil { p.avatarURL = meta["og:image"] }
        // "Display Name (@handle) on Threads"
        if let title = meta["og:title"] ?? meta["twitter:title"],
           let handle = firstMatch(#"\(@([A-Za-z0-9._]+)\)"#, in: title) {
            p.username = handle
        }

        if let text = p.text {
            p.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return p
    }

    /// Reads the visible parts of the embed page: time, checkmark and counts.
    static func parseEmbed(_ html: String) -> FetchedPost {
        var p = FetchedPost()
        if let iso = firstMatch(#"<time[^>]*datetime="([^"]+)""#, in: html) {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            p.takenAt = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        }
        if html.range(of: #"aria-label="Verified"|>Verified<|title="Verified""#,
                      options: [.regularExpression, .caseInsensitive]) != nil {
            p.verified = true
        }
        let text = visibleText(html)
        let num = #"(\d[\d,.]*[KkMm]?)"#
        p.likes = firstMatch(num + #"\s+likes?\b"#, in: text, caseInsensitive: true)
        p.replies = firstMatch(num + #"\s+repl(?:y|ies)\b"#, in: text, caseInsensitive: true)
        p.reposts = firstMatch(num + #"\s+reposts?\b"#, in: text, caseInsensitive: true)
        p.shares = firstMatch(num + #"\s+shares?\b"#, in: text, caseInsensitive: true)
        return p
    }

    /// Tags stripped, so "<span>531</span> likes" reads as "531 likes".
    private static func visibleText(_ html: String) -> String {
        var s = html.replacingOccurrences(of: #"<script[\s\S]*?</script>|<style[\s\S]*?</style>"#,
                                          with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        s = decodeEntities(s)
        return s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    /// Threads style: 531, 1.2K, 12K, 3.4M.
    static func formatCount(_ n: Int) -> String {
        func short(_ v: Double, _ suffix: String) -> String {
            let s = v < 10 ? String(format: "%.1f", v) : String(Int(v))
            return (s.hasSuffix(".0") ? String(s.dropLast(2)) : s) + suffix
        }
        if n >= 1_000_000 { return short(Double(n) / 1_000_000, "M") }
        if n >= 1_000 { return short(Double(n) / 1_000, "K") }
        return String(n)
    }

    // MARK: - Helpers

    private static func firstMatch(_ pattern: String, in s: String, caseInsensitive: Bool = false) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern,
                                                options: caseInsensitive ? [.caseInsensitive] : []) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1,
              m.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    private static func decodeJSONString(_ raw: String) -> String? {
        try? JSONDecoder().decode(String.self, from: Data("\"\(raw)\"".utf8))
    }

    /// property/name -> decoded content, for every <meta> tag (attribute order doesn't matter).
    private static func metaTags(_ html: String) -> [String: String] {
        var out: [String: String] = [:]
        guard let tagRE = try? NSRegularExpression(pattern: #"<meta\s[^>]*>"#, options: [.caseInsensitive]),
              let attrRE = try? NSRegularExpression(pattern: #"([a-zA-Z:-]+)\s*=\s*"([^"]*)""#) else { return out }
        let ns = html as NSString
        for m in tagRE.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let tag = ns.substring(with: m.range)
            let tns = tag as NSString
            var attrs: [String: String] = [:]
            for a in attrRE.matches(in: tag, range: NSRange(location: 0, length: tns.length)) {
                attrs[tns.substring(with: a.range(at: 1)).lowercased()] = tns.substring(with: a.range(at: 2))
            }
            if let key = attrs["property"] ?? attrs["name"], let content = attrs["content"], out[key] == nil {
                out[key] = decodeEntities(content)
            }
        }
        return out
    }

    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "&", let semi = s[i...].prefix(12).firstIndex(of: ";") {
                let name = String(s[s.index(after: i)..<semi])
                var decoded: String?
                switch name {
                case "amp": decoded = "&"
                case "lt": decoded = "<"
                case "gt": decoded = ">"
                case "quot": decoded = "\""
                case "apos": decoded = "'"
                case "nbsp": decoded = " "
                default:
                    if name.hasPrefix("#x") || name.hasPrefix("#X"), let v = UInt32(name.dropFirst(2), radix: 16),
                       let u = Unicode.Scalar(v) {
                        decoded = String(Character(u))
                    } else if name.hasPrefix("#"), let v = UInt32(name.dropFirst()), let u = Unicode.Scalar(v) {
                        decoded = String(Character(u))
                    }
                }
                if let decoded {
                    out += decoded
                    i = s.index(after: semi)
                    continue
                }
            }
            out.append(s[i])
            i = s.index(after: i)
        }
        return out
    }

    static func downloadImage(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        return try? await URLSession.shared.data(from: url).0
    }
}
