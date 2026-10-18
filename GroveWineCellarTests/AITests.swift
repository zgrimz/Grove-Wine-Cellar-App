import Foundation
import Testing
@testable import GroveWineCellar

struct AIModelCatalogTests {
    private let anthropic = [
        AIModelInfo(id: "claude-opus-5-5", displayName: "Claude Opus 5.5"),
        AIModelInfo(id: "claude-sonnet-5-5", displayName: "Claude Sonnet 5.5"),
        AIModelInfo(id: "claude-haiku-5-5", displayName: "Claude Haiku 5.5"),
    ]

    @Test func labelScanningPrefersTheQuickModel() {
        #expect(AIModelCatalog.preferred(from: anthropic, for: .labelScanning) == "claude-haiku-5-5")
    }

    @Test func pairingPrefersTheCapableModel() {
        #expect(AIModelCatalog.preferred(from: anthropic, for: .pairing) == "claude-opus-5-5")
    }

    @Test func unknownNamingFallsBackToTheFirstModel() {
        let models = [AIModelInfo(id: "zeta-1", displayName: "Zeta"), AIModelInfo(id: "zeta-2", displayName: "Zeta 2")]
        #expect(AIModelCatalog.preferred(from: models, for: .pairing) == "zeta-1")
        #expect(AIModelCatalog.preferred(from: [], for: .pairing) == nil)
    }
}

struct AIWireFormatTests {
    private let request = AIToolRequest(
        modelID: "some-model", maxTokens: 1000, systemPrompt: "system", userText: "user",
        image: AIImage(base64: "AAAA", mediaType: "image/jpeg"),
        tool: AITool(name: "record", description: "d", properties: ["a": ["type": "string"]], required: []),
        timeout: 60)

    @Test func anthropicForcesTheToolAndPutsTheImageFirst() throws {
        let body = AnthropicWire().requestBody(for: request)
        #expect(body["max_tokens"] as? Int == 1000)
        #expect((body["tool_choice"] as? [String: Any])?["name"] as? String == "record")
        let content = try #require(((body["messages"] as? [[String: Any]])?.first)?["content"] as? [[String: Any]])
        #expect(content.map { $0["type"] as? String } == ["image", "text"])
        // An empty `required` is omitted, not sent as [].
        let schema = try #require(((body["tools"] as? [[String: Any]])?.first)?["input_schema"] as? [String: Any])
        #expect(schema["required"] == nil)
    }

    @Test func openAIScalesTheBudgetForReasoning() {
        let body = OpenAIWire().requestBody(for: request)
        #expect(body["max_completion_tokens"] as? Int == 8000)
        #expect(body["max_tokens"] == nil)
        #expect(OpenAIWire().scaledTimeout(60) == 90)
    }

    @Test func anthropicReadsTheToolUseBlock() throws {
        let root: [String: Any] = ["content": [["type": "text", "text": "hi"],
                                               ["type": "tool_use", "input": ["name": "Barolo"]]]]
        #expect(try AnthropicWire().toolInput(from: root)["name"] as? String == "Barolo")
        #expect(throws: AIClient.CallError.self) { try AnthropicWire().toolInput(from: ["content": []]) }
    }

    @Test func openAIParsesStringArguments() throws {
        let root: [String: Any] = ["choices": [["message": ["tool_calls": [
            ["function": ["arguments": #"{"name":"Chablis"}"#]],
        ]]]]]
        #expect(try OpenAIWire().toolInput(from: root)["name"] as? String == "Chablis")
    }

    @Test func authFailuresAndTruncationAreRecognised() {
        #expect(AnthropicWire().isAuthFailure(status: 401, root: nil))
        #expect(!AnthropicWire().isAuthFailure(status: 500, root: nil))
        #expect(AnthropicWire().isTruncated(["stop_reason": "max_tokens"]))
        #expect(OpenAIWire().isTruncated(["choices": [["finish_reason": "length"]]]))
        #expect(OpenAIWire().isRefusal(["choices": [["message": ["refusal": "no"]]]]))
    }

    @Test func openAIModelListKeepsOnlyChatModelsSorted() {
        let root: [String: Any] = ["data": [
            ["id": "gpt-5"], ["id": "text-embedding-3-large"], ["id": "o3-mini"],
            ["id": "gpt-4o-realtime-preview"], ["id": "whisper-1"], ["id": "gpt-4o"],
        ]]
        #expect(OpenAIWire().parseModels(from: root).map(\.id) == ["gpt-4o", "gpt-5", "o3-mini"])
    }

    @Test func anthropicModelListUsesDisplayNames() {
        let root: [String: Any] = ["data": [["id": "claude-haiku-5-5", "display_name": "Claude Haiku 5.5"]]]
        #expect(AnthropicWire().parseModels(from: root) == [AIModelInfo(id: "claude-haiku-5-5", displayName: "Claude Haiku 5.5")])
    }
}

struct AIFeatureParsingTests {
    @Test func labelAttributesMatchEnumsLeniently() throws {
        let attributes = try #require(VisionService.attributes(from: [
            "name": "Whispering Angel", "color": "rose", "style": "still", "sweetness": "dry",
            "vintage": "2023", "producer": "  ",
        ]))
        #expect(attributes.color == .rose)
        #expect(attributes.style == .still)
        #expect(attributes.sweetness == [.dry])
        #expect(attributes.vintage == 2023)
        #expect(attributes.producer == nil)
    }

    @Test func labelWithoutANameIsNotARecognition() {
        #expect(VisionService.attributes(from: ["color": "Red"]) == nil)
    }

    @Test func recommendationAcceptsANumericVintageAndMissingProducer() throws {
        let recommendation = try #require(SommelierService.recommendation(from: [
            "recommendedWine": ["id": "ABC", "name": "Barolo", "vintage": 2016],
            "whyThisPair": ["Tannin meets fat."],
            "pairingConfidence": 9,
        ]))
        #expect(recommendation.recommendedWine.vintage == "2016")
        #expect(recommendation.recommendedWine.producer == "")
        #expect(recommendation.betterPairingRecommendation == nil)
    }
}
