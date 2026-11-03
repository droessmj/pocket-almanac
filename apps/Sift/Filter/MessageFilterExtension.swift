// Copyright (c) 2026 Michael Droessler
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import IdentityLookup
import OSLog

/// Sends SMS/MMS from unknown senders that contain a user keyword to Junk (no notification);
/// everything else is left to the system. No match or message history is recorded.
final class MessageFilterExtension: ILMessageFilterExtension {
    override init() {
        super.init()
        // Deletion-only upgrade cleanup in the extension's own private container.
        do { try LegacyLogFileCleanup.removePrivateLog() }
        catch {
            Logger(subsystem: "com.droessmj.blotter", category: "LegacyCleanup")
                .error("Old private activity file cleanup failed; it will retry on the next extension launch.")
        }
    }
}

extension MessageFilterExtension: ILMessageFilterQueryHandling {
    func handle(
        _ queryRequest: ILMessageFilterQueryRequest,
        context: ILMessageFilterExtensionContext,
        completion: @escaping (ILMessageFilterQueryResponse) -> Void
    ) {
        let match = KeywordMatcher.firstMatch(in: queryRequest.messageBody ?? "", keywords: KeywordStore.load(),
                                              options: KeywordStore.loadOptions())

        let response = ILMessageFilterQueryResponse()
        response.action = match == nil ? .none : .junk
        completion(response)
    }
}
