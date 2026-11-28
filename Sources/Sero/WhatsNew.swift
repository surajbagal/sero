import SwiftUI

// What's new, once, after an update.
//
// New features start off, so someone who never opens Settings never meets
// them (a reply on X). The first time a newer version opens, a small card
// shows its new switches, each with a line of what it does and the switch
// itself, and — so nothing gets lost — the switches from earlier versions
// that are still off. Nothing else: few words. Closed, it
// doesn't come back for that version. Not after a fresh install: the welcome
// is for that. Every version's notes are in Settings › About › What's New…
//
// A release edits `toggles` (its new switches, marked with its version),
// `releases` (that it has a card) and `notes` (what it brought).
//
// A few switches lead: first on every card, above that version's own, for
// as long as they are off. Sync with iCloud and Handoff do, since 22 Nov
// 2026: on for a new install (SyncDefault.swift), offered here to everyone
// who had Sero before and never turned them on.

enum WhatsNew {
    /// A switch the card offers: the same setting as in Settings.
    struct Toggle {
        let title: String
        let detail: String
        /// The version it came in.
        let since: String
        let get: @MainActor (Preferences) -> Bool
        let set: @MainActor (Preferences, Bool) -> Void
        /// Whether it can do anything now: a switch that needs another one
        /// on stays off the card until it is.
        var shown: @MainActor (Preferences) -> Bool = { _ in true }
        /// First on every card while it is off, whatever its version.
        var lead = false
    }

    /// A version that has a card.
    struct Release {
        let version: String
    }

