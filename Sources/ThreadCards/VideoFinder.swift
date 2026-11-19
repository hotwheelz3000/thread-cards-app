import Foundation
import Photos
import UIKit
import WebKit

/// Opens a Threads post in a hidden web view (the way Safari would) and
/// reads the addresses of its video files.
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
      return out.filter(u => u.startsWith('http'));
    })()
    """

    /// Video URLs for the post, or [] if it has none (or they couldn't be found).
    static func find(_ postURL: URL, timeout: TimeInterval = 20) async -> [URL] {
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
        var last: [String] = []
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let found = await read(web)
            // Return once the list has settled for a second.
            if !found.isEmpty && found == last { break }
            last = found
        }
        web.stopLoading()
        return last.compactMap(URL.init(string:))
    }

    private static func read(_ web: WKWebView) async -> [String] {
        await withCheckedContinuation { cont in
            web.evaluateJavaScript(script) { result, _ in
                cont.resume(returning: (result as? [String]) ?? [])
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
