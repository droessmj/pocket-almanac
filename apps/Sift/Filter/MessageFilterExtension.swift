// Copyright (c) 2026 Michael Droessler
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import IdentityLookup

/// Sends SMS/MMS from unknown senders that contain a user keyword to Junk (no notification);
/// everything else is left to the system. Every message is recorded in the activity log.
final class MessageFilterExtension: ILMessageFilterExtension {}

extension MessageFilterExtension: ILMessageFilterQueryHandling {
    func handle(
        _ queryRequest: ILMessageFilterQueryRequest,
        context: ILMessageFilterExtensionContext,
        completion: @escaping (ILMessageFilterQueryResponse) -> Void
    ) {
        let received = Date()
        let match = KeywordMatcher.firstMatch(in: queryRequest.messageBody ?? "", keywords: KeywordStore.load(),
                                              options: KeywordStore.loadOptions())

        let response = ILMessageFilterQueryResponse()
        response.action = match == nil ? .none : .junk
        completion(response)

        ActivityLog.record(ActivityEntry(
            received: received,
            sender: queryRequest.sender ?? "unknown",
            verdict: match == nil ? .allowed : .spam,
            reason: match.map { "keyword \"\($0)\"" } ?? "no keyword match"
        ))
    }
}
