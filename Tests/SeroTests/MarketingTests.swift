import XCTest
@testable import Sero

/// Sero's marketing tools (MarketingLogic.swift): SEO facts read into
/// checks, tag requests read into hits, Google asked "as if from" a city,
/// and results saved as CSV. No page, no network.
final class MarketingTests: XCTestCase {

    // MARK: SEO

    private func check(_ id: String, in facts: [String: Any]) -> SEOCheck? {
        SEOReport.checks(from: facts).first { $0.id == id }
    }

    func testTitleLengthIsJudgedAsGoogleShowsIt() {
        XCTAssertEqual(check("title", in: [:])?.level, .bad)
        XCTAssertEqual(check("title", in: ["title": "Short"])?.level, .warn)
        XCTAssertEqual(check("title", in: ["title": "Running Shoes for Men – Free Delivery | Shop"])?.level, .good)
        XCTAssertEqual(check("title", in: ["title": String(repeating: "word ", count: 20)])?.level, .warn)
    }

    func testDescriptionAndHeadings() {
        XCTAssertEqual(check("description", in: [:])?.level, .warn)
        XCTAssertEqual(check("description", in: ["description": String(repeating: "a", count: 120)])?.level, .good)
        XCTAssertEqual(check("h1", in: ["h1": [String]()])?.level, .bad)
        XCTAssertEqual(check("h1", in: ["h1": ["One"]])?.level, .good)
        XCTAssertEqual(check("h1", in: ["h1": ["One", "Two"]])?.level, .warn)
    }

    func testNoindexAndCanonical() {
        XCTAssertEqual(check("robots", in: ["robots": "noindex, follow"])?.level, .bad)
        XCTAssertEqual(check("robots", in: [:])?.level, .good)
        XCTAssertEqual(check("canonical", in: ["url": "https://www.shop.com/a/", "canonical": "https://shop.com/a"])?.level, .good)
        XCTAssertEqual(check("canonical", in: ["url": "https://shop.com/a?x=1", "canonical": "https://shop.com/b"])?.level, .info)
        XCTAssertEqual(check("canonical", in: ["canonical": "/a"])?.level, .warn)
        XCTAssertEqual(check("canonical", in: [:])?.level, .warn)
    }

    func testStructuredDataAltTextAndOutline() {
        XCTAssertEqual(check("schema", in: ["schema": ["Product", "BreadcrumbList"]])?.value, "Product, BreadcrumbList")
        XCTAssertEqual(check("schema", in: ["schemaErrors": 1])?.level, .bad)
        XCTAssertEqual(check("alt", in: ["images": 10, "imagesNoAlt": 3])?.value, "3 of 10 missing")
        XCTAssertNil(check("alt", in: ["images": 0]))
        XCTAssertEqual(SEOReport.outline(from: ["headings": [["level": 1, "text": "Shoes"], ["level": 2, "text": "Sizes"]]]),
                       ["H1  Shoes", "   H2  Sizes"])
    }

    // MARK: Tags

    func testGA4HitInTheAddressAndInABatch() {
        let single = TagHits.parse(url: "https://www.google-analytics.com/g/collect?v=2&tid=G-ABC123&en=page_view&dl=https%3A%2F%2Fshop.com%2F")
        XCTAssertEqual(single.count, 1)
        XCTAssertEqual(single.first?.vendor, "Google Analytics 4")
        XCTAssertEqual(single.first?.account, "G-ABC123")
        XCTAssertEqual(single.first?.event, "page_view")
        XCTAssertEqual(single.first?.detail, "https://shop.com/")

        let batch = TagHits.parse(url: "https://region1.google-analytics.com/g/collect?v=2&tid=G-ABC123",
                                  body: "en=scroll&epn.percent_scrolled=90\nen=add_to_cart")
        XCTAssertEqual(batch.map(\.event), ["scroll", "add_to_cart"])
        XCTAssertEqual(Set(batch.map(\.id)).count, 2, "each event of a batch is its own hit")
    }

