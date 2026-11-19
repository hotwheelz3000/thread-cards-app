import SwiftUI
import UIKit

/// Everything shown on a card. Every field is editable in the app.
struct PostInfo {
    var username = ""
    var verified = true
    var time = ""
    var text = ""
    var likes = ""
    var replies = ""
    var reposts = ""
    var shares = ""
    var avatar: UIImage?
}

/// Colors and sizes measured from the Threads "Add to Instagram story" preview.
/// The story is 360 x 640 points, rendered at 3x = 1080 x 1920 pixels.
enum Look {
    static let storySize = CGSize(width: 360, height: 640)
    static let storyBackground = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255)   // #1A1A1A
    static let cardBackground = Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)    // #1E1E1E
    static let cardBorder = Color(red: 42 / 255, green: 43 / 255, blue: 43 / 255)        // #2A2B2B
    static let text = Color(red: 243 / 255, green: 245 / 255, blue: 247 / 255)           // #F3F5F7
    static let name = Color(red: 248 / 255, green: 249 / 255, blue: 249 / 255)           // #F8F9F9
    static let gray = Color(red: 119 / 255, green: 119 / 255, blue: 119 / 255)           // #777777
    static let pill = Color(red: 52 / 255, green: 52 / 255, blue: 52 / 255)              // #343434
    static let blue = Color(red: 0, green: 166 / 255, blue: 1)                           // #00A6FF
    static let cardWidth: CGFloat = 296
}

/// One full story image: dark background with the card centered.
struct StoryView: View {
    let post: PostInfo
    let text: String
    let index: Int
    let total: Int

    var body: some View {
        ZStack {
            Look.storyBackground
            // Shrinks the type only when a very long half wouldn't fit.
            ViewThatFits(in: .vertical) {
                ForEach([1.0, 0.92, 0.84, 0.76, 0.68, 0.6, 0.52], id: \.self) { s in
                    CardView(post: post, text: text, index: index, total: total, scale: s)
                }
            }
            .padding(.vertical, 24)
        }
        .frame(width: Look.storySize.width, height: Look.storySize.height)
        .environment(\.colorScheme, .dark)
    }
}

struct CardView: View {
    let post: PostInfo
    let text: String
    let index: Int
    let total: Int
    var scale: CGFloat = 1

    private var bodySize: CGFloat { 15.5 * scale }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 9 * scale)

            VStack(alignment: .leading, spacing: 6 * scale) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, p in
                    Text(p)
                        .font(.system(size: bodySize))
                        .lineSpacing(2.2 * scale)
                        .foregroundStyle(Look.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if total > 1 {
                Text("\(index)/\(total)")
                    .font(.system(size: 12 * scale, weight: .semibold))
                    .foregroundStyle(Look.gray)
                    .padding(.horizontal, 4.5 * scale)
                    .frame(height: 19 * scale)
                    .background(Look.pill, in: RoundedRectangle(cornerRadius: 6 * scale, style: .continuous))
                    .padding(.top, 8 * scale)
            }

            if hasStats {
                stats.padding(.top, 8 * scale)
            }
        }
        .padding(.horizontal, 10.5)
        .padding(.top, 12.5)
        .padding(.bottom, 12)
        .frame(width: Look.cardWidth, alignment: .leading)
        .background(Look.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Look.cardBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 10)
    }

    private var paragraphs: [String] {
        let parts = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [" "] : parts
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 0) {
            avatar
                .frame(width: 31 * scale, height: 31 * scale)
                .clipShape(Circle())
                .padding(.trailing, 11 * scale)

            Text(post.username.isEmpty ? "username" : post.username)
                .font(.system(size: bodySize, weight: .semibold))
                .foregroundStyle(Look.name)
                .lineLimit(1)

            if post.verified {
                Image(systemName: "checkmark.seal.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Look.blue)
                    .font(.system(size: 12.5 * scale))
                    .padding(.leading, 3 * scale)
            }

            if !post.time.isEmpty {
                Text(post.time)
                    .font(.system(size: bodySize))
                    .foregroundStyle(Look.gray)
                    .padding(.leading, 6.5 * scale)
            }

            Spacer(minLength: 8)

            Image(systemName: "at")
                .font(.system(size: 15 * scale, weight: .semibold))
                .foregroundStyle(Look.text)
        }
    }

    @ViewBuilder private var avatar: some View {
        if let img = post.avatar {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            ZStack {
                Color(white: 0.25)
                Image(systemName: "person.fill")
                    .font(.system(size: 15 * scale))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
    }

    private var hasStats: Bool {
        ![post.likes, post.replies, post.reposts, post.shares].allSatisfy { $0.isEmpty }
    }

    private var stats: some View {
        HStack(spacing: 20 * scale) {
            stat("heart", post.likes)
            stat("bubble.left", post.replies)
            stat("arrow.2.squarepath", post.reposts)
            stat("paperplane", post.shares)
        }
    }

    @ViewBuilder private func stat(_ icon: String, _ value: String) -> some View {
        if !value.isEmpty {
            HStack(spacing: 4 * scale) {
                Image(systemName: icon)
                    .font(.system(size: 14.5 * scale))
                Text(value)
                    .font(.system(size: 15 * scale))
            }
            .foregroundStyle(Look.gray)
        }
    }
}
