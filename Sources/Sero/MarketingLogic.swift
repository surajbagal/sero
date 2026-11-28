import Foundation

// Sero's marketing tools (MarketingPanel.swift): the parts that are only
// reading — what a page's SEO facts mean, which marketing tag a request
// belongs to, how Google is asked for results "as if from" a city, and the
// CSV a results page is saved as. Nothing here touches a page or the
// network, so the unit tests can hold all of it.

// MARK: - SEO

/// One line of the SEO tab: what was found, and whether it is fine.
struct SEOCheck: Equatable, Identifiable {
    enum Level: Int, Comparable {
        case good, info, warn, bad
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    let id: String
    let title: String
    let value: String
    let level: Level
    let note: String
}

/// What the page script reports (MarketingPanel.seoScript), read into
/// checks. Lengths follow what Google shows before cutting a line off:
/// about 30–60 characters of title and 70–160 of description.
enum SEOReport {
    static func checks(from facts: [String: Any]) -> [SEOCheck] {
        var out: [SEOCheck] = []
        let title = (facts["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        switch title.count {
        case 0:
            out.append(.init(id: "title", title: "Title", value: "Missing", level: .bad, note: "Every page needs a <title>."))
        case 1..<30:
            out.append(.init(id: "title", title: "Title", value: title, level: .warn, note: "\(title.count) characters: short. Aim for 30–60."))
        case 30...60:
            out.append(.init(id: "title", title: "Title", value: title, level: .good, note: "\(title.count) characters."))
        default:
            out.append(.init(id: "title", title: "Title", value: title, level: .warn, note: "\(title.count) characters: Google may cut it off after about 60."))
        }

        let description = (facts["description"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        switch description.count {
        case 0:
            out.append(.init(id: "description", title: "Meta description", value: "Missing", level: .warn, note: "Google writes its own snippet without one."))
        case 1..<70:
            out.append(.init(id: "description", title: "Meta description", value: description, level: .warn, note: "\(description.count) characters: short. Aim for 70–160."))
        case 70...160:
            out.append(.init(id: "description", title: "Meta description", value: description, level: .good, note: "\(description.count) characters."))
        default:
            out.append(.init(id: "description", title: "Meta description", value: description, level: .warn, note: "\(description.count) characters: may be cut off after about 160."))
        }

        let h1s = facts["h1"] as? [String] ?? []
        switch h1s.count {
        case 0: out.append(.init(id: "h1", title: "H1", value: "Missing", level: .bad, note: "The page has no main heading."))
        case 1: out.append(.init(id: "h1", title: "H1", value: h1s[0], level: .good, note: "One main heading."))
        default: out.append(.init(id: "h1", title: "H1", value: h1s.joined(separator: " · "), level: .warn, note: "\(h1s.count) H1s: one is clearer."))
        }

        let robots = (facts["robots"] as? String ?? "").lowercased()
        if robots.contains("noindex") {
            out.append(.init(id: "robots", title: "Robots", value: robots, level: .bad, note: "noindex: search engines are told not to list this page."))
        } else if robots.contains("nofollow") {
            out.append(.init(id: "robots", title: "Robots", value: robots, level: .warn, note: "nofollow: links on this page pass nothing on."))
        } else {
            out.append(.init(id: "robots", title: "Robots", value: robots.isEmpty ? "Not set (index, follow)" : robots, level: .good, note: "Search engines may list this page."))
        }

        let canonical = facts["canonical"] as? String ?? ""
        let address = facts["url"] as? String ?? ""
        if canonical.isEmpty {
            out.append(.init(id: "canonical", title: "Canonical", value: "Missing", level: .warn, note: "Without one, copies of this page can compete with it."))
        } else if !canonical.hasPrefix("http") {
            out.append(.init(id: "canonical", title: "Canonical", value: canonical, level: .warn, note: "Relative: an absolute address is safer."))
        } else if strip(canonical) != strip(address) {
            out.append(.init(id: "canonical", title: "Canonical", value: canonical, level: .info, note: "Points to another address: this page defers to it."))
        } else {
            out.append(.init(id: "canonical", title: "Canonical", value: canonical, level: .good, note: "Points to this page."))
        }

        let lang = facts["lang"] as? String ?? ""
        out.append(.init(id: "lang", title: "Language", value: lang.isEmpty ? "Not set" : lang,
                         level: lang.isEmpty ? .warn : .good, note: lang.isEmpty ? "Add lang to <html>." : "From <html lang>."))

        let viewport = facts["viewport"] as? String ?? ""
        out.append(.init(id: "viewport", title: "Mobile viewport", value: viewport.isEmpty ? "Missing" : viewport,
                         level: viewport.isEmpty ? .bad : .good, note: viewport.isEmpty ? "Phones will show the desktop layout, shrunk." : "Set for phones."))

        let hreflang = facts["hreflang"] as? [String] ?? []
        if !hreflang.isEmpty {
            out.append(.init(id: "hreflang", title: "hreflang", value: hreflang.joined(separator: ", "), level: .info, note: "\(hreflang.count) language versions."))
        }

        let images = facts["images"] as? Int ?? 0
        let noAlt = facts["imagesNoAlt"] as? Int ?? 0
        if images > 0 {
            out.append(.init(id: "alt", title: "Image alt text", value: noAlt == 0 ? "All \(images) have it" : "\(noAlt) of \(images) missing",
                             level: noAlt == 0 ? .good : .warn, note: noAlt == 0 ? "" : "Alt text helps image search and screen readers."))
        }

        let words = facts["words"] as? Int ?? 0
        out.append(.init(id: "words", title: "Words", value: "\(words)", level: words < 300 ? .warn : .good,
                         note: words < 300 ? "Under 300: may read as thin content." : ""))

        let inside = facts["linksInternal"] as? Int ?? 0
        let external = facts["linksExternal"] as? Int ?? 0
        let nofollow = facts["linksNofollow"] as? Int ?? 0
        out.append(.init(id: "links", title: "Links", value: "\(inside) internal · \(external) external",
                         level: .info, note: nofollow > 0 ? "\(nofollow) marked nofollow or sponsored." : ""))

        let schema = facts["schema"] as? [String] ?? []
        let schemaErrors = facts["schemaErrors"] as? Int ?? 0
        if schemaErrors > 0 {
            out.append(.init(id: "schema", title: "Structured data", value: schema.isEmpty ? "Unreadable" : schema.joined(separator: ", "),
                             level: .bad, note: "\(schemaErrors) JSON-LD block\(schemaErrors == 1 ? "" : "s") won't parse."))
        } else {
            out.append(.init(id: "schema", title: "Structured data", value: schema.isEmpty ? "None" : schema.joined(separator: ", "),
                             level: schema.isEmpty ? .info : .good, note: schema.isEmpty ? "No JSON-LD found." : "JSON-LD types."))
        }

        let ogTitle = facts["ogTitle"] as? String ?? ""
        let ogImage = facts["ogImage"] as? String ?? ""
        let twitter = facts["twitterCard"] as? String ?? ""
        let social: SEOCheck.Level = ogTitle.isEmpty || ogImage.isEmpty ? .warn : .good
        out.append(.init(id: "social", title: "Social sharing", value: ogImage.isEmpty ? "No og:image" : "og:image set",
                         level: social, note: [ogTitle.isEmpty ? "No og:title." : nil, twitter.isEmpty ? "No twitter:card." : "twitter:card \(twitter)."]
                            .compactMap { $0 }.joined(separator: " ")))
        return out
    }

    /// An address with what doesn't change the page taken off, for telling
    /// whether a canonical points back to it.
    static func strip(_ address: String) -> String {
        var text = address.lowercased()
        if let hash = text.firstIndex(of: "#") { text = String(text[..<hash]) }
        if text.hasSuffix("/") { text.removeLast() }
        return text.replacingOccurrences(of: "://www.", with: "://")
    }

    /// The headings, in order, as "H2  Text", for the outline.
    static func outline(from facts: [String: Any]) -> [String] {
        (facts["headings"] as? [[String: Any]] ?? []).compactMap { item in
            guard let level = item["level"] as? Int, let text = item["text"] as? String else { return nil }
            return String(repeating: "   ", count: max(0, level - 1)) + "H\(level)  " + text
        }
    }
}

// MARK: - Tags

/// A marketing tag installed on the page, with the ids it was set up with.
struct TagFound: Equatable, Identifiable, Hashable {
    let vendor: String
    let ids: [String]
    var id: String { vendor }
}

/// One request a tag sent: who to, which account, which event.
struct TagHit: Equatable, Identifiable, Hashable {
    let vendor: String
    let account: String
    let event: String
    let detail: String
    let url: String
    var id: String { url + event }
}

enum TagHits {
    /// The vendors the Tags tab names, and the window globals or script
    /// addresses that show each is on a page (MarketingPanel.tagScript).
    static let vendors = [
        "Google Tag Manager", "Google Analytics 4", "Google Ads", "Meta Pixel", "LinkedIn Insight",
        "TikTok Pixel", "Microsoft UET", "Pinterest Tag", "Snap Pixel", "X Pixel", "Hotjar", "Microsoft Clarity",
    ]

    /// The request a tag sends, read: nil for one that isn't a known tag's.
    /// `body` is a POST's text when the page script caught it.
    static func parse(url text: String, body: String? = nil) -> [TagHit] {
        guard let url = URL(string: text), let host = url.host?.lowercased() else { return [] }
        let path = url.path.lowercased()
        let query = params(url.query)

        // GA4: /g/collect, one event in the address, or several in the body,
        // a line each.
        if (host.hasSuffix("google-analytics.com") || host == "analytics.google.com"), path.hasSuffix("/g/collect") {
            let account = query["tid"] ?? ""
            let lines = (body ?? "").split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            if lines.isEmpty {
                return [TagHit(vendor: "Google Analytics 4", account: account, event: query["en"] ?? "hit",
                               detail: query["dl"] ?? "", url: text)]
            }
            return lines.enumerated().map { index, line in
                let one = params(line)
                return TagHit(vendor: "Google Analytics 4", account: account, event: one["en"] ?? query["en"] ?? "hit",
                              detail: query["dl"] ?? "", url: text + "#\(index)")
            }
        }
        // Google Ads conversions and remarketing: the AW id is in the path.
        if host.hasSuffix("googleadservices.com") || host == "googleads.g.doubleclick.net" || host.hasSuffix("google.com"),
           path.contains("/pagead/conversion") || path.contains("/pagead/viewthroughconversion") || path.contains("/ccm/collect") {
            let number = url.pathComponents.last(where: { $0.allSatisfy(\.isNumber) && !$0.isEmpty }) ?? ""
            let label = query["label"].map { " · label \($0)" } ?? ""
            let event = path.contains("viewthrough") ? "remarketing" : "conversion"
            return [TagHit(vendor: "Google Ads", account: number.isEmpty ? "" : "AW-\(number)", event: event,
                           detail: (query["value"].map { "value \($0)" } ?? "") + label, url: text)]
        }
        if host.hasSuffix("facebook.com") || host.hasSuffix("facebook.net"), path == "/tr" || path == "/tr/" {
            return [TagHit(vendor: "Meta Pixel", account: query["id"] ?? "", event: query["ev"] ?? "hit",
                           detail: query["dl"] ?? "", url: text)]
        }
        if host == "px.ads.linkedin.com" || host == "dc.ads.linkedin.com" {
            let account = query["pid"] ?? ""
            let event = query["conversionId"].map { "conversion \($0)" } ?? "page view"
            return [TagHit(vendor: "LinkedIn Insight", account: account, event: event, detail: query["url"] ?? "", url: text)]
        }
        if host.hasSuffix("analytics.tiktok.com"), path.contains("/pixel") {
            var account = query["sdkid"] ?? ""
            var event = "hit"
            if let data = body?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                event = json["event"] as? String ?? event
                if let context = json["context"] as? [String: Any], let pixel = context["pixel"] as? [String: Any] {
                    account = pixel["code"] as? String ?? account
                }
            }
            return [TagHit(vendor: "TikTok Pixel", account: account, event: event, detail: "", url: text)]
        }
        if host == "bat.bing.com", path.hasPrefix("/action") {
            return [TagHit(vendor: "Microsoft UET", account: query["ti"] ?? "", event: query["evt"] ?? "hit",
                           detail: query["ea"] ?? "", url: text)]
        }
        if host == "ct.pinterest.com" {
            return [TagHit(vendor: "Pinterest Tag", account: query["tid"] ?? "", event: query["event"] ?? "hit", detail: "", url: text)]
        }
        if host == "tr.snapchat.com" || host == "tr-shadow.snapchat.com" {
            return [TagHit(vendor: "Snap Pixel", account: query["pid"] ?? "", event: query["ev"] ?? "hit", detail: "", url: text)]
        }
        if (host == "analytics.twitter.com" || host == "t.co"), path.contains("adsct") {
            return [TagHit(vendor: "X Pixel", account: query["txn_id"] ?? "", event: query["events"] ?? "hit", detail: "", url: text)]
        }
        return []
    }

    /// A query string's pairs, decoded. A key given twice keeps its first.
    static func params(_ query: String?) -> [String: String] {
        guard let query, !query.isEmpty else { return [:] }
        var out: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard let key = parts.first?.removingPercentEncoding, !key.isEmpty, out[key] == nil else { continue }
            let value = parts.count > 1 ? parts[1].replacingOccurrences(of: "+", with: " ") : ""
            out[key] = value.removingPercentEncoding ?? value
        }
        return out
    }

    /// What the page script found installed, read: vendors with their ids,
    /// in the order of `vendors`, each id once.
    static func found(from facts: [String: Any]) -> [TagFound] {
        let tags = facts["tags"] as? [String: [String]] ?? [:]
        return vendors.compactMap { vendor in
            guard let ids = tags[vendor] else { return nil }
            var seen = Set<String>()
            return TagFound(vendor: vendor, ids: ids.filter { !$0.isEmpty && seen.insert($0).inserted })
        }
    }
}

// MARK: - Google results by location

/// A place Google can be asked to search from: its country code, the
/// language it is asked in, and the place's canonical name as Google's
/// geotargets list spells it (nil for the whole country).
struct SERPPlace: Hashable, Identifiable {
    let name: String
    let country: String
    let language: String
    let canonical: String?
    /// Where the place is, handed to Google as the browser's location
    /// (SERP.locationScript); nil for a whole country.
    var latitude: Double? = nil
    var longitude: Double? = nil
    var id: String { country + "|" + name }
}

enum SERP {
    /// The places offered, by country, cities after their country.
    static let places: [SERPPlace] = [
        .init(name: "India", country: "IN", language: "en", canonical: nil),
        .init(name: "Mumbai", country: "IN", language: "en", canonical: "Mumbai,Maharashtra,India", latitude: 19.076, longitude: 72.8777),
        .init(name: "Delhi", country: "IN", language: "en", canonical: "New Delhi,Delhi,India", latitude: 28.6139, longitude: 77.209),
        .init(name: "Bengaluru", country: "IN", language: "en", canonical: "Bengaluru,Karnataka,India", latitude: 12.9716, longitude: 77.5946),
        .init(name: "Hyderabad", country: "IN", language: "en", canonical: "Hyderabad,Telangana,India", latitude: 17.385, longitude: 78.4867),
        .init(name: "Chennai", country: "IN", language: "en", canonical: "Chennai,Tamil Nadu,India", latitude: 13.0827, longitude: 80.2707),
        .init(name: "Kolkata", country: "IN", language: "en", canonical: "Kolkata,West Bengal,India", latitude: 22.5726, longitude: 88.3639),
        .init(name: "Pune", country: "IN", language: "en", canonical: "Pune,Maharashtra,India", latitude: 18.5204, longitude: 73.8567),
        .init(name: "Ahmedabad", country: "IN", language: "en", canonical: "Ahmedabad,Gujarat,India", latitude: 23.0225, longitude: 72.5714),
        .init(name: "United States", country: "US", language: "en", canonical: nil),
        .init(name: "New York", country: "US", language: "en", canonical: "New York,New York,United States", latitude: 40.7128, longitude: -74.006),
        .init(name: "Los Angeles", country: "US", language: "en", canonical: "Los Angeles,California,United States", latitude: 34.0522, longitude: -118.2437),
        .init(name: "Chicago", country: "US", language: "en", canonical: "Chicago,Illinois,United States", latitude: 41.8781, longitude: -87.6298),
        .init(name: "San Francisco", country: "US", language: "en", canonical: "San Francisco,California,United States", latitude: 37.7749, longitude: -122.4194),
        .init(name: "United Kingdom", country: "GB", language: "en", canonical: nil),
        .init(name: "London", country: "GB", language: "en", canonical: "London,England,United Kingdom", latitude: 51.5074, longitude: -0.1278),
        .init(name: "Manchester", country: "GB", language: "en", canonical: "Manchester,England,United Kingdom", latitude: 53.4808, longitude: -2.2426),
        .init(name: "Canada", country: "CA", language: "en", canonical: nil),
        .init(name: "Toronto", country: "CA", language: "en", canonical: "Toronto,Ontario,Canada", latitude: 43.6532, longitude: -79.3832),
        .init(name: "Australia", country: "AU", language: "en", canonical: nil),
        .init(name: "Sydney", country: "AU", language: "en", canonical: "Sydney,New South Wales,Australia", latitude: -33.8688, longitude: 151.2093),
        .init(name: "United Arab Emirates", country: "AE", language: "en", canonical: nil),
        .init(name: "Dubai", country: "AE", language: "en", canonical: "Dubai,Dubai,United Arab Emirates", latitude: 25.2048, longitude: 55.2708),
        .init(name: "Singapore", country: "SG", language: "en", canonical: nil, latitude: 1.3521, longitude: 103.8198),
        .init(name: "Germany", country: "DE", language: "de", canonical: nil),
        .init(name: "Berlin", country: "DE", language: "de", canonical: "Berlin,Berlin,Germany", latitude: 52.52, longitude: 13.405),
        .init(name: "France", country: "FR", language: "fr", canonical: nil),
        .init(name: "Paris", country: "FR", language: "fr", canonical: "Paris,Ile-de-France,France", latitude: 48.8566, longitude: 2.3522),
        .init(name: "Spain", country: "ES", language: "es", canonical: nil),
        .init(name: "Brazil", country: "BR", language: "pt", canonical: nil),
        .init(name: "Japan", country: "JP", language: "ja", canonical: nil),
    ]