    func testAdsMetaLinkedInTikTokAndOthers() {
        let ads = TagHits.parse(url: "https://www.googleadservices.com/pagead/conversion/123456789/?label=abcDEF&value=49.0")
        XCTAssertEqual(ads.first?.account, "AW-123456789")
        XCTAssertEqual(ads.first?.event, "conversion")

        let meta = TagHits.parse(url: "https://www.facebook.com/tr/?id=1122334455&ev=Purchase&dl=https%3A%2F%2Fshop.com")
        XCTAssertEqual(meta.first?.vendor, "Meta Pixel")
        XCTAssertEqual(meta.first?.event, "Purchase")
        XCTAssertEqual(meta.first?.account, "1122334455")

        let linkedIn = TagHits.parse(url: "https://px.ads.linkedin.com/collect?pid=998877&conversionId=554433&fmt=gif")
        XCTAssertEqual(linkedIn.first?.event, "conversion 554433")

        let tiktok = TagHits.parse(url: "https://analytics.tiktok.com/api/v2/pixel",
                                   body: #"{"event":"CompletePayment","context":{"pixel":{"code":"CABC123"}}}"#)
        XCTAssertEqual(tiktok.first?.event, "CompletePayment")
        XCTAssertEqual(tiktok.first?.account, "CABC123")

        XCTAssertEqual(TagHits.parse(url: "https://bat.bing.com/action/0?ti=5566&evt=pageLoad").first?.vendor, "Microsoft UET")
        XCTAssertTrue(TagHits.parse(url: "https://shop.com/api/cart").isEmpty)
        XCTAssertTrue(TagHits.parse(url: "not a url").isEmpty)
    }

    func testQueryPairsAreDecodedAndInstalledTagsListedOnce() {
        XCTAssertEqual(TagHits.params("a=1&b=two+words&c=%2Fx&a=2"), ["a": "1", "b": "two words", "c": "/x"])
        let found = TagHits.found(from: ["tags": ["Meta Pixel": ["1", "1", ""], "Google Tag Manager": ["GTM-XYZ"]]])
        XCTAssertEqual(found.map(\.vendor), ["Google Tag Manager", "Meta Pixel"], "in the panel's own order")
        XCTAssertEqual(found.last?.ids, ["1"])
    }

    // MARK: SERP

    func testUuleIsGooglesLocationCode() {
        XCTAssertEqual(SERP.uule(for: "Mumbai,Maharashtra,India"), "w+CAIQICIYTXVtYmFpLE1haGFyYXNodHJhLEluZGlh")
        XCTAssertEqual(SERP.uule(for: "London,England,United Kingdom"), "w+CAIQICIdTG9uZG9uLEVuZ2xhbmQsVW5pdGVkIEtpbmdkb20=")
        XCTAssertNil(SERP.uule(for: ""))
    }

    func testSearchAddressCarriesCountryLanguageAndCity() throws {
        let mumbai = try XCTUnwrap(SERP.places.first { $0.name == "Mumbai" })
        let url = try XCTUnwrap(SERP.url(for: "best c++ course", in: mumbai))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value }
        XCTAssertEqual(url.host, "www.google.com")
        XCTAssertEqual(value("q"), "best c++ course", "a plus stays a plus, not a space")
        XCTAssertEqual(value("gl"), "in")
        XCTAssertEqual(value("hl"), "en")
        XCTAssertEqual(value("pws"), "0")
        XCTAssertEqual(value("uule"), SERP.uule(for: "Mumbai,Maharashtra,India"))

        let india = try XCTUnwrap(SERP.places.first { $0.name == "India" })
        XCTAssertNil(URLComponents(url: try XCTUnwrap(SERP.url(for: "shoes", in: india)), resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "uule" }, "a whole country needs no city")
        XCTAssertNil(SERP.url(for: "   ", in: india))
    }

    func testCitiesCarryCoordinatesAndCountriesDont() throws {
        let pune = try XCTUnwrap(SERP.places.first { $0.name == "Pune" })
        XCTAssertEqual(pune.latitude ?? 0, 18.52, accuracy: 0.01)
        XCTAssertEqual(pune.longitude ?? 0, 73.86, accuracy: 0.01)
        XCTAssertNil(SERP.places.first { $0.name == "India" }?.latitude)
        XCTAssertTrue(SERP.places.filter { $0.canonical != nil }.allSatisfy { $0.latitude != nil },
                      "every city can be handed to Google as a location")
    }

    func testLocationScriptAnswersOnlyOnGoogleWithThePlace() {
        let script = SERP.locationScript(latitude: 18.5204, longitude: 73.8567)
        XCTAssertTrue(script.contains("latitude: 18.5204"))
        XCTAssertTrue(script.contains("longitude: 73.8567"))
        XCTAssertTrue(script.contains(#"/(^|\.)google\.[a-z.]+$/"#), "Google's own pages only")
        XCTAssertTrue(script.contains(#"state: "granted""#))
        XCTAssertTrue(script.contains("use precise location"), "Google is asked to use it")
        XCTAssertTrue(script.contains("location.reload()") && script.contains("seroPlaced"),
                      "loaded again once, so the results follow the place")
    }

    func testDomainMatchingAndCSV() {
        XCTAssertTrue(SERP.matches("https://www.shop.com/shoes", "shop.com"))
        XCTAssertTrue(SERP.matches("https://blog.shop.com/a", "https://www.shop.com/"))
        XCTAssertFalse(SERP.matches("https://notshop.com/", "shop.com"))
        XCTAssertFalse(SERP.matches("https://shop.com/", ""))

        let csv = CSV.results([SERPResult(position: 1, title: #"Shoes "Sale""#, url: "https://shop.com/a")],
                              query: "shoes, men", place: "Mumbai")
        XCTAssertEqual(csv, "\"Position\",\"Title\",\"URL\",\"Domain\",\"Query\",\"Location\"\r\n"
                       + "\"1\",\"Shoes \"\"Sale\"\"\",\"https://shop.com/a\",\"shop.com\",\"shoes, men\",\"Mumbai\"\r\n")
    }
}
