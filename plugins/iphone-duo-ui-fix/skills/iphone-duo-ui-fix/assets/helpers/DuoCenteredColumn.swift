import SwiftUI

/// Caps interactive content to a phone-width column on wide windows (iPhone Duo
/// inner display, iPad) while `background` fills the whole window. On compact
/// widths it is a no-op. Apply per screen, or once around the root content.
///
/// Keep NavigationStack / TabView *outside* the modifier so the system still gets
/// its bars (and the vertical bar on Duo); apply it to each screen's content.
/// The screen's own gradient/image must move from the content into `background`,
/// otherwise it is capped with the content.
struct DuoCenteredColumn<Background: View>: ViewModifier {
    var maxWidth: CGFloat = 466          // outer display width; keep <= 480
    @ViewBuilder var background: Background
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            ZStack {
                background.ignoresSafeArea()      // edge to edge, under bars and rail
                content.frame(maxWidth: maxWidth) // safe areas still apply to content
            }
        } else {
            content
        }
    }
}

extension View {
    func duoCenteredColumn<B: View>(maxWidth: CGFloat = 466,
                                    @ViewBuilder background: () -> B) -> some View {
        modifier(DuoCenteredColumn(maxWidth: maxWidth, background: background))
    }

    func duoCenteredColumn(maxWidth: CGFloat = 466) -> some View {
        modifier(DuoCenteredColumn(maxWidth: maxWidth) { Color(.systemBackground) })
    }
}

// Usage:
// HomeContent()
//     .duoCenteredColumn {
//         LinearGradient(colors: [.deep, .shallow], startPoint: .top, endPoint: .bottom)
//     }