    /// Every switch worth meeting, the leading ones first, then oldest
    /// last. The card shows the leading ones still off, this version's, and
    /// the older ones still off. Only switches that are off unless turned
    /// on: the ones on for everyone who never touched them since 25 Nov 2026
    /// (HTTPS first, video keys, smooth wheel, the loading line, unread
    /// counts, swipe back closes, Home tiles, site styles, commands, Capture,
    /// pin folders) left the card then, so turning one off isn't asked about
    /// again.
    static let toggles: [Toggle] = [
        // Leading, in this order (see the top of this file).
        Toggle(title: "Sync with iCloud", detail: "Your tabs, pins and spaces on your iPhone and your other Macs, end-to-end encrypted.",
               since: "1.0.0", get: { _ in ICloudSync.shared.on },
               set: { _, on in on ? ICloudSync.shared.turnOnOrWait() : ICloudSync.shared.turnOff() },
               // Never beside the folder sync: the two would undo each other.
               shown: { _ in ICloudSync.shared.on || !Sync.shared.on }, lead: true),
        Toggle(title: "Handoff to your iPhone", detail: "The page in front comes up in your iPhone's and iPad's app switcher.",
               since: "1.0.0", get: { $0.handoff }, set: { $0.handoff = $1 }, lead: true),
    ] + (AI.shipped ? [
        Toggle(title: "AI on pages", detail: "Summarize a page or ask about it. Choose where it runs in Settings › AI.",
               since: "1.0.0", get: { $0.ai }, set: { $0.ai = $1 }),
    ] : []) + [
        Toggle(title: "Double click to rename", detail: "Click on the tab you're on to rename it, as Rename in its menu does, instead of editing its address.",
               since: "1.0.0", get: { $0.tabClickRenames }, set: { $0.tabClickRenames = $1 },
               shown: { !$0.iconColumn }),

        Toggle(title: "Backspace goes back", detail: "⌫ goes back a page and ⇧⌫ forward, when you aren't typing in a field.",
               since: "1.0.0", get: { $0.backspaceGoesBack }, set: { $0.backspaceGoesBack = $1 }),

        Toggle(title: "Hide the page behind the field", detail: "⌘T's and ⌘L's field over a plain ground, the page out of sight instead of dimmed.",
               since: "1.0.0", get: { $0.fieldHidesPage }, set: { $0.fieldHidesPage = $1 }),

        Toggle(title: "Return takes the top suggestion", detail: "Return goes to the place on top of the field's list as you type, as in Arc's command bar; ↑ lets go of it.",
               since: "1.0.0", get: { $0.returnTakesTop }, set: { $0.returnTakesTop = $1 }),

        Toggle(title: "Links from pins open in a new tab", detail: "A link clicked in a pinned tab opens in a tab of its own, and the pin stays on its page.",
               since: "1.0.0", get: { $0.pinLinksOpenTabs }, set: { $0.pinLinksOpenTabs = $1 }),

        Toggle(title: "Keep the window when its last tab closes", detail: "⌘W on the last, empty tab leaves it there, as in Arc; ⇧⌘W still closes the window.",
               since: "1.0.0", get: { $0.keepWindowAfterLast }, set: { $0.keepWindowAfterLast = $1 }),

        Toggle(title: "Clicking the tab you're on keeps its name", detail: "With the address bar always shown, the address is edited there or with ⌘L.",
               since: "1.0.0", get: { $0.tabClickKeepsName }, set: { $0.tabClickKeepsName = $1 },
               shown: { $0.addressLine && !$0.iconColumn && !$0.tabClickRenames }),

        Toggle(title: "Fade scroll bars", detail: "Thin bars over the page that come up as it scrolls and fade when it stops, even with a mouse.",
               since: "1.0.0", get: { $0.scrollbarsFade }, set: { $0.scrollbarsFade = $1 }),

        Toggle(title: "Update ready, in the window", detail: "When a new version is waiting, \"Update ready\" and Restart at the foot of the sidebar, or a pill by the tabs. On; × hides it until the next one.",
               since: "1.0.0", get: { $0.showsUpdateReady }, set: { $0.showsUpdateReady = $1 }),

        Toggle(title: "Bookmarks bar only on new tabs", detail: "The bookmarks bar above a new tab only, gone once a page opens, as in Chrome and Edge.",
               since: "1.0.0", get: { $0.bookmarksNewTabOnly }, set: { $0.bookmarksNewTabOnly = $1 },
               shown: { $0.bookmarksBar && !$0.sideBookmarks }),

        Toggle(title: "Bookmarks bar in the sidebar", detail: "The bookmarks bar at the top of the sidebar, in every space.",
               since: "1.0.0", get: { $0.bookmarksInSidebar }, set: { $0.bookmarksInSidebar = $1 }),
        Toggle(title: "The field in the middle of the window", detail: "⌘T's and ⌘L's field centred on the window and higher up, as in Arc.",
               since: "1.0.0", get: { $0.fieldOnWindow }, set: { $0.fieldOnWindow = $1 }),
        Toggle(title: "Click the tab you're on to edit its address", detail: "Without the site card.",
               since: "1.0.0", get: { $0.tabClickAddressOnly }, set: { $0.tabClickAddressOnly = $1 },
               shown: { $0.iconColumn || !($0.tabClickRenames || $0.tabClickKeepsName && $0.addressLine) }),
        Toggle(title: "Touch ID before filling a password", detail: "Touch ID, or your Mac's password, before a saved password goes into a page.",
               since: "1.0.0", get: { $0.asksBeforeFilling }, set: { $0.asksBeforeFilling = $1 }),
        Toggle(title: "Icons only on the bookmarks bar", detail: "Each bookmark its site's icon, its name on hover. Folders keep their names.",
               since: "1.0.0", get: { $0.bookmarksIconsOnly }, set: { $0.bookmarksIconsOnly = $1 }),

        Toggle(title: "Sidebar button", detail: "Beside the window's buttons, it hides the sidebar as ⌘S does.",
               since: "1.0.0", get: { $0.foldButton }, set: { $0.foldButton = $1 }),
        Toggle(title: "Narrow to icons", detail: "Pull the sidebar narrower and it becomes a strip of site icons.",
               since: "1.0.0", get: { $0.narrowsToIcons }, set: { $0.narrowsToIcons = $1 }),

        Toggle(title: "⌘T finds your open tabs", detail: "As you type in ⌘T's field, a matching open tab or pin comes first.",
               since: "1.0.0", get: { $0.arcTabPopup }, set: { $0.arcTabPopup = $1 },
               shown: { $0.floatingNewTab }),
        Toggle(title: "One button per space", detail: "Every space beside the bookmarks, one click away.",
               since: "1.0.0", get: { $0.spaceButtons }, set: { $0.spaceButtons = $1 },
               shown: { $0.usesSpaces }),

        Toggle(title: "Always show the address bar", detail: "The page's full address stays in sight, to type in.",
               since: "1.0.0", get: { $0.addressLine }, set: { $0.addressLine = $1 }),
        Toggle(title: "Glass window", detail: "The column and the window's edge as frosted glass over your desktop.",
               since: "1.0.0", get: { $0.glass }, set: { $0.glass = $1 }),
        Toggle(title: "Buttons at the top", detail: "The column's bottom buttons beside back, forward and reload.",
               since: "1.0.0", get: { $0.doorsUp }, set: { $0.doorsUp = $1 }),
        Toggle(title: "Ask which space a link opens in", detail: "For links from other apps.",
               since: "1.0.0", get: { $0.asksSpaceForLinks }, set: { $0.asksSpaceForLinks = $1 }),
        Toggle(title: "Dim sleeping tabs", detail: "A tab put to sleep fades until you come back to it.",
               since: "1.0.0", get: { $0.dimsSleepingTabs }, set: { $0.dimsSleepingTabs = $1 }),
        Toggle(title: "High contrast tab text", detail: "Tab titles in full black or white.",
               since: "1.0.0", get: { $0.highContrastText }, set: { $0.highContrastText = $1 }),

        Toggle(title: "⌘1–⌘9 switch spaces", detail: "As in Arc: the tabs move to ⌃1–⌃9.",
               since: "1.0.0", get: { $0.spacesOnCommand }, set: { $0.spacesOnCommand = $1 },
               shown: { $0.usesSpaces }),
        Toggle(title: "Same tabs in every window", detail: "Every window lists the same open tabs, as Arc's sidebar does.",
               since: "1.0.0", get: { $0.mirrorsTabs }, set: { $0.mirrorsTabs = $1 }),
        Toggle(title: "⌥-click a link opens it in Split View", detail: "Beside the page you're reading.",
               since: "1.0.0", get: { $0.optionClickSplits }, set: { $0.optionClickSplits = $1 }),
        Toggle(title: "Bounce at the top and bottom", detail: "Pages stretch past their ends and spring back, as in Safari.",
               since: "1.0.0", get: { $0.bounces }, set: { $0.bounces = $1 }),
        Toggle(title: "Slide the column in and out", detail: "An eased slide for ⌘S and the column that hides.",
               since: "1.0.0", get: { $0.slidesColumn }, set: { $0.slidesColumn = $1 }),

        Toggle(title: "Keep the card in full screen", detail: "The page keeps its room and rounded corners when the window fills the screen.",
               since: "1.0.0", get: { $0.cardsInFullScreen }, set: { $0.cardsInFullScreen = $1 },
               shown: { $0.sidebar && $0.cards }),
        Toggle(title: "⌘-click on a pin opens a new tab", detail: "As in Arc, or takes a page that wandered off into the loose tabs.",
               since: "1.0.0", get: { $0.pinCommandOpensTab }, set: { $0.pinCommandOpensTab = $1 }),

        Toggle(title: "Send links to a space", detail: "Links to the sites you choose open in their space, with its sign-ins, as in Arc.",
               since: "1.0.0", get: { $0.sendsLinksToSpaces }, set: { $0.sendsLinksToSpaces = $1 },
               shown: { $0.usesSpaces }),

        Toggle(title: "Profiles in one window", detail: "A space of another profile opens in the same window, with that profile's sign-ins, as in Arc.",
               since: "1.0.0", get: { $0.profilesInOneWindow }, set: { $0.profilesInOneWindow = $1 }),

        Toggle(title: "Close goes back", detail: "Closing the tab you're on takes you to the one you were on before it, as ⌃Tab would.",
               since: "1.0.0", get: { $0.closeGoesBack }, set: { $0.closeGoesBack = $1 }),

        Toggle(title: "Your Apple passwords", detail: "Accounts from Apple's Passwords app under the sign-in field, with a code from your Mac.",
               since: "1.0.0", get: { $0.applePasswords }, set: { $0.applePasswords = $1 }),
        Toggle(title: "Ask before quitting", detail: "⌘Q asks first, so a slip doesn't close every window.",
               since: "1.0.0", get: { $0.confirmsQuit }, set: { $0.confirmsQuit = $1 }),
        Toggle(title: "Tab numbers while ⌘ is held", detail: "See which tab ⌘1–⌘9 goes to.",
               since: "1.0.0", get: { $0.showsTabShortcuts }, set: { $0.showsTabShortcuts = $1 }),
        Toggle(title: "A column of icons only", detail: "The tabs as icons down the side, nothing that grows under the pointer.",
               since: "1.0.0", get: { $0.sideIcons }, set: { $0.sideIcons = $1 }),
        Toggle(title: "Escape twice to leave full screen", detail: "One Escape stays with the page, a second leaves full screen.",
               since: "1.0.0", get: { $0.escapeTwice }, set: { $0.escapeTwice = $1 }),

        Toggle(title: "Suggestions from your search engine", detail: "Searches suggested as you type. What you type is sent to your engine; never from a private tab.",
               since: "1.0.0", get: { $0.engineSuggests }, set: { $0.engineSuggests = $1 }),
        Toggle(title: "Pins keep their site", detail: "Links elsewhere open in a peek, and ⌘W takes a pin back to its page, as in Arc.",
               since: "1.0.0", get: { $0.pinsKeepSite }, set: { $0.pinsKeepSite = $1 }),
        Toggle(title: "Darken light pages", detail: "While Sero is dark, pages with no dark look of their own are darkened.",
               since: "1.0.0", get: { $0.darkensPages }, set: { $0.darkensPages = $1 }),
        Toggle(title: "Roomier tabs", detail: "Taller rows and larger titles in the sidebar.",
               since: "1.0.0", get: { $0.roomyTabs }, set: { $0.roomyTabs = $1 }),
        Toggle(title: "New tab in a floating field", detail: "⌘T raises the address field over the page you are on, as in Arc.",
               since: "1.0.0", get: { $0.floatingNewTab }, set: { $0.floatingNewTab = $1 }),

        Toggle(title: "Pinned rows", detail: "Pins as rows with their names, under the squares, as in Arc. Right-click a tab to pin it as a row.",
               since: "1.0.0", get: { $0.listsPins }, set: { $0.listsPins = $1 }),
        Toggle(title: "Start with a fresh window", detail: "Your pinned tabs, tab groups and named tabs, and none of last time's others.",
               since: "1.0.0", get: { $0.startsFresh }, set: { $0.startsFresh = $1 }),

        Toggle(title: "Sidebar on the right", detail: "The tabs down the right edge of the window.",
               since: "1.0.0", get: { $0.sidebar && $0.sidePosition == .right },
               set: { prefs, on in
                   if on { prefs.sidebar = true }
                   prefs.sidePosition = on ? .right : .left
               }),
        Toggle(title: "Videos wait for a click", detail: "Videos don't start by themselves, even without sound.",
               since: "1.0.0", get: { $0.waitsForPlay }, set: { $0.waitsForPlay = $1 }),
        Toggle(title: "Always show the downloads button", detail: "Your downloads one click away, beside the other buttons.",
               since: "1.0.0", get: { $0.alwaysShowsDownloads }, set: { $0.alwaysShowsDownloads = $1 }),

        Toggle(title: "Spaces", detail: "Separate sets of tabs, each with its own sign-ins. ⌃1–⌃9 to switch.",
               since: "1.0.0", get: { $0.usesSpaces }, set: { $0.usesSpaces = $1 }),
        Toggle(title: "A sidebar that hides", detail: "The page takes the whole window; the tabs come out at the edge.",
               since: "1.0.0", get: { $0.sidebar && $0.sideHides },
               set: { prefs, on in
                   if on { prefs.sidebar = true }
                   prefs.sideHides = on
               }),
        Toggle(title: "Bookmarks bar", detail: "Your bookmarks in a row above the page.",
               since: "1.0.0", get: { $0.bookmarksBar }, set: { $0.bookmarksBar = $1 }),
        Toggle(title: "Float the video when you switch apps", detail: "A playing video follows you out into a small window.",
               since: "1.0.0", get: { $0.floatsAway }, set: { prefs, on in if on { prefs.floatOwn = .tabsOrApps } else { prefs.floatsAway = false } }),
        Toggle(title: "Pages at 120 Hz", detail: "Smoother scrolling and animations on screens that can. Uses more battery.",
               since: "1.0.0", get: { $0.fastPages != .never }, set: { $0.fastPages = $1 ? .onPower : .never }),
        Toggle(title: "Scroll with the middle button", detail: "Click the wheel, then move the mouse to scroll, as on Windows.",
               since: "1.0.0", get: { $0.autoScroll }, set: { $0.autoScroll = $1 }),
    ]

