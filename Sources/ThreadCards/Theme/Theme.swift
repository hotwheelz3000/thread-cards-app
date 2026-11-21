import CoreText
import SwiftUI

/// The app's screens, styled like soulection-app (values read from
/// radio.soulection.com): #1A1A1A background, #2A2A2A borders, 9 pt corners,
/// Bai Jamjuree, light grey text and white as the accent.
/// The story cards keep the Threads look (see CardView).
enum Theme {
    static let bg = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255)        // rgb(26,26,26)
    static let border = Color(red: 42 / 255, green: 42 / 255, blue: 42 / 255)    // rgb(42,42,42)
    static let text = Color(white: 180 / 255)                                     // rgb(180,180,180)
    static let muted = Color(white: 150 / 255)                                    // rgb(150,150,150)
    static let track = Color(white: 105 / 255)                                    // rgb(105,105,105)
    static let accent = Color.white
    static let pressed = Color.white.opacity(0.06)
    static let corner: CGFloat = 9

    enum Weight: String {
        case regular = "Regular", medium = "Medium", semibold = "SemiBold", bold = "Bold"
    }

    /// Bai Jamjuree at a size that still follows the phone's text size setting.
    static func font(_ size: CGFloat, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("BaiJamjuree-\(weight.rawValue)", size: size, relativeTo: style)
    }

    /// Makes the bundled Bai Jamjuree files usable (also listed in UIAppFonts;
    /// registering twice is harmless).
    static func registerFonts() {
        for w in ["Regular", "Medium", "SemiBold", "Bold"] {
            if let url = Bundle.main.url(forResource: "BaiJamjuree-\(w)", withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}

/// White pill with dark text (like Soulection's "Let's go"), or an outlined pill.
/// `outline` sets an outlined pill's border color; `dims` fades it while disabled.
struct PillButtonStyle: ButtonStyle {
    var filled = true
    var outline: Color = Theme.border
    var dims = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(17, .semibold, relativeTo: .headline))
            .foregroundStyle(filled ? Theme.bg : Theme.text)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .padding(.horizontal, 14)
            .background(Capsule().fill(filled ? Theme.accent : (configuration.isPressed ? Theme.pressed : .clear)))
            .overlay(Capsule().strokeBorder(filled ? .clear : outline, lineWidth: 1))
            .opacity(isEnabled || !dims ? (configuration.isPressed && filled ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

extension View {
    /// A text field or box: dark fill, thin border, 9 pt corners.
    func soulectionField(padding: CGFloat = 12) -> some View {
        self
            .font(Theme.font(16))
            .foregroundStyle(.white)
            .padding(padding)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }

    /// A small grey label above a field.
    func fieldLabel() -> some View {
        self.font(Theme.font(13, .semibold, relativeTo: .caption)).foregroundStyle(Theme.muted)
    }
}

/// Flat top bar with a border underneath, like soulection-app's; the title is in
/// Threads' screen font (SF Pro Bold).
struct TopBar<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            // Apple's system font (SF Pro) in bold, as on Threads' own screens.
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            trailing
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .background(Theme.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }
}