    /// A script for the page's own world, at document start, that answers
    /// the page's location questions with this place: navigator.geolocation
    /// gives these coordinates and the permission reads as granted, so
    /// Google takes them as the browser's precise location, over the one it
    /// guesses from the network. Only on Google's own pages.
    static func locationScript(latitude: Double, longitude: Double) -> String {
        """
        (() => {
          if (!/(^|\\.)google\\.[a-z.]+$/.test(location.hostname)) return;
          // What happened, for the bench to read: installed, asked, pressed.
          const note = { installed: Date.now(), asked: 0, permission: 0, pressed: "", found: 0 };
          try { Object.defineProperty(window, "__seroGeo", { value: note, enumerable: false }); } catch (e) {}
          const coords = { latitude: \(latitude), longitude: \(longitude), accuracy: 25, altitude: null,
                           altitudeAccuracy: null, heading: null, speed: null };
          const where = () => ({ coords, timestamp: Date.now() });
          // Google fetches the location after the page is drawn and uses it
          // from its next page on: the first time it asks in this tab, the
          // page is loaded again, once, so the results follow the place.
          const settle = () => {
            try {
              if (sessionStorage.getItem("seroPlaced")) return;
              sessionStorage.setItem("seroPlaced", "1");
              note.reloaded = true;
              setTimeout(() => location.reload(), 1800);
            } catch (e) {}
          };
          const geo = {
            getCurrentPosition(ok) { note.asked++; setTimeout(() => ok(where()), 5); settle(); },
            watchPosition(ok) { note.asked++; setTimeout(() => ok(where()), 5); settle(); return 1; },
            clearWatch() {}
          };
          try { Object.defineProperty(Navigator.prototype, "geolocation", { get() { return geo; }, configurable: true }); } catch (e) {}
          // A switch for testing from the bench: "1" leaves the page's own
          // answer to whether location is allowed.
          let realPermission = false;
          try { realPermission = localStorage.getItem("seroGeoRealPermission") === "1"; } catch (e) {}
          if (!realPermission) try {
            const ask = navigator.permissions && navigator.permissions.query.bind(navigator.permissions);
            if (ask) navigator.permissions.query = d => (d && d.name === "geolocation" && ++note.permission)
              ? Promise.resolve({ name: "geolocation", state: "granted", onchange: null, addEventListener() {}, removeEventListener() {} })
              : ask(d);
          } catch (e) {}
          // Google guesses from the network until it is asked to use the
          // browser's location: its "Use precise location" pressed once in
          // this tab, so these coordinates are what it takes.
          const press = () => {
            try {
              if (sessionStorage.getItem("seroLocated")) return;
              const found = [...document.querySelectorAll('[role="button"], button, a, span, div')]
                .filter(e => /^\\s*use precise location\\s*$/i.test(e.textContent || ""));
              note.found = found.length;
              const button = found.pop();
              if (!button) { note.pressed = note.pressed || "no button"; return; }
              note.pressed = "pressed";
              sessionStorage.setItem("seroLocated", "1");
              (button.closest('[role="button"], button, a') || button).click();
            } catch (e) {}
          };
          addEventListener("load", () => { setTimeout(press, 800); setTimeout(press, 2500); });
        })();
        """
    }

