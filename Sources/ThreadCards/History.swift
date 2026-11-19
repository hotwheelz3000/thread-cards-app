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
        p.likes = likes
        p.replies = replies
        p.reposts = reposts
        p.shares = shares
        p.avatar = avatar.flatMap(UIImage.init(data:))
        return p
    }
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
        NavigationStack {
            Group {
                if store.posts.isEmpty {
                    Text("Posts you get show up here.")
                        .foregroundStyle(.secondary)
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
                        }
                        .onDelete { store.delete(at: $0) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ item: SavedPost) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let data = item.avatar, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Color(white: 0.25)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.username.isEmpty ? "Unknown" : item.username)
                        .font(.subheadline.weight(.semibold))
                    if item.hadVideo {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.savedAt, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(item.text.components(separatedBy: "\n").first ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
