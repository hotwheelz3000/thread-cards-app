import SwiftUI

/// "Edit post": a bordered box that opens to show every field of the cards,
/// including the original post (for replies) and the thread's next posts.
struct PostEditor: View {
    @Binding var post: PostInfo
    @Binding var isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { isOpen.toggle() }
            } label: {
                HStack {
                    Text("Edit post").font(Theme.font(17, .semibold, relativeTo: .headline))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .foregroundStyle(Theme.text)
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                Rectangle().fill(Theme.border).frame(height: 1)
                fields.padding(14)
            }
        }
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
            .strokeBorder(Theme.border, lineWidth: 1))
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 10) {
            if post.parent != nil {
                parentEditor
                Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 4)
                Text("Reply").fieldLabel()
            }
            field("Username", $post.username)
            Toggle(isOn: $post.verified) {
                Text("Verified checkmark").font(Theme.font(16)).foregroundStyle(Theme.text)
            }
            .tint(Theme.track)
            field("Time (e.g. 6h)", $post.time, plain: false)
            Text(post.followUps.isEmpty ? "Post text" : "Post 1").fieldLabel()
            textBox($post.text, minHeight: 160)
            ForEach(post.followUps.indices, id: \.self) { i in
                HStack {
                    Text("Post \(i + 2)").fieldLabel()
                    Spacer()
                    removeButton { post.followUps.remove(at: i) }
                }
                textBox(Binding(
                    get: { i < post.followUps.count ? post.followUps[i] : "" },
                    set: { if i < post.followUps.count { post.followUps[i] = $0 } }
                ), minHeight: 120)
            }
            Button {
                post.followUps.append("")
            } label: {
                Label("Add next post", systemImage: "plus")
                    .font(Theme.font(15, .semibold, relativeTo: .callout))
                    .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                field("Likes", $post.likes, plain: false)
                field("Replies", $post.replies, plain: false)
                field("Reposts", $post.reposts, plain: false)
                field("Shares", $post.shares, plain: false)
            }
            .keyboardType(.numbersAndPunctuation)
        }
    }

    /// The post being replied to (card 1).
    @ViewBuilder private var parentEditor: some View {
        HStack {
            Text("Original post").fieldLabel()
            Spacer()
            removeButton { post.parent = nil }
        }
        field("Username", Binding(
            get: { post.parent?.username ?? "" },
            set: { post.parent?.username = $0 }))
        Toggle(isOn: Binding(
            get: { post.parent?.verified ?? false },
            set: { post.parent?.verified = $0 })) {
            Text("Verified checkmark").font(Theme.font(16)).foregroundStyle(Theme.text)
        }
        .tint(Theme.track)
        textBox(Binding(
            get: { post.parent?.text ?? "" },
            set: { post.parent?.text = $0 }), minHeight: 120)
    }

    /// A text field in the Soulection style. `plain` turns off capitals and autocorrect.
    private func field(_ placeholder: String, _ text: Binding<String>, plain: Bool = true) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.muted))
            .textInputAutocapitalization(plain ? .never : .sentences)
            .autocorrectionDisabled(plain)
            .soulectionField(padding: 10)
    }

    private func textBox(_ text: Binding<String>, minHeight: CGFloat) -> some View {
        TextEditor(text: text)
            .scrollContentBackground(.hidden)
            .frame(minHeight: minHeight)
            .soulectionField(padding: 6)
    }

    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Remove").font(Theme.font(13, .semibold, relativeTo: .caption))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
