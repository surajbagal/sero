import SwiftUI

// Sero: the address bar across the top (Settings › Appearance › Window ›
// Address bar across the top), as Safari, Chrome and Arc's top bar have it:
// with the tabs down the side, a band over the page with back, forward and
// reload and the address as wide as the page, the site card's button at its
// end. The same field as the column's (AddressLine): a click edits the
// address in place, its suggestions hanging under it. The column then keeps
// neither its own back, forward and reload nor its address line.
//
// With the column folded away (⌘S) the band runs the window's width, and
// starts with the button that brings the column back.

struct TopBar: View {
    /// The band's height: the row the window's buttons sit in, so the
    /// field lines up with them.
    @MainActor static var height: CGFloat { Metrics.strip }
    /// The address field's height in it.
    static let field: CGFloat = 30

    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences

    var body: some View {
        HStack(spacing: 8) {
            if browser.folded {
                Door(icon: prefs.sidePosition == .right ? "sidebar.right" : "sidebar.left",
                     help: "Show Sidebar   ⌘S") {
                    browser.toggleFold()
                }
                .accessibilityLabel("Show Sidebar")
            }
            Helm(browser: browser)
            AddressLine(browser: browser, height: TopBar.field)
                .frame(maxWidth: .infinity)
                // Its suggestions hang over the page below.
                .zIndex(1)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(height: TopBar.height)
    }

    /// Whether it shows: asked for, with the tabs down the side.
    @MainActor static func shown(_ prefs: Preferences) -> Bool { prefs.topBar && prefs.sidebar }
}
