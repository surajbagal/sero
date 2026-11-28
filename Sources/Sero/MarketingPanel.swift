import AppKit
import CoreLocation
import SwiftUI
import WebKit

// Sero's marketing tools: View › Marketing… (⌥⇧⌘M), once Settings ›
// Browsing › Pages › Marketing tools is on. A small floating panel beside
// the window, for the tab in front:
//
// - SEO: the page's title, description, headings, canonical, robots,
//   hreflang, alt text, words, links, structured data and social tags,
//   read in Sero's own script world (Web.world), so the page can't see it.
// - Tags: which marketing tags the page has (GTM, GA4, Google Ads, Meta,
//   LinkedIn, TikTok and others) and the hits they send. Read in the page's
//   own world, where the tags live: its globals, the requests it has made
//   (resource timing), and, from the first look on, fetch, XHR and
//   sendBeacon as they go, kept in the page until it is left. Sero's ad
//   blocker stops most of these tags on purpose; the tab says so and can
//   turn the blocker off for that one site (the same switch as the site
//   card's), so a client's tags can be tested.
// - SERP: Google's results as someone in a chosen city would see them
//   (gl, hl, uule; pws=0), numbered on the page, your domain outlined,
//   saved as CSV.
//
// Nothing here sends anything anywhere: the SERP tab opens a Google search
// in a tab, as typing it would.

@MainActor
final class MarketingModel: ObservableObject {
    static let shared = MarketingModel()

    enum Pane: String, CaseIterable, Identifiable {
        case seo = "SEO", tags = "Tags", serp = "SERP"
        var id: String { rawValue }
    }

    @Published var pane: Pane = .seo { didSet { refresh() } }
    @Published private(set) var pageTitle = ""
    @Published private(set) var pageHost = ""
    @Published private(set) var message: String?

    @Published private(set) var checks: [SEOCheck] = []
    @Published private(set) var outline: [String] = []

    @Published private(set) var found: [TagFound] = []
    @Published private(set) var hits: [TagHit] = []
    @Published private(set) var dataLayer = ""
    @Published private(set) var hasDataLayer = false
    @Published private(set) var blockerOn = false

    @Published var query = ""
    @Published var placeID = SERP.places[1].id
    @Published var domain = Store.settings.string(forKey: "marketing.domain") ?? "" {
        didSet { Store.settings.set(domain, forKey: "marketing.domain") }
    }
    /// A place typed in, as Google's geotargets name it ("Lohegaon,
    /// Maharashtra,India"), used over the list's when there is one.
    @Published var customPlace = Store.settings.string(forKey: "marketing.customPlace") ?? "" {
        didSet { Store.settings.set(customPlace, forKey: "marketing.customPlace") }
    }
    /// The search in a private tab: its own empty cookie jar, so no
    /// location Google keeps in your cookies, and nothing of your account.
    @Published var searchesPrivately = Store.settings.object(forKey: "marketing.private") as? Bool ?? true {
        didSet { Store.settings.set(searchesPrivately, forKey: "marketing.private") }
    }
    @Published private(set) var results: [SERPResult] = []
    @Published private(set) var searchedFor = ""

    weak var browser: Browser?
    private var timer: Timer?
    /// The location script for each tab a SERP check opened (Tab.arm asks).
    private static var placed: [Tab.ID: String] = [:]
    static func placeScript(for tab: Tab.ID) -> String? { placed[tab] }
    /// Where the last search was placed, and its tab, for the bench.
    private(set) var lastCoordinates: (Double, Double)?
    private(set) var lastTab: Tab.ID?
    private var opening: ((URL) -> Tab)?
    private var cleared = Set<String>()
    private var lastPage: URL?

