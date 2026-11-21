import UIKit

/// Everything shown on a card. Every field is editable in the app.
struct PostInfo {
    var username = ""
    var verified = true
    var time = ""
    var text = ""
    /// The author's next posts in the thread (cards 2/2, 3/3...).
    var followUps: [String] = []
    var likes = ""
    var replies = ""
    var reposts = ""
    var shares = ""
    var avatar: UIImage?
    /// The post this one replies to (someone else's), shown first with its own header.
    var parent: ParentPost?
}

/// The post a reply answers: its own name, picture and checkmark.
struct ParentPost {
    var username = ""
    var verified = false
    var text = ""
    var avatar: UIImage?

    /// As a card header (no counts or time).
    var cardPost: PostInfo {
        var p = PostInfo()
        p.username = username
        p.verified = verified
        p.text = text
        p.avatar = avatar
        return p
    }
}

/// One image: whose header it shows and the text on it.
struct Card {
    var header: PostInfo
    var text: String
}
