import XCTest
@testable import BlotterCore

final class KeywordMatcherTests: XCTestCase {
    func testDefaultMatchingIgnoresCaseAndAccents() {
        XCTAssertEqual(KeywordMatcher.firstMatch(in: "A CAFÉ offer", keywords: ["cafe"], options: MatchOptions()), "cafe")
    }

    func testWholeWordsRejectLettersAndNumbersAroundKeyword() {
        for text in ["devoted", "voter", "αvoteβ", "vote1", "3vote"] {
            XCTAssertNil(KeywordMatcher.firstMatch(in: text, keywords: ["vote"], options: MatchOptions()), text)
        }
        XCTAssertEqual(KeywordMatcher.firstMatch(in: "Vote-now!", keywords: ["vote"], options: MatchOptions()), "vote")
    }

    func testSubstringMatchingCanBeEnabled() {
        var options = MatchOptions()
        options.wholeWords = false
        XCTAssertEqual(KeywordMatcher.firstMatch(in: "devoted", keywords: ["vote"], options: options), "vote")
    }

    func testCaseSensitiveSubstringMatchesTheDisplayedExample() {
        let options = MatchOptions(matchCase: true, matchAccents: false, wholeWords: false)
        XCTAssertEqual(KeywordMatcher.firstMatch(in: "devoted", keywords: ["vote"], options: options), "vote")
        XCTAssertNil(KeywordMatcher.firstMatch(in: "devoted", keywords: ["Vote"], options: options))
    }

    func testWholeWordSearchContinuesAfterAnEmbeddedMatch() {
        XCTAssertEqual(KeywordMatcher.firstMatch(in: "devoted? vote!", keywords: ["vote"], options: MatchOptions()), "vote")
    }

    func testCaseAndAccentOptionsAreIndependent() {
        var options = MatchOptions()
        options.matchCase = true
        XCTAssertNil(KeywordMatcher.firstMatch(in: "Vote", keywords: ["vote"], options: options))
        XCTAssertEqual(KeywordMatcher.firstMatch(in: "café", keywords: ["cafe"], options: options), "cafe")
        options.matchCase = false
        options.matchAccents = true
        XCTAssertNil(KeywordMatcher.firstMatch(in: "café", keywords: ["cafe"], options: options))
        XCTAssertEqual(KeywordMatcher.firstMatch(in: "CAFE", keywords: ["cafe"], options: options), "cafe")
    }

    func testPhrasesAndPunctuation() {
        XCTAssertEqual(KeywordMatcher.firstMatch(in: "A limited offer, today.", keywords: ["limited offer"], options: MatchOptions()), "limited offer")
        XCTAssertEqual(KeywordMatcher.firstMatch(in: "Save $5 today", keywords: ["$5"], options: MatchOptions()), "$5")
    }

    func testNonmatchesAndEmptyInputReturnNoMatch() {
        XCTAssertNil(KeywordMatcher.firstMatch(in: "hello there", keywords: ["vote"], options: MatchOptions()))
        XCTAssertNil(KeywordMatcher.firstMatch(in: "vote", keywords: [], options: MatchOptions()))
        XCTAssertNil(KeywordMatcher.firstMatch(in: "", keywords: ["vote"], options: MatchOptions()))
        XCTAssertNil(KeywordMatcher.firstMatch(in: "vote", keywords: [""], options: MatchOptions()))
    }

    func testReturnsConfiguredKeywordInRuleOrder() {
        XCTAssertEqual(KeywordMatcher.firstMatch(in: "An offer to VOTE", keywords: ["vote", "offer"], options: MatchOptions()), "vote")
    }
}