    /// Google's `uule` value for a place: its canonical name, base64, after
    /// a fixed prefix and a letter that says how long the name is.
    static func uule(for canonical: String) -> String? {
        let key = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        let bytes = Array(canonical.utf8)
        guard !bytes.isEmpty, bytes.count < key.count else { return nil }
        return "w+CAIQICI" + String(key[bytes.count]) + Data(bytes).base64EncodedString()
    }

    /// Google's results for `query` as someone in `place` would see them,
    /// without the results tuned to whoever is signed in (pws=0).
    static func url(for query: String, in place: SERPPlace, language: String? = nil) -> URL? {
        let words = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return nil }
        var parts = URLComponents(string: "https://www.google.com/search")
        var items = [
            URLQueryItem(name: "q", value: words),
            URLQueryItem(name: "gl", value: place.country.lowercased()),
            URLQueryItem(name: "hl", value: language ?? place.language),
            URLQueryItem(name: "pws", value: "0"),
        ]
        if let canonical = place.canonical, let code = uule(for: canonical) {
            items.append(URLQueryItem(name: "uule", value: code))
        }
        parts?.queryItems = items
        // URLComponents leaves "+" alone, and Google reads it as a space.
        let encoded = parts?.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        parts?.percentEncodedQuery = encoded
        return parts?.url
    }

    /// The host a result is on, without www, for matching your domain.
    static func domain(of address: String) -> String {
        let host = URL(string: address)?.host?.lowercased() ?? ""
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Whether a result's host is `wanted` or under it.
    static func matches(_ address: String, _ wanted: String) -> Bool {
        let want = wanted.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !want.isEmpty else { return false }
        let host = domain(of: address)
        return host == want || host.hasSuffix("." + want)
    }
}

/// One organic result, numbered as it appears.
struct SERPResult: Equatable, Identifiable {
    let position: Int
    let title: String
    let url: String
    var id: Int { position }
    var domain: String { SERP.domain(of: url) }
}

enum CSV {
    /// Rows as CSV, every field quoted, quotes doubled (RFC 4180).
    static func text(_ rows: [[String]]) -> String {
        rows.map { row in
            row.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",")
        }.joined(separator: "\r\n") + "\r\n"
    }

    static func results(_ results: [SERPResult], query: String, place: String) -> String {
        text([["Position", "Title", "URL", "Domain", "Query", "Location"]]
             + results.map { ["\($0.position)", $0.title, $0.url, $0.domain, query, place] })
    }
}