    static let releases: [Release] = [
        Release(version: "1.0.0"),
    ]

    /// What a card opened now lists: first the leading switches still off,
    /// then the version's own; under their caption, the earlier ones still
    /// off.
    @MainActor static func rows(for release: Release, prefs: Preferences) -> (leading: [Toggle], own: [Toggle], earlier: [Toggle]) {
        (toggles.filter { $0.lead && !$0.get(prefs) && $0.shown(prefs) },
         toggles.filter { !$0.lead && $0.since == release.version && $0.shown(prefs) },
         toggles.filter { !$0.lead && older($0.since, than: release.version) && !$0.get(prefs) && $0.shown(prefs) })
    }

    /// This version's card, when it has one.
    static var current: Release? { releases.first { $0.version == Updater.version } }

    /// Version strings in order: 1.0.10 after 1.0.9.
    static func older(_ one: String, than other: String) -> Bool {
        let a = one.split(separator: ".").compactMap { Int($0) }
        let b = other.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    private static let seenKey = "whatsnew.seen"

    /// At launch, once: whether the card is due. Not on a fresh install (the
    /// welcome is up, and this version counts as seen), nor in a test world
    /// unless the bench asks; otherwise once per version that has a card.
    @MainActor static func due(prefs: Preferences, welcoming: Bool) -> Bool {
        let store = Store.settings
        guard let current, !Store.testing else { return false }
        if welcoming {
            store.set(current.version, forKey: seenKey)
            return false
        }
        guard store.string(forKey: seenKey) != current.version else { return false }
        store.set(current.version, forKey: seenKey)
        return true
    }

    /// Sero › What's New… and the About window's button: this
    /// version's card again, exactly as after an update, switches and all.
    /// Nothing is marked: the card was already seen once.
    @MainActor static func showAgain(in browser: Browser) {
        guard current != nil else { return }
        browser.newsShowing = true
    }

    // MARK: - every version's notes

    /// What a version brought, for Settings › About › What's New…
    struct Notes {
        let version: String
        let date: String
        /// A sentence or two: what the version is about.
        let headline: String
        let new: [String]
        let better: [String]
        let fixed: [String]
    }

    /// Newest first.
    static let notes: [Notes] = [
        Notes(
            version: "1.0.0", date: "28 November 2026",
            headline: "The first version of Sero: a small, fast, quiet browser for the Mac.",
            new: [
                "Tabs down the side or across the top, pinned tabs that keep their place, spaces and profiles with their own sign-ins, and one field for addresses and searches.",
                "An address bar across the top, with the tabs down the side, if you prefer it.",
                "Marketing tools: SEO checks, the marketing tags on a page and the hits they send, and Google's results as someone in a chosen city sees them.",
                "Ads and trackers blocked before they load; passwords in your keychain.",
                "Anything on a page can be hidden; articles open in a reading mode and videos float.",
                "Chrome extensions from the Chrome Web Store, on macOS 15.4 or later.",
                "It runs on the engine already in macOS.",
            ],
            better: [],
            fixed: []
        ),
    ]
}

/// The card: what's new in this version, its switches right there, and
/// the earlier ones still off.
struct WhatsNewCard: View {
    let release: WhatsNew.Release
    @ObservedObject var prefs: Preferences
    let close: () -> Void
    let notes: () -> Void
    /// A link from the card (the privacy page), opened in a tab.
    var open: (URL) -> Void = { NSWorkspace.shared.open($0) }

