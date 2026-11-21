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

    /// The post it replies to (if any), the linked post, then the author's
    /// follow-ups; a post too long for one card continues on the next.
    /// The pills count every card (1/3, 2/3, 3/3).
    private var parts: [Card] {
        var cards: [Card] = []
        if let parent = post.parent {
            cards += Paginator.pages(parent.text).map { Card(header: parent.cardPost, text: $0) }
        }
        cards += ([post.text] + post.followUps).flatMap(Paginator.pages).map { Card(header: post, text: $0) }
        return cards
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Threads Cards") {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("History")
            }

            ScrollView {
                VStack(spacing: 16) {
                    linkBox

                    if !message.isEmpty {
                        Text(message)
                            .font(Theme.font(14, relativeTo: .footnote))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !post.text.isEmpty {
                        previews
                        saveButton
                    }

                    if findingVideo {
                        HStack(spacing: 8) {
                            ProgressView().tint(Theme.text)
                            Text("Looking for the rest of the thread and videos...")
                                .font(Theme.font(14, relativeTo: .footnote))
                                .foregroundStyle(Theme.muted)
                        }
                    }

                    videoSection

                    PostEditor(post: $post, isOpen: $showEdit)

                    Text(BuildInfo.label)
                        .font(Theme.font(12, relativeTo: .caption2))
                        .foregroundStyle(Theme.muted)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.bg.ignoresSafeArea())
        .tint(Theme.accent)
        .sheet(isPresented: $showHistory) {
            HistoryView(store: history) { item in openSaved(item) }
                .presentationBackground(Theme.bg)
        }
    }

    // MARK: - Link

    private var linkBox: some View {
        VStack(spacing: 10) {
            TextField("", text: $link, prompt: Text("Threads post link").foregroundStyle(Theme.muted))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .soulectionField()

            HStack(spacing: 10) {
                Button {
                    if let s = UIPasteboard.general.string { link = s }
                    fetch()
                } label: {
                    Label("Paste & Get", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(PillButtonStyle(filled: false, outline: Theme.track))

                Button {
                    fetch()
                } label: {
                    Label("Get", systemImage: "arrow.down.circle")
                }
                .buttonStyle(PillButtonStyle(filled: false, outline: Theme.track, dims: false))
                .disabled(link.isEmpty)
            }
            .disabled(loading)

            if loading { ProgressView().tint(Theme.text) }
        }
    }

    private func fetch() {
        let input = link
        loading = true
        message = ""
        readPage(input)
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
                if shownLink == input {
                    p.followUps = post.followUps
                    p.parent = post.parent
                }
                if let early = earlyExtras[HistoryStore.key(input)] {
                    if p.followUps.isEmpty { p.followUps = early.followUps }
                    if p.parent == nil { p.parent = early.parent }
                }
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

    /// Thread posts found before the main post finished loading.
    @State private var earlyExtras: [String: (followUps: [String], parent: ParentPost?)] = [:]

    /// Opens the post page in the background: finds videos, the post it replies
    /// to and the author's next posts in the thread, then reads those posts.
    private func readPage(_ input: String, threadToo: Bool = true) {
        videos = []
        guard let url = PostFetcher.postURL(from: input) else { return }
        findingVideo = true
        let key = HistoryStore.key(input)
        Task {
            let page = await PageReader.read(url)
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

            var parent: ParentPost?
            if threadToo, let up = page.parent, let f = try? await PostFetcher.fetch(up.absoluteString),
               let t = f.text, !t.isEmpty {
                var pp = ParentPost(username: f.username ?? "", verified: f.verified ?? false, text: t)
                if let a = f.avatarURL, let data = await PostFetcher.downloadImage(a) {
                    pp.avatar = UIImage(data: data)
                }
                parent = pp
            }
            guard HistoryStore.key(link) == key else { return }
            findingVideo = false

            if HistoryStore.key(shownLink) == key {
                if threadToo, !texts.isEmpty { post.followUps = texts }
                if threadToo, let parent { post.parent = parent }
                if !texts.isEmpty || parent != nil || !videos.isEmpty {
                    history.save(link: input, post: post, hadVideo: !videos.isEmpty)
                }
            } else if !texts.isEmpty || parent != nil {
                earlyExtras[key] = (texts, parent) // the main post is still loading
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
        if item.hadVideo { readPage(item.link, threadToo: false) }
    }

    // MARK: - Preview + save

    private var previews: some View {
        let previewScale: CGFloat = 0.62
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, card in
                    Scaled(scale: previewScale) {
                        StoryView(post: card.header, text: card.text, index: i + 1, total: parts.count)
                            .scaleEffect(previewScale, anchor: .topLeading)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1))
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Label(saving ? "Saving..." : "Save to Photos", systemImage: "square.and.arrow.down")
        }
        .buttonStyle(PillButtonStyle())
        .disabled(saving)
    }

    private func save() {
        saving = true
        let cards = parts
        let images = cards.enumerated().compactMap { i, card -> Data? in
            let renderer = ImageRenderer(content: StoryView(post: card.header, text: card.text, index: i + 1, total: cards.count))
            renderer.scale = 3
            return renderer.uiImage?.pngData()
        }
        Task {
            do {
                try await PhotoSaver.save(images)
                message = images.count == 1 ? "Saved the card to Photos." : "Saved \(images.count) cards to Photos."
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
            }
            .buttonStyle(PillButtonStyle(filled: false))
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
