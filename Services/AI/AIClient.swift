import Foundation

/// The one network path for every AI feature in the app.
///
/// Takes a vendor-neutral ``AIToolRequest``, posts it in the selected provider's wire format, and
/// returns the forced tool call's arguments — so ``VisionService`` and ``SommelierService`` state
/// what they want and never learn which vendor answered. Swift has no official SDK for either, so
/// this is plain `URLSession` against their REST APIs.
enum AIClient {
    /// Transport and protocol failures, mapped by each feature to its own user-facing error type.
    enum CallError: Error {
        case transport(String)
        /// `isAuthFailure` is decided by the provider's ``AIWireFormat``, not by the status code.
        /// Providers disagree about how to reject a bad key — 400 as well as 401 — so a bare `401`
        /// test misreports it.
        case http(status: Int, message: String, isAuthFailure: Bool)
        case refused
        /// The model hit its output ceiling before finishing the tool call. Kept distinct from
        /// `noToolCall`: nothing is wrong with the request or the schema, so telling the user
        /// their photo was unreadable would send them after the wrong problem.
        case truncated
        case noToolCall

        /// A plain description, for surfaces that have no feature-specific framing to add (the
        /// model refresh in Settings). The features add their own copy where they have some.
        func summary(provider: AIProvider) -> String {
            switch self {
            case .transport(let detail):
                return "Couldn't reach \(provider.displayName): \(detail)"
            case .http(let status, let message, let isAuthFailure):
                if isAuthFailure {
                    return "Your \(provider.displayName) API key was rejected (\(status))."
                }
                return "\(provider.displayName) returned an error (\(status)): \(message)"
            case .refused: return "The model declined the request."
            case .truncated: return "The model ran out of room before answering."
            case .noToolCall: return "The model didn't return a usable answer."
            }
        }
    }

    /// POST a request that forces a tool call, and return that call's arguments.
    static func forcedToolInput(_ request: AIToolRequest, provider: AIProvider,
                                apiKey: String) async throws -> [String: Any] {
        let wire = provider.wire
        var urlRequest = URLRequest(url: try wire.endpoint(modelID: request.modelID))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = wire.scaledTimeout(request.timeout)
        for (field, value) in wire.headers(apiKey: apiKey) {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: wire.requestBody(for: request))

        let (data, http) = try await send(urlRequest)
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        try check(http, data: data, root: root, wire: wire)

        guard let root else { throw CallError.noToolCall }
        if wire.isRefusal(root) { throw CallError.refused }
        do {
            return try wire.toolInput(from: root)
        } catch {
            // A budget spent entirely on reasoning looks identical to a missing tool call from
            // here, so name the real cause before giving up.
            if wire.isTruncated(root) {
                print("AI: \(provider.rawValue) response truncated before the tool call")
                throw CallError.truncated
            }
            print("AI: couldn't read a tool call out of the \(provider.rawValue) response")
            throw error
        }
    }

    /// Ask the provider which models the key can actually use, for the Settings picker.
    static func availableModels(provider: AIProvider, apiKey: String) async throws -> [AIModelInfo] {
        let wire = provider.wire
        var urlRequest = URLRequest(url: wire.modelsEndpoint())
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 20
        for (field, value) in wire.headers(apiKey: apiKey) {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        let (data, http) = try await send(urlRequest)
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        try check(http, data: data, root: root, wire: wire)
        guard let root else { return [] }
        return wire.parseModels(from: root)
    }

    private static func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("AI: request failed to send — URLError \((error as? URLError)?.errorCode ?? -1)")
            throw CallError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw CallError.transport("No HTTP response")
        }
        return (data, http)
    }

    private static func check(_ http: HTTPURLResponse, data: Data, root: [String: Any]?,
                              wire: AIWireFormat) throws {
        guard !(200..<300).contains(http.statusCode) else { return }
        // Status only. The provider's error message can quote the request back, and the request
        // carries the user's label photo or cellar list — so it reaches the user's alert and
        // stops there.
        print("AI: provider returned HTTP \(http.statusCode)")
        throw CallError.http(status: http.statusCode,
                             message: aiErrorMessage(from: data, root: root),
                             isAuthFailure: wire.isAuthFailure(status: http.statusCode, root: root))
    }
}