    /// The leading and earlier switches, read once as the card opens
    /// (WhatsNew.rows): one turned on here stays in the list rather than
    /// vanishing under the hand. The version's own are read as they stand.
    @State private var listed: (leading: [WhatsNew.Toggle], own: [WhatsNew.Toggle], earlier: [WhatsNew.Toggle])?
    /// Sync with iCloud's switch is its own, not a preference's.
    @ObservedObject private var icloud = ICloudSync.shared

    var body: some View {
        Plate("New in Sero \(release.version)", width: 460, close: close) {
            VStack(alignment: .leading, spacing: 14) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        rows((listed?.leading ?? []) + WhatsNew.rows(for: release, prefs: prefs).own)
                        if let earlier = listed?.earlier, !earlier.isEmpty {
                            Caption("From earlier versions, in case you missed them")
                                .padding(.top, 6)
                            rows(earlier)
                        }
                    }
                }
                .frame(maxHeight: 470)
                .fixedSize(horizontal: false, vertical: true)
            }
        } foot: {
            HStack {
                Button(action: notes) {
                    Text("Everything that's new…")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                .buttonStyle(.plain)
                Spacer()
                Pill("Close", filled: true, action: close)
            }
        }
        .onAppear {
            if listed == nil { listed = WhatsNew.rows(for: release, prefs: prefs) }
        }
    }

    private func rows(_ toggles: [WhatsNew.Toggle]) -> some View {
        Card {
            ForEach(Array(toggles.enumerated()), id: \.offset) { index, toggle in
                if index > 0 { Rule() }
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(toggle.title)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ink)
                        Text(toggle.detail)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Switch(on: Binding(get: { toggle.get(prefs) }, set: { toggle.set(prefs, $0) }))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }
}

/// Every version's notes, newest first: Settings › About › What's New…
struct ReleaseNotesPanel: View {
    let close: () -> Void

    var body: some View {
        Plate("What's New", width: 560, close: close) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(WhatsNew.notes, id: \.version) { note in
                        version(note)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .listHeight(480)
        }
    }

    private func version(_ note: WhatsNew.Notes) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Sero \(note.version)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                if !note.date.isEmpty {
                    Text(note.date)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.faint)
                }
            }
            Text(note.headline)
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            list("New", note.new)
            list("Better", note.better)
            list("Fixed", note.fixed)
        }
    }

    @ViewBuilder
    private func list(_ title: String, _ lines: [String]) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Palette.muted)
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(Palette.faint)
                        Text(line)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 12.5))
                }
            }
        }
    }
}
