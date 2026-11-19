import SwiftUI
import UIKit
import Photos

struct ContentView: View {
    @State private var link = ""
    @State private var post = PostInfo()
    @State private var loading = false
    @State private var message = ""
    @State private var saving = false
    @State private var showEdit = false
    @State private var videos: [URL] = []
    @State private var findingVideo = false
    @State private var savingVideo = false
    @State private var history = HistoryStore()
    @State private var showHistory = false
    /// The link of the post on screen (for History).
    @State private var shownLink = ""

    /// One card per post in the thread: the linked post, then the author's follow-ups.
    private var parts: [String] {
        ([post.text] + post.followUps).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    linkBox

                    if !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !post.text.isEmpty {
                        previews
                        saveButton
                    }

                    if findingVideo {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Looking for the rest of the thread and videos...")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }

                    videoSection

                    DisclosureGroup("Edit post", isExpanded: $showEdit) { editor }
                        .padding(12)
                        .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 12))

                    Text(BuildInfo.label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
            .navigationTitle("Thread Cards")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(store: history) { item in openSaved(item) }
            }
        }
    }

    // MARK: - Link

    private var linkBox: some View {
        VStack(spacing: 10) {
            TextField("Threads post link", text: $link)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(12)
                .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                Button {
                    if let s = UIPasteboard.general.string { link = s }
                    fetch()
                } label: {
                    Label("Paste & Get", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    fetch()
                } label: {
                    Label("Get", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(link.isEmpty)
            }
            .disabled(loading)

            if loading { ProgressView() }
        }
    }

    private func fetch() {
        let input = link
        loading = true
        message = ""
        findVideos(input)
        Task {
            do {
                let f = try await PostFetcher.fetch(input)
                var p = PostInfo()
                p.username = f.username ?? ""
                p.verified = f.verified ?? false
                p.time = f.takenAt.map(Self.relativeTime) ?? ""
                p.text = f.text ?? ""
                p.likes = f.likes ?? ""
                p.replies = f.replies ?? ""
                p.reposts = f.reposts ?? ""
                p.shares = f.shares ?? ""
                if let url = f.avatarURL, let data = await PostFetcher.downloadImage(url) {
                    p.avatar = UIImage(data: data)
                }
                p.followUps = post.followUps.isEmpty || shownLink != input ? pendingFollowUps(for: input) : post.followUps
                post = p
                shownLink = input
                history.save(link: input, post: p, hadVideo: !videos.isEmpty)
                message = ""
            } catch {
                message = error.localizedDescription
                if let u = PostFetcher.postURL(from: input), let name = PostFetcher.username(from: u) {
                    post.username = name
                }
                showEdit = true
            }
            loading = false
        }
    }

    /// Follow-up texts found before the main post finished loading.
    @State private var earlyFollowUps: [String: [String]] = [:]

    private func pendingFollowUps(for input: String) -> [String] {
        earlyFollowUps[HistoryStore.key(input)] ?? []
    }

    /// Opens the post page in the background: finds videos and the author's
    /// next posts in the thread, then reads each of those posts' text.
    private func findVideos(_ input: String, threadToo: Bool = true) {
        videos = []
        guard let url = PostFetcher.postURL(from: input) else { return }
        findingVideo = true
        let key = HistoryStore.key(input)
        Task {
            let page = await VideoFinder.find(url)
            // Ignore the result if another post was fetched meanwhile.
            guard HistoryStore.key(link) == key else { return }
            videos = page.videoURLs

            var texts: [String] = []
            if threadToo {
                for next in page.followUps {
                    guard let f = try? await PostFetcher.fetch(next.absoluteString),
                          let t = f.text, !t.isEmpty else { break }
                    texts.append(t)
                }
            }
            guard HistoryStore.key(link) == key else { return }
            findingVideo = false

            if HistoryStore.key(shownLink) == key {
                if threadToo, !texts.isEmpty { post.followUps = texts }
                if !texts.isEmpty || !videos.isEmpty {
                    history.save(link: input, post: post, hadVideo: !videos.isEmpty)
                }
            } else if !texts.isEmpty {
                earlyFollowUps[key] = texts // the main post is still loading
            }
        }
    }

    private func openSaved(_ item: SavedPost) {
        link = item.link
        post = item.post
        shownLink = item.link
        message = ""
        videos = []
        findingVideo = false
        // Threads video links expire, so look them up again.
        if item.hadVideo { findVideos(item.link, threadToo: false) }
    }

    // MARK: - Preview + save

    private var previews: some View {
        let previewScale: CGFloat = 0.62
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, text in
                    Scaled(scale: previewScale) {
                        StoryView(post: post, text: text, index: i + 1, total: parts.count)
                            .scaleEffect(previewScale, anchor: .topLeading)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Label(saving ? "Saving..." : "Save to Photos", systemImage: "square.and.arrow.down")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(saving)
    }

    private func save() {
        saving = true
        let cards = parts
        let images = cards.enumerated().compactMap { i, text -> Data? in
            let renderer = ImageRenderer(content: StoryView(post: post, text: text, index: i + 1, total: cards.count))
            renderer.scale = 3
            return renderer.uiImage?.pngData()
        }
        Task {
            do {
                try await PhotoSaver.save(images)
                message = images.count == 1 ? "Saved the card to Photos." : "Saved both cards to Photos."
                // Keeps any edits in History.
                if !shownLink.isEmpty {
                    history.save(link: shownLink, post: post, hadVideo: !videos.isEmpty)
                }
            } catch {
                message = error.localizedDescription
            }
            saving = false
        }
    }

    // MARK: - Video

    @ViewBuilder private var videoSection: some View {
        if !findingVideo && !videos.isEmpty {
            Button {
                saveVideos()
            } label: {
                Label(savingVideo ? "Saving video..." : (videos.count == 1 ? "Save Video" : "Save \(videos.count) Videos"),
                      systemImage: "video.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .disabled(savingVideo)
        }
    }

    private func saveVideos() {
        let urls = videos
        savingVideo = true
        Task {
            do {
                try await VideoSaver.save(urls)
                message = urls.count == 1 ? "Saved the video to Photos." : "Saved \(urls.count) videos to Photos."
            } catch {
                message = error.localizedDescription
            }
            savingVideo = false
        }
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Username", text: $post.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Toggle("Verified checkmark", isOn: $post.verified)
            TextField("Time (e.g. 6h)", text: $post.time)
            Text(post.followUps.isEmpty ? "Post text" : "Post 1").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $post.text)
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
                .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 8))
            ForEach(post.followUps.indices, id: \.self) { i in
                HStack {
                    Text("Post \(i + 2)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Remove", role: .destructive) { post.followUps.remove(at: i) }
                        .font(.caption)
                }
                TextEditor(text: Binding(
                    get: { i < post.followUps.count ? post.followUps[i] : "" },
                    set: { if i < post.followUps.count { post.followUps[i] = $0 } }
                ))
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 8))
            }
            Button("Add next post") { post.followUps.append("") }
                .font(.callout)
            HStack {
                TextField("Likes", text: $post.likes)
                TextField("Replies", text: $post.replies)
                TextField("Reposts", text: $post.reposts)
                TextField("Shares", text: $post.shares)
            }
            .keyboardType(.numbersAndPunctuation)
            .font(.callout)
        }
        .textFieldStyle(.roundedBorder)
        .padding(.top, 8)
    }

    // MARK: - Formatting (matches Threads: 6h, 2d)

    static func relativeTime(_ date: Date) -> String {
        let secs = max(0, Int(Date().timeIntervalSince(date)))
        if secs < 60 { return "\(max(secs, 1))s" }
        if secs < 3600 { return "\(secs / 60)m" }
        if secs < 86_400 { return "\(secs / 3600)h" }
        if secs < 7 * 86_400 { return "\(secs / 86_400)d" }
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yy"
        return f.string(from: date)
    }
}

enum PhotoSaver {
    struct Denied: LocalizedError {
        var errorDescription: String? {
            "Photos access is off. Turn it on in Settings > Thread Cards > Photos."
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
