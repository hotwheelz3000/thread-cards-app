import Foundation
import Photos
import UIKit
import WebKit

/// What the hidden web view found on the post page.
struct PageInfo: Sendable {
    var videos: [String] = []
    var links: [String] = []
    var path = ""

    var videoURLs: [URL] { videos.compactMap(URL.init(string:)) }

    /// The author's next posts in the same thread (2/2, 3/3...), as full links:
    /// the posts by the same author right after this one, up to the first post by someone else.
    var followUps: [URL] {
        func parts(_ l: String) -> (user: String, code: String)? {
            let c = l.split(separator: "/").map(String.init) // ["@name", "post", "CODE"]
            guard c.count >= 3, c[0].hasPrefix("@"), c[1] == "post" else { return nil }
            return (String(c[0].dropFirst()).lowercased(), c[2])
        }
        let posts = links.compactMap(parts)
        guard !posts.isEmpty else { return [] }
        var start = 0
        if let here = parts(path), let i = posts.firstIndex(where: { $0.code == here.code }) { start = i }
        let author = posts[start].user
        var out: [URL] = []
        for p in posts.dropFirst(start + 1) {
            guard p.user == author else { break }
            if let u = URL(string: "https://www.threads.com/@\(p.user)/post/\(p.code)") { out.append(u) }
            if out.count == 9 { break }
        }
        return out
    }
}

/// Opens a Threads post in a hidden web view (the way Safari would) and
/// reads its video files and the other posts in the thread.
@MainActor
enum VideoFinder {
    private static let script = """
    (() => {
      const out = [];
      const add = (u) => { if (u && !u.startsWith('blob:') && !out.includes(u)) out.push(u); };
      document.querySelectorAll('video').forEach(v => {
        add(v.currentSrc); add(v.getAttribute('src'));
        v.querySelectorAll('source').forEach(s => add(s.getAttribute('src')));
      });
      if (out.length === 0) {
        const html = document.documentElement.innerHTML;
        const re = /"video_versions":\\[\\{[^\\]]*?"url":"((?:\\\\.|[^"\\\\])*)"/g;
        let m;
        while ((m = re.exec(html))) { try { add(JSON.parse('"' + m[1] + '"')); } catch (e) {} }
      }
      // Every post on the page, in order, as /@name/post/CODE.
      const links = [];
      document.querySelectorAll('a[href*="/post/"]').forEach(a => {
        const m = (a.getAttribute('href') || '').match(/\\/@([^\\/?#]+)\\/post\\/([^\\/?#]+)/);
        if (m) { const l = '/@' + m[1] + '/post/' + m[2]; if (!links.includes(l)) links.push(l); }
      });
      return { videos: out.filter(u => u.startsWith('http')), links: links, path: location.pathname };
    })()
    """

    /// The post's videos and the posts around it.
    static func find(_ postURL: URL, timeout: TimeInterval = 20) async -> PageInfo {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .nonPersistent()

        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        web.alpha = 0.01
        web.isUserInteractionEnabled = false
        // Kept in the window so the page runs normally; invisible and behind everything.
        if let window = keyWindow() {
            window.insertSubview(web, at: 0)
        }
        defer { web.removeFromSuperview() }

        web.load(URLRequest(url: postURL))

        let deadline = Date().addingTimeInterval(timeout)
        var last = PageInfo()
        var best = PageInfo()
        var steady = 0
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let found = await read(web)
            if !found.videos.isEmpty { best.videos = found.videos }
            if found.links.count >= best.links.count { best.links = found.links }
            if !found.path.isEmpty { best.path = found.path }
            // Stop once the page has settled: same posts and videos for 2 seconds.
            if !found.links.isEmpty && found.links == last.links && found.videos == last.videos {
                steady += 1
                if steady >= 2 { break }
            } else {
                steady = 0
            }
            last = found
        }
        web.stopLoading()
        return best
    }

    private static func read(_ web: WKWebView) async -> PageInfo {
        await withCheckedContinuation { cont in
            web.evaluateJavaScript(script) { result, _ in
                let d = result as? [String: Any]
                cont.resume(returning: PageInfo(videos: d?["videos"] as? [String] ?? [],
                                                links: d?["links"] as? [String] ?? [],
                                                path: d?["path"] as? String ?? ""))
            }
        }
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

enum VideoSaver {
    struct DownloadFailed: LocalizedError {
        var errorDescription: String? { "Couldn't download the video." }
    }

    /// Downloads each video and saves it to Photos.
    static func save(_ urls: [URL]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw PhotoSaver.Denied() }

        var files: [URL] = []
        for url in urls {
            var request = URLRequest(url: url, timeoutInterval: 120)
            request.setValue("https://www.threads.com/", forHTTPHeaderField: "Referer")
            let (temp, response) = try await URLSession.shared.download(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw DownloadFailed()
            }
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            try FileManager.default.moveItem(at: temp, to: dest)
            files.append(dest)
        }

        let toSave = files
        try await PHPhotoLibrary.shared().performChanges {
            for file in toSave {
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: file, options: options)
            }
        }
    }
}