    var place: SERPPlace {
        let picked = SERP.places.first { $0.id == placeID } ?? SERP.places[0]
        let typed = customPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return picked }
        return SERPPlace(name: typed.components(separatedBy: ",").first ?? typed, country: picked.country,
                         language: picked.language, canonical: typed)
    }
    private var front: Browser { browser ?? Browsers.frontBrowser }
    private var tab: Tab? { front.active }

    /// The tab in front, read again for the pane showing.
    func refresh() {
        guard let tab, tab.isWeb, let page = tab.built else {
            pageTitle = ""
            pageHost = ""
            message = "Open a web page to check it."
            checks = []; outline = []; found = []; hits = []; dataLayer = ""; results = []
            return
        }
        let address = tab.pageAddress
        if address != lastPage { cleared = []; lastPage = address }
        pageTitle = page.title ?? ""
        pageHost = address?.host ?? ""
        message = nil
        blockerOn = Shield.shared.enabled && !Shield.shared.isPaused(on: address?.host)
        switch pane {
        case .seo: readSEO(page)
        case .tags: readTags(page)
        case .serp: if address?.host?.contains("google.") == true { markResults() }
        }
    }

    /// While the panel is up: Tags again every two seconds, so hits show
    /// as they're sent; the other panes when the tab in front changes.
    func watch(_ on: Bool) {
        timer?.invalidate()
        timer = nil
        guard on else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.pane == .tags || self.tab?.pageAddress != self.lastPage { self.refresh() }
            }
        }
    }

    // MARK: SEO

    private func readSEO(_ page: PageView) {
        page.callAsyncJavaScript(MarketingModel.seoScript, arguments: [:], in: nil, in: Web.world) { [weak self] result in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch result {
                case .success(let value):
                    let facts = value as? [String: Any] ?? [:]
                    self.checks = SEOReport.checks(from: facts)
                    self.outline = SEOReport.outline(from: facts)
                case .failure:
                    self.message = "This page couldn't be read."
                }
            }
        }
    }

    // MARK: Tags

    private func readTags(_ page: PageView) {
        page.callAsyncJavaScript(MarketingModel.tagScript, arguments: [:], in: nil, in: .page) { [weak self] result in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard case .success(let value) = result, let facts = value as? [String: Any] else {
                    self.message = "This page couldn't be read."
                    return
                }
                self.found = TagHits.found(from: facts)
                var seen = Set<String>()
                let raw = facts["hits"] as? [[String: Any]] ?? []
                self.hits = raw.flatMap { TagHits.parse(url: $0["url"] as? String ?? "", body: $0["body"] as? String) }
                    .filter { !self.cleared.contains($0.id) && seen.insert($0.id).inserted }
                    .reversed()
                self.dataLayer = facts["dataLayer"] as? String ?? ""
                self.hasDataLayer = facts["hasDataLayer"] as? Bool ?? false
            }
        }
    }

    func clearHits() {
        cleared.formUnion(hits.map(\.id))
        hits = []
    }

    /// Sero's ad blocker off (or on again) for this site, as the site
    /// card's switch does, and the page loaded again so the tags can run.
    func allowTags(_ allow: Bool) {
        guard let host = tab?.pageAddress?.host else { return }
        Shield.shared.pause(host, allow)
        cleared = []
        front.reload()
        blockerOn = !allow && Shield.shared.enabled
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    // MARK: SERP

    /// `privately` nil: as the panel's switch says. The bench passes false,
    /// so the tab is one it can read.
    func searchGoogle(privately: Bool? = nil, opening: ((URL) -> Tab)? = nil) {
        self.opening = opening
        let privately = privately ?? searchesPrivately
        let place = self.place
        guard let url = SERP.url(for: query, in: place) else { return }
        searchedFor = query
        results = []
        message = nil
        if let latitude = place.latitude, let longitude = place.longitude {
            open(url, at: (latitude, longitude), privately: privately)
        } else if let typed = place.canonical, SERP.places.allSatisfy({ $0.canonical != typed }) {
            // A place typed in: its coordinates from the Mac's own geocoder.
            message = "Finding \(place.name)…"
            CLGeocoder().geocodeAddressString(typed.replacingOccurrences(of: ",", with: ", ")) { [weak self] marks, _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let found = marks?.first?.location?.coordinate
                    self.message = found == nil ? "Couldn't find \(place.name) on the map; searching by name only." : nil
                    self.open(url, at: found.map { ($0.latitude, $0.longitude) }, privately: privately)
                }
            }
            return
        } else {
            open(url, at: nil, privately: privately)
        }
    }

    /// The search in its tab, private or not, with the place's coordinates
    /// handed to Google from the first page on.
    private func open(_ url: URL, at coordinates: (Double, Double)?, privately: Bool) {
        let script = coordinates.map { SERP.locationScript(latitude: $0.0, longitude: $0.1) }
        lastCoordinates = coordinates
        if let opening {
            // The bench's own tab: placed before its first page.
            let tab = opening(URL(string: "about:blank")!)
            if let script { MarketingModel.placed[tab.id] = script }
            tab.go(to: url)
            lastTab = tab.id
            self.opening = nil
            return
        }
        if privately {
            front.openShy(url) { tab in
                if let script { MarketingModel.placed[tab.id] = script }
            }
        } else {
            let tab = front.open(url, foreground: true)
            if let script {
                MarketingModel.placed[tab.id] = script
                tab.rearm()
                tab.reload()
            }
        }
        // The results page has to load before it can be numbered, and with a
        // place it loads once more after Google has its coordinates
        // (SERP.locationScript): numbered each time, the last one kept. A
        // "prove you're not a robot" page in between leaves the tab's address
        // changing after it, which numbers it then (see watch).
        for delay in [2.5, 5.0, 8.0, 12.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                MainActor.assumeIsolated { self?.markResults() }
            }
        }
    }

    func markResults() {
        guard let page = tab?.built, tab?.pageAddress?.host?.contains("google.") == true else {
            message = "Search Google first, or open a Google results page."
            return
        }
        page.callAsyncJavaScript(MarketingModel.serpScript, arguments: ["domain": domain], in: nil, in: Web.world) { [weak self] result in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard case .success(let value) = result else {
                    if case .failure(let error) = result {
                        self.message = "Couldn't number this page: \(error.localizedDescription)"
                    }
                    return
                }
                let answer = value as? [String: Any] ?? [:]
                let rows = answer["results"] as? [[String: Any]] ?? []
                self.results = rows.compactMap { row in
                    guard let position = row["position"] as? Int, let url = row["url"] as? String else { return nil }
                    return SERPResult(position: position, title: row["title"] as? String ?? "", url: url)
                }
                let address = self.tab?.pageAddress?.absoluteString ?? ""
                if address.contains("/sorry/") {
                    self.message = "Google wants to check you're not a robot. Answer it in the page; the results are numbered once they show."
                } else if self.results.isEmpty {
                    let headings = answer["headings"] as? Int ?? 0
                    let area = answer["area"] as? String ?? "?"
                    let skipped = answer["skipped"] as? [String: Int] ?? [:]
                    let why = [("ads", skipped["ad"] ?? 0), ("without a link", skipped["noLink"] ?? 0),
                               ("Google's own", skipped["google"] ?? 0), ("repeats", skipped["again"] ?? 0)]
                        .filter { $0.1 > 0 }.map { "\($0.1) \($0.0)" }.joined(separator: ", ")
                    self.message = "No ordinary results found on this page yet (\(headings) titles in \(area)\(why.isEmpty ? "" : ": " + why)). Scroll or wait for it to finish, then press Number This Page."
                } else {
                    self.message = nil
                }
                if self.searchedFor.isEmpty, let q = self.tab?.pageAddress.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) })?
                    .queryItems?.first(where: { $0.name == "q" })?.value {
                    self.searchedFor = q
                }
            }
        }
    }

    var yourPositions: [Int] {
        results.filter { SERP.matches($0.url, domain) }.map(\.position)
    }

    func exportCSV() {
        guard !results.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        let safe = searchedFor.isEmpty ? "results" : searchedFor.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "Google – \(safe) – \(place.name).csv"
        guard panel.runModal() == .OK, let file = panel.url else { return }
        let text = CSV.results(results, query: searchedFor, place: place.name)
        do {
            try text.write(to: file, atomically: true, encoding: .utf8)
        } catch {
            message = "Couldn't save: \(error.localizedDescription)"
        }
    }

    // MARK: - page scripts

    /// The SEO facts, read in Sero's world.
    static let seoScript = #"""
    const meta = n => { const e = document.querySelector(`meta[name="${n}" i]`); return e ? (e.content || "") : ""; };
    const prop = n => { const e = document.querySelector(`meta[property="${n}" i]`); return e ? (e.content || "") : ""; };
    const words = e => (e.innerText || e.textContent || "").replace(/\s+/g, " ").trim();
    const headings = [...document.querySelectorAll("h1,h2,h3,h4,h5,h6")].slice(0, 300)
        .map(h => ({ level: +h.tagName[1], text: words(h).slice(0, 160) })).filter(h => h.text);
    const host = location.hostname.replace(/^www\./, "");
    let internal = 0, external = 0, nofollow = 0;
    for (const a of document.querySelectorAll("a[href]")) {
        let u; try { u = new URL(a.href); } catch (e) { continue; }
        if (!/^https?:$/.test(u.protocol)) continue;
        const h = u.hostname.replace(/^www\./, "");
        if (h === host || h.endsWith("." + host)) internal++; else external++;
        if (/nofollow|sponsored|ugc/i.test(a.rel || "")) nofollow++;
    }
    const images = [...document.images];
    const schema = []; let schemaErrors = 0;
    const types = v => {
        if (!v) return;
        if (Array.isArray(v)) return v.forEach(types);
        if (typeof v === "object") {
            if (v["@type"]) [].concat(v["@type"]).forEach(t => schema.push(String(t)));
            if (v["@graph"]) types(v["@graph"]);
        }
    };
    for (const s of document.querySelectorAll('script[type="application/ld+json"]')) {
        try { types(JSON.parse(s.textContent)); } catch (e) { schemaErrors++; }
    }
    const canonical = document.querySelector('link[rel="canonical"]');
    const text = document.body ? (document.body.innerText || "") : "";
    return {
        url: location.href, title: document.title, description: meta("description"), robots: meta("robots"),
        canonical: canonical ? (canonical.getAttribute("href") || "") : "", lang: document.documentElement.lang || "",
        viewport: meta("viewport"),
        hreflang: [...document.querySelectorAll('link[rel="alternate"][hreflang]')].map(l => l.hreflang),
        h1: headings.filter(h => h.level === 1).map(h => h.text), headings,
        images: images.length, imagesNoAlt: images.filter(i => !i.hasAttribute("alt")).length,
        words: (text.match(/\S+/g) || []).length,
        linksInternal: internal, linksExternal: external, linksNofollow: nofollow,
        schema: [...new Set(schema)], schemaErrors,
        ogTitle: prop("og:title"), ogImage: prop("og:image"), twitterCard: meta("twitter:card")
    };
    """#

    /// The tags and their hits, read in the page's own world. The first
    /// call leaves a small recorder in the page (window.__seroTagHits) for
    /// fetch, XHR and sendBeacon; it goes when the page does.
    static let tagScript = #"""
    const T = {};
    const add = (v, id) => { (T[v] = T[v] || []); if (id !== undefined && id !== null && id !== "") T[v].push(String(id)); };
    let gtm = [];
    try { gtm = window.google_tag_manager ? Object.keys(window.google_tag_manager) : []; } catch (e) {}
    gtm.filter(k => /^GTM-/.test(k)).forEach(k => add("Google Tag Manager", k));
    gtm.filter(k => /^G-/.test(k)).forEach(k => add("Google Analytics 4", k));
    gtm.filter(k => /^AW-/.test(k)).forEach(k => add("Google Ads", k));
    for (const s of document.scripts) {
        if (!s.src) continue;
        let u; try { u = new URL(s.src); } catch (e) { continue; }
        const h = u.hostname, id = u.searchParams.get("id") || "";
        if (/googletagmanager\.com$/.test(h)) {
            if (/^GTM-/.test(id)) add("Google Tag Manager", id);
            else if (/^G-/.test(id)) add("Google Analytics 4", id);
            else if (/^AW-/.test(id)) add("Google Ads", id);
        }
        if (/connect\.facebook\.net$/.test(h)) add("Meta Pixel");
        if (/snap\.licdn\.com$/.test(h)) add("LinkedIn Insight");
        if (/analytics\.tiktok\.com$/.test(h)) add("TikTok Pixel", u.searchParams.get("sdkid"));
        if (/bat\.bing\.com$/.test(h)) add("Microsoft UET");
        if (/s\.pinimg\.com$/.test(h) && /\/ct\/|pinit/.test(u.pathname)) add("Pinterest Tag");
        if (/sc-static\.net$/.test(h)) add("Snap Pixel");
        if (/static\.ads-twitter\.com$/.test(h)) add("X Pixel");
        if (/static\.hotjar\.com$/.test(h)) add("Hotjar");
        if (/clarity\.ms$/.test(h)) add("Microsoft Clarity", /^\/tag\//.test(u.pathname) ? u.pathname.split("/").pop() : null);
    }
    try {
        if (window.fbq) {
            add("Meta Pixel");
            const st = typeof fbq.getState === "function" ? fbq.getState() : null;
            if (st && st.pixels) st.pixels.forEach(p => add("Meta Pixel", p.id));
        }
    } catch (e) {}
    try { if (window._linkedin_data_partner_ids) [].concat(window._linkedin_data_partner_ids).forEach(i => add("LinkedIn Insight", i)); } catch (e) {}
    try { if (window._linkedin_partner_id) add("LinkedIn Insight", window._linkedin_partner_id); } catch (e) {}
    try { if (window.ttq) { add("TikTok Pixel"); if (ttq._i) Object.keys(ttq._i).forEach(k => add("TikTok Pixel", k)); } } catch (e) {}
    if (window.uetq) add("Microsoft UET");
    if (window.pintrk) add("Pinterest Tag");
    if (window.snaptr) add("Snap Pixel");
    if (window.twq) add("X Pixel");
    try { if (window._hjSettings) add("Hotjar", window._hjSettings.hjid); } catch (e) {}
    if (window.clarity) add("Microsoft Clarity");

    if (!window.__seroTagHits) {
        const list = [];
        Object.defineProperty(window, "__seroTagHits", { value: list, enumerable: false });
        try { performance.setResourceTimingBufferSize(1000); } catch (e) {}
        const keep = (u, b) => {
            try {
                list.push({ url: new URL(String(u), location.href).href, body: typeof b === "string" ? b.slice(0, 20000) : "" });
                if (list.length > 500) list.shift();
            } catch (e) {}
        };
        const f = window.fetch;
        if (f) window.fetch = function (input, init) {
            try { keep(typeof input === "string" ? input : (input && input.url) || "", init && init.body); } catch (e) {}
            return f.apply(this, arguments);
        };
        if (navigator.sendBeacon) {
            const beacon = navigator.sendBeacon.bind(navigator);
            navigator.sendBeacon = function (u, d) { keep(u, d); return beacon(u, d); };
        }
        const open = XMLHttpRequest.prototype.open, send = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function (m, u) { this.__seroURL = u; return open.apply(this, arguments); };
        XMLHttpRequest.prototype.send = function (b) { keep(this.__seroURL || "", b); return send.apply(this, arguments); };
    }
    const hits = performance.getEntriesByType("resource").map(e => ({ url: e.name, body: "" })).concat(window.__seroTagHits);
    let dataLayer = "";
    try {
        const held = new WeakSet();
        dataLayer = JSON.stringify((window.dataLayer || []).slice(-40), (k, v) => {
            if (typeof v === "function") return "ƒ";
            if (v && typeof v === "object") {
                if (typeof Node !== "undefined" && v instanceof Node) return "[element]";
                if (held.has(v)) return "[…]";
                held.add(v);
            }
            return v;
        }, 2);
    } catch (e) {}
    return { tags: T, hits, dataLayer, hasDataLayer: Array.isArray(window.dataLayer) };
    """#

    /// Google's organic results numbered in place, `domain`'s outlined;
    /// returned in order. Ads (#tads) are skipped. Run again, it starts over.
    static let serpScript = #"""
    const want = (domain || "").toLowerCase().trim().replace(/^https?:\/\//, "").replace(/^www\./, "").replace(/\/.*$/, "");
    document.querySelectorAll(".sero-pos").forEach(e => e.remove());
    document.querySelectorAll("[data-sero-hit]").forEach(e => { e.style.outline = ""; e.style.outlineOffset = ""; e.removeAttribute("data-sero-hit"); });
    const out = [], seen = new Set();
    const skipped = { ad: 0, noLink: 0, google: 0, again: 0 };
    const root = document.querySelector("#rso") || document.querySelector("#search") || document.querySelector("#center_col") || document.body;
    // A result's title: an <h3>, or, in Google's newer layouts, an element
    // marked as a level-3 heading, or the heading-like line inside a
    // result's link.
    const titles = new Set();
    const look = r => r.querySelectorAll('h3, [role="heading"][aria-level="3"], a[href] [role="heading"]').forEach(t => titles.add(t));
    look(root);
    const more = document.querySelector("#botstuff");
    if (more && root.id === "rso") look(more);
    const ordered = [...titles].filter(t => ![...titles].some(o => o !== t && o.contains(t)))
        .sort((a, b) => a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1);
    for (const h3 of ordered) {
        const box = h3.closest("[data-hveid], .MjjYud, .g") || h3.parentElement;
        const a = h3.closest("a[href]") || (box && box.querySelector("a[href]"));
        if (!a) { skipped.noLink++; continue; }
        if (a.closest("#tads, #tadsb, #bottomads, [data-text-ad], [aria-label='Ads'], [aria-label='Sponsored']")) { skipped.ad++; continue; }
        let u; try { u = new URL(a.href); } catch (e) { skipped.noLink++; continue; }
        if (/(^|\.)google\./.test(u.hostname)) {
            const inner = u.searchParams.get("url") || u.searchParams.get("q");
            let ok = false;
            if (inner) { try { const v = new URL(inner); if (/^https?:$/.test(v.protocol) && !/(^|\.)google\./.test(v.hostname)) { u = v; ok = true; } } catch (e) {} }
            // Google's newer pages link through /goto?url=<a code>: the site
            // shows only in the address line under the title, "https://www.
            // practo.com › Pune", read back into an address.
            if (!ok && /^\/(goto|url)$/.test(u.pathname)) {
                const holder = h3.closest(".MjjYud, [data-hveid]") || box;
                const cite = holder && holder.querySelector("cite");
                const shown = cite ? (cite.innerText || cite.textContent || "").trim() : "";
                const parts = shown.split("›").map(x => x.trim()).filter(Boolean);
                if (parts.length) {
                    const base = /^https?:\/\//.test(parts[0]) ? parts[0] : "https://" + parts[0];
                    try {
                        const v = new URL(base);
                        if (!/(^|\.)google\./.test(v.hostname)) {
                            v.pathname = "/" + parts.slice(1).map(x => x.replace(/\s+/g, "-").replace(/\.{3}|…/g, "")).filter(Boolean).join("/");
                            u = v; ok = true;
                        }
                    } catch (e) {}
                }
            }
            if (!ok) { skipped.google++; continue; }
        }
        if (!/^https?:$/.test(u.protocol) || seen.has(u.href)) { skipped.again++; continue; }
        seen.add(u.href);
        const title = (h3.innerText || h3.textContent || "").trim();
        if (!title) { skipped.noLink++; continue; }
        const position = out.length + 1;
        const badge = document.createElement("span");
        badge.className = "sero-pos";
        badge.textContent = String(position);
        badge.style.cssText = "display:inline-block;min-width:22px;margin-right:8px;padding:1px 6px;border-radius:10px;background:#4a40ed;color:#fff;font:600 12px -apple-system,system-ui,sans-serif;text-align:center;vertical-align:middle;line-height:18px";
        h3.prepend(badge);
        const host = u.hostname.replace(/^www\./, "");
        if (want && (host === want || host.endsWith("." + want))) {
            const mark = a.closest("[data-hveid]") || box || a.parentElement;
            mark.setAttribute("data-sero-hit", "");
            mark.style.outline = "2px solid #4a40ed";
            mark.style.outlineOffset = "4px";
        }
        out.push({ position, title, url: u.href });
    }
    return { results: out, headings: ordered.length, skipped, area: root.id ? "#" + root.id : root.tagName.toLowerCase() };
    """#
}

// MARK: - the panel

@MainActor
enum MarketingPanel {
    private static var panel: NSPanel?
    private static var closing: NSObjectProtocol?

    /// The chart button, View › Marketing… and ⌥⇧⌘M: open, or put away if
    /// it is up.
    static func toggle(for browser: Browser) {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            MarketingModel.shared.watch(false)
            return
        }
        show(for: browser)
    }

    static func show(for browser: Browser) {
        let model = MarketingModel.shared
        model.browser = browser
        guard !Store.testing else { return }
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            model.refresh()
            model.watch(true)
            return
        }
        let host = NSHostingView(rootView: MarketingView(model: model))
        let made = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 640),
                           styleMask: [.titled, .closable, .resizable, .utilityWindow],
                           backing: .buffered, defer: false)
        made.title = "Marketing"
        made.isFloatingPanel = true
        made.hidesOnDeactivate = true
        made.isReleasedWhenClosed = false
        made.contentView = host
        made.minSize = NSSize(width: 360, height: 420)
        if let window = browser.window {
            let frame = window.frame
            made.setFrameTopLeftPoint(NSPoint(x: max(frame.minX, frame.maxX - 460), y: frame.maxY - 60))
        } else {
            made.center()
        }
        closing = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: made, queue: .main) { _ in
            MainActor.assumeIsolated { MarketingModel.shared.watch(false) }
        }
        made.makeKeyAndOrderFront(nil)
        panel = made
        model.refresh()
        model.watch(true)
    }
}

struct MarketingView: View {
    @ObservedObject var model: MarketingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.pageHost.isEmpty ? "No page" : model.pageHost)
                        .font(.headline)
                        .lineLimit(1)
                    if !model.pageTitle.isEmpty {
                        Text(model.pageTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Read the page in front again")
            }
            Picker("", selection: $model.pane) {
                ForEach(MarketingModel.Pane.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if let message = model.message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            switch model.pane {
            case .seo: SEOPane(model: model)
            case .tags: TagsPane(model: model)
            case .serp: SERPPane(model: model)
            }
        }
        .padding(14)
        .frame(minWidth: 360, minHeight: 420)
    }
}

private struct SEOPane: View {
    @ObservedObject var model: MarketingModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(model.checks) { check in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: icon(check.level))
                            .foregroundStyle(colour(check.level))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.title).font(.callout.weight(.semibold))
                            Text(check.value).font(.callout).lineLimit(3).textSelection(.enabled)
                            if !check.note.isEmpty {
                                Text(check.note).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if !model.outline.isEmpty {
                    DisclosureGroup("Headings (\(model.outline.count))") {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(model.outline.enumerated()), id: \.offset) { _, line in
                                Text(line).font(.system(.caption, design: .monospaced)).lineLimit(1)
                            }
                        }
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.callout.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func icon(_ level: SEOCheck.Level) -> String {
        switch level {
        case .good: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .bad: return "xmark.octagon.fill"
        }
    }

    private func colour(_ level: SEOCheck.Level) -> Color {
        switch level {
        case .good: return .green
        case .info: return .blue
        case .warn: return .orange
        case .bad: return .red
        }
    }
}

private struct TagsPane: View {
    @ObservedObject var model: MarketingModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !model.pageHost.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: model.blockerOn ? "shield.lefthalf.filled" : "shield.slash")
                            .foregroundStyle(model.blockerOn ? .orange : .secondary)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.blockerOn
                                 ? "Sero's ad blocker stops most marketing tags on \(model.pageHost). Allow them here to test this site's tags."
                                 : "Tags are allowed on \(model.pageHost).")
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                            Button(model.blockerOn ? "Allow Tags on This Site" : "Block Again") {
                                model.allowTags(model.blockerOn)
                            }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                }

                Text("Installed").font(.callout.weight(.semibold))
                if model.found.isEmpty {
                    Text("No marketing tags found.").font(.callout).foregroundStyle(.secondary)
                }
                ForEach(model.found) { tag in
                    HStack(alignment: .firstTextBaseline) {
                        Text(tag.vendor).font(.callout)
                        Spacer()
                        Text(tag.ids.isEmpty ? "present" : tag.ids.joined(separator: ", "))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.trailing)
                    }
                }

                HStack {
                    Text("Hits (\(model.hits.count))").font(.callout.weight(.semibold))
                    Spacer()
                    Button("Clear") { model.clearHits() }.disabled(model.hits.isEmpty)
                }
                if model.hits.isEmpty {
                    Text("Nothing sent yet. Click around the page; hits show here as they go.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(model.hits) { hit in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(hit.event).font(.callout.weight(.medium))
                            Spacer()
                            Text(hit.vendor).font(.caption).foregroundStyle(.secondary)
                        }
                        Text([hit.account, hit.detail].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .help(hit.url)
                    .contextMenu {
                        Button("Copy Request Address") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(hit.url, forType: .string)
                        }
                    }
                }

                if model.hasDataLayer {
                    DisclosureGroup("dataLayer") {
                        VStack(alignment: .leading, spacing: 6) {
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(model.dataLayer, forType: .string)
                            }
                            Text(model.dataLayer.isEmpty ? "[]" : model.dataLayer)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .font(.callout.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SERPPane: View {
    @ObservedObject var model: MarketingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Sero words", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.searchGoogle() }
            Picker("Searching from", selection: $model.placeID) {
                ForEach(SERP.places) { place in
                    Text(place.canonical == nil ? place.name : "    " + place.name).tag(place.id)
                }
            }
            TextField("Or a place as Google names it, e.g. Lohegaon,Maharashtra,India", text: $model.customPlace)
                .textFieldStyle(.roundedBorder)
            TextField("Your domain, to outline (optional)", text: $model.domain)
                .textFieldStyle(.roundedBorder)
            Toggle("Sero in a private tab (no location saved in your Google cookies)", isOn: $model.searchesPrivately)
                .font(.callout)
            HStack {
                Button("Search Google") { model.searchGoogle() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.query.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Number This Page") { model.markResults() }
                Spacer()
                Button("Export CSV…") { model.exportCSV() }.disabled(model.results.isEmpty)
            }
            if !model.results.isEmpty {
                Text(summary).font(.callout).foregroundStyle(.secondary)
            }
            List(model.results) { result in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(result.position)")
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .frame(width: 24, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(result.title).font(.callout).lineLimit(2)
                        Text(result.domain).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(SERP.matches(result.url, model.domain) ? Color.accentColor.opacity(0.15) : Color.clear)
            }
            .listStyle(.plain)
            Text("Keep the place out of the search words: Google uses a place you type (\"…in Lohegaon\") over the one picked here. It may still use your network's location.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summary: String {
        let mine = model.yourPositions
        let count = "\(model.results.count) results from \(model.place.name)"
        guard !model.domain.trimmingCharacters(in: .whitespaces).isEmpty else { return count }
        return mine.isEmpty ? count + " · \(model.domain) not on this page"
            : count + " · \(model.domain) at " + mine.map { "#\($0)" }.joined(separator: ", ")
    }
}
