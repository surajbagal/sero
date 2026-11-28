import AppKit
import SwiftUI

// Sero › About Sero: the icon, the name and the version, as the
// standard panel shows them, with a What's New button under the version
// line that brings back this version's card. A window of our
// own, because the standard panel takes no button.

@MainActor
enum AboutWindow {
    private static var window: NSWindow?

    /// Shown, or brought forward if it is already up. Never in a test run:
    /// a probe stays off every screen (the view is drawn by the bench).
    static func show() {
        guard !Store.testing else { return }
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingView(rootView: AboutView(whatsNew: {
            AboutWindow.close()
            let browser = Browsers.frontBrowser
            browser.window?.makeKeyAndOrderFront(nil)
            WhatsNew.showAgain(in: browser)
        }))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    static func close() {
        window?.close()
        window = nil
    }
}

/// What the About window holds. Its own view, so the bench can draw it.
struct AboutView: View {
    let whatsNew: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .padding(.bottom, 10)
            Text(verbatim: "Sero")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text(verbatim: AboutView.versionLine)
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .textSelection(.enabled)
                .padding(.top, 3)
            if WhatsNew.current != nil {
                Pill("What's New", action: whatsNew)
                    .padding(.top, 12)
            }
            Text(verbatim: AboutView.copyright)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.faint)
                .padding(.top, 16)
            Button("Acknowledgements") { Acknowledgements.show() }
                .buttonStyle(.plain)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.muted)
                .padding(.top, 4)
        }
        .padding(.top, 34)
        .padding(.bottom, 20)
        .padding(.horizontal, 28)
        .frame(width: 320)
        .background(Palette.ground)
    }

    /// As the standard panel writes it: "Version 1.0.18 (202611221830)".
    static var versionLine: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "Version \(Updater.version)" : "Version \(Updater.version) (\(build))"
    }

    static var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "© 2026 Suraj Bagal"
    }
}

/// The open-source software Sero includes: its licence and the notices of
/// the components in it, bundled beside the app (build.sh), in a window of
/// their own.
enum Acknowledgements {
    private static var window: NSWindow?

    static func show() {
        guard !Store.testing else { return }
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let text = ["LICENSE", "THIRD_PARTY_NOTICES.md"].compactMap { name -> String? in
            guard let url = Bundle.main.url(forResource: name, withExtension: nil) else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }.joined(separator: "\n\n")
        let scroll = NSTextView.scrollableTextView()
        if let view = scroll.documentView as? NSTextView {
            view.isEditable = false
            view.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            view.textContainerInset = NSSize(width: 14, height: 14)
            view.string = text.isEmpty ? "Sero includes open-source software under the MIT licence." : text
        }
        let made = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
                            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        made.title = "Acknowledgements"
        made.isReleasedWhenClosed = false
        made.contentView = scroll
        made.center()
        made.makeKeyAndOrderFront(nil)
        window = made
    }
}
