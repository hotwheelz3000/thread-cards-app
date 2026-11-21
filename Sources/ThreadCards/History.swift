import SwiftUI
import UIKit

/// One post kept in History.
struct SavedPost: Codable, Identifiable, Equatable {
    var id = UUID()
    var link: String
    var username: String
    var verified: Bool
    var time: String
    var text: String
    var followUps: [String]?
    var parent: SavedParent?
    var likes: String
    var replies: String
    var reposts: String
    var shares: String
    var avatar: Data?
    var hadVideo: Bool
    var savedAt: Date

    init(link: String, post: PostInfo, hadVideo: Bool) {
        self.link = link
        username = post.username
        verified = post.verified
        time = post.time
        text = post.text
        followUps = post.followUps
        parent = post.parent.map {
            SavedParent(username: $0.username, verified: $0.verified, text: $0.text,
                        avatar: $0.avatar?.jpegData(compressionQuality: 0.85))
        }
        likes = post.likes
        replies = post.replies
        reposts = post.reposts
        shares = post.shares
        avatar = post.avatar?.jpegData(compressionQuality: 0.85)
        self.hadVideo = hadVideo
        savedAt = Date()
    }

    var post: PostInfo {
        var p = PostInfo()
        p.username = username
        p.verified = verified
        p.time = time
        p.text = text
        p.followUps = followUps ?? []
        p.parent = parent.map {
            ParentPost(username: $0.username, verified: $0.verified, text: $0.text,
                       avatar: $0.avatar.flatMap(UIImage.init(data:)))
        }
        p.likes = likes
        p.replies = replies
        p.reposts = reposts
        p.shares = shares
        p.avatar = avatar.flatMap(UIImage.init(data:))
        return p
    }
}

struct SavedParent: Codable, Equatable {
    var username: String
    var verified: Bool
    var text: String
    var avatar: Data?
}

/// History, newest first, kept in history.json in the app's Documents folder
/// (survives app updates).
@MainActor @Observable
final class HistoryStore {
    private(set) var posts: [SavedPost] = []

    private let file: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("history.json")

    init() {
        if let data = try? Data(contentsOf: file),
           let saved = try? JSONDecoder().decode([SavedPost].self, from: data) {
            posts = saved
        }
    }

    /// Adds the post, or replaces the one with the same link, and moves it to the top.
    func save(link: String, post: PostInfo, hadVideo: Bool) {
        let key = Self.key(link)
        guard !key.isEmpty, !post.text.isEmpty else { return }
        let old = posts.first { Self.key($0.link) == key }
        posts.removeAll { Self.key($0.link) == key }
        var entry = SavedPost(link: link, post: post, hadVideo: hadVideo || (old?.hadVideo ?? false))
        if let old { entry.id = old.id }
        posts.insert(entry, at: 0)
        write()
    }

    func delete(at offsets: IndexSet) {
        posts.remove(atOffsets: offsets)
        write()
    }

    private func write() {
        if let data = try? JSONEncoder().encode(posts) {
            try? data.write(to: file, options: .atomic)
        }
    }

    /// The same post pasted twice counts as one, whatever tracking bits the link has.
    static func key(_ link: String) -> String {
        PostFetcher.postURL(from: link)?.absoluteString.lowercased()
            ?? link.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct HistoryView: View {
    let store: HistoryStore
    let open: (SavedPost) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "History") {
                Button("Done") { dismiss() }
                    .font(Theme.font(17, .semibold, relativeTo: .headline))
                    .foregroundStyle(.white)
            }

            if store.posts.isEmpty {
                Spacer()
                Text("Posts you get show up here.")
                    .font(Theme.font(16))
                    .foregroundStyle(Theme.muted)
                Spacer()
            } else {
                List {
                    ForEach(store.posts) { item in
                        Button {
                            open(item)
                            dismiss()
                        } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.bg)
                        .listRowSeparatorTint(Theme.border)
                    }
                    .onDelete { store.delete(at: $0) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func row(_ item: SavedPost) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let data = item.avatar, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Theme.border
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.username.isEmpty ? "Unknown" : item.username)
                        .font(Theme.font(16, .semibold))
                        .foregroundStyle(.white)
                    if item.hadVideo {
                        Image(systemName: "video.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text(item.savedAt, format: .dateTime.month(.abbreviated).day())
                        .font(Theme.font(13, relativeTo: .caption))
                        .foregroundStyle(Theme.muted)
                }
                Text(item.text.components(separatedBy: "\n").first ?? "")
                    .font(Theme.font(15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
