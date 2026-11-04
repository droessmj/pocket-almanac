// Copyright (c) 2026 Michael Droessler
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import Foundation

enum Blotter {
    static let appGroup = "group.com.droessmj.blotter"
}

/// How keywords are compared to message text. Defaults: any case, any accents, whole words only.
struct MatchOptions: Equatable {
    var matchCase = false
    var matchAccents = false
    var wholeWords = true
}

/// Keyword list and match options. The app writes them; the filter extension only reads them
/// (the system lets the extension read, but not write, the shared App Group).
enum KeywordStore {
    private static let keywordsKey = "keywords"
    private static let matchCaseKey = "matchCase"
    private static let matchAccentsKey = "matchAccents"
    private static let wholeWordsKey = "wholeWords"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: Blotter.appGroup) }

    static func load() -> [String] { defaults?.stringArray(forKey: keywordsKey) ?? [] }
    static func save(_ keywords: [String]) { defaults?.set(keywords, forKey: keywordsKey) }

    static func loadOptions() -> MatchOptions {
        let fallback = MatchOptions()
        guard let defaults else { return fallback }
        func bool(_ key: String, _ value: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? value }
        return MatchOptions(matchCase: bool(matchCaseKey, fallback.matchCase),
                            matchAccents: bool(matchAccentsKey, fallback.matchAccents),
                            wholeWords: bool(wholeWordsKey, fallback.wholeWords))
    }

    static func save(_ options: MatchOptions) {
        defaults?.set(options.matchCase, forKey: matchCaseKey)
        defaults?.set(options.matchAccents, forKey: matchAccentsKey)
        defaults?.set(options.wholeWords, forKey: wholeWordsKey)
    }
}

enum KeywordMatcher {
    /// First keyword found in `body` under `options`. With whole words on, "vote" matches
    /// "Vote today!" but not "devoted"; with it off, it matches both.
    static func firstMatch(in body: String, keywords: [String], options: MatchOptions) -> String? {
        keywords.first { contains(body, keyword: $0, options: options) }
    }

    private static func contains(_ body: String, keyword: String, options: MatchOptions) -> Bool {
        guard let first = keyword.first, let last = keyword.last else { return false }
        var compare: String.CompareOptions = []
        if !options.matchCase { compare.insert(.caseInsensitive) }
        if !options.matchAccents { compare.insert(.diacriticInsensitive) }
        var searchStart = body.startIndex
        while let r = body.range(of: keyword, options: compare, range: searchStart..<body.endIndex) {
            guard options.wholeWords else { return true }
            let startOK = !isWordChar(first) || r.lowerBound == body.startIndex
                || !isWordChar(body[body.index(before: r.lowerBound)])
            let endOK = !isWordChar(last) || r.upperBound == body.endIndex || !isWordChar(body[r.upperBound])
            if startOK && endOK { return true }
            searchStart = body.index(after: r.lowerBound)
        }
        return false
    }

    private static func isWordChar(_ c: Character) -> Bool { c.isLetter || c.isNumber }
}
