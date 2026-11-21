import Foundation
import Photos

/// Saves card images to Photos.
enum PhotoSaver {
    struct Denied: LocalizedError {
        var errorDescription: String? {
            "Photos access is off. Turn it on in Settings > Threads Cards > Photos."
        }
    }

    static func save(_ pngs: [Data]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw Denied() }
        try await PHPhotoLibrary.shared().performChanges {
            for data in pngs {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
        }
    }
}

/// Downloads videos and saves them to Photos.
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
