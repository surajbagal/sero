# Sero

A small, fast, quiet web browser for the Mac.

Sero is built on **WebKit**, the engine already inside every Mac. There's no
second copy of Chromium to download, update and keep in memory, so the app is
about 14 MB and opens instantly.

By Suraj Bagal · macOS 14 or later · free · open source

---

## What it does

- **One field.** Type an address and you go there; type words and you search.
  It finishes addresses from your own history and sends nothing until you
  press Return.
- **Tabs that stay out of the way.** Down the left or across the top. Pin the
  pages you keep open all day. Tabs from your last session come back
  instantly and cost nothing until you click them. `⌘K` finds an open tab by
  name.
- **An ad blocker that runs before the page.** Trackers and ad networks are
  stopped inside WebKit's networking, so there's nothing to render. On by
  default, off per site.
- **Hide anything, for good.** `⇧⌘H`, then click a cookie banner or an
  overlay, and it stays gone on that site.
- **Reading mode** (`⇧⌘R`), **video that floats** above everything (`⇧⌘P`),
  and **Split View** for two pages side by side.
- **Passwords in your keychain.** Sero offers to save a sign-in once it has
  worked, and can bring passwords over from Chrome, Arc, Brave, Edge and
  others. Nothing leaves your Mac.
- **Chrome extensions without Chrome** (macOS 15.4 or later), on WebKit's own
  extension engine.
- **Bookmarks, history and downloads**, each a searchable panel one keystroke
  away. Light, dark, or the Mac's own.
- **Marketing tools** (new in Sero, off until you turn them on in Settings ›
  Browsing › Pages). `⌥⇧⌘M` opens a panel for the page in front:
  - **SEO**: title and description length, headings, canonical, robots,
    hreflang, alt text, links, structured data and social tags.
  - **Tags**: which of GTM, GA4, Google Ads, Meta, LinkedIn, TikTok,
    Microsoft, Pinterest, Snap, X, Hotjar and Clarity are on the page, the
    hits they send, and the dataLayer. One click lets a site's tags through
    the ad blocker, for testing.
  - **SERP**: Google's results as someone in a chosen city sees them,
    numbered, your domain outlined, saved as CSV.

## Privacy

There's no account, no telemetry, no analytics and no crash reports sent
anywhere. Sero has no server.

What leaves your Mac: the pages you ask for and their icons; the Chrome Web
Store, when you add an extension and when Sero checks the ones you have for
updates; and, only once you turn them on in Settings, suggestions from your
search engine as you type, an AI provider when you ask it something, and
Handoff of the page in front to your other Apple devices. History, bookmarks and settings stay in
`~/Library/Application Support/Sero/`; passwords stay in the macOS keychain.

A **private tab** (`⇧⌘N`) has its own cookie jar and leaves nothing behind
when it closes.

## Getting Sero

There's no ready-made download yet. For now, build it yourself (below); it
takes a few minutes.

When there are downloads on the
[Releases](https://github.com/surajbagal/sero/releases) page, note that Sero
isn't notarised by Apple, so macOS blocks the first launch. Open
**System Settings › Privacy & Security** and click **Open Anyway**. You only
need to do this once.

Because Sero isn't signed with a paid Apple Developer ID, a few features of
the original need entitlements it can't have: **Sync with iCloud** (use the
folder sync in Settings › General › Sync and other devices instead),
**passkeys** in web pages, and **automatic updates**.

## Building it

You need macOS 14 or later and Xcode 16 or later.

```bash
git clone https://github.com/surajbagal/sero.git
cd sero
./build.sh
open build/Sero.app
```

`./build.sh` makes `build/Sero.app`, ad-hoc signed so it runs on your own Mac.
`swift build` and `swift test` work too.

The code is Swift, with SwiftUI for the interface, AppKit where SwiftUI
doesn't reach, and WKWebView for pages, with no dependencies beyond what
Apple ships. `Sources/Sero/` is one file per concern: `Vault.swift` is the
keychain, `Shield.swift` the ad blocker, `Session.swift` what comes back at
launch, `MarketingPanel.swift` the marketing tools, and so on.
[CONTRIBUTING.md](CONTRIBUTING.md) covers building and testing.

## Contributing

Issues and pull requests are welcome at
[github.com/surajbagal/sero](https://github.com/surajbagal/sero/issues).
Small, focused changes; no new dependencies; nothing that phones home. Found a
security problem? Please report it privately, as [SECURITY.md](SECURITY.md)
describes.

## License

MIT. See [LICENSE](LICENSE), and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the open-source components
Sero includes. Sero › About Sero › Acknowledgements shows the same in the app.
