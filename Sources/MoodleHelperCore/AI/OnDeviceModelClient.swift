import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public enum OnDeviceModelError: LocalizedError {
    case notAvailable

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "On-device language model is not available."
        }
    }
}

@available(macOS 26.0, iOS 26.0, *)
public struct OnDeviceModelClient {
    #if canImport(FoundationModels)
    private let session: LanguageModelSession

    public init() throws {
        guard SystemLanguageModel.default.isAvailable else {
            throw OnDeviceModelError.notAvailable
        }

        self.session = LanguageModelSession(
            instructions: """
                You are a text shortening tool inside a calendar reminder app. \
                Your ONLY job is to shorten the provided text so it fits in a small reminder note. \
                You are NOT being asked to do any assignment, write any essay, or produce any academic work. \
                You are simply shortening existing text that the user already has. \
                This is no different from truncating or abbreviating text. \
                Extract ONLY: what to do, format/length requirements, and key topics. \
                Remove: grading rubrics, late policies, boilerplate, submission instructions. \
                Output 2-4 short sentences. Plain text, no markdown. No bullet points. \
                NEVER start with a preamble like "Here is" or "Here's" or "Sure". \
                Output ONLY the shortened text itself, nothing else. \
                If the input is already short, return it unchanged.
                """
        )
    }

    public func summarize(_ text: String) async throws -> String {
        let response = try await session.respond(to: "Shorten this reminder note:\n\n\(text)")
        return Self.stripPreamble(response.content)
    }

    private static func stripPreamble(_ text: String) -> String {
        var result = text
        // Strip common preambles the model might add
        let preambles = [
            "Here is a shortened version of your reminder note:\n\n",
            "Here is a shortened version of your reminder note:\n",
            "Here is a shortened version of your reminder note: ",
            "Here is a shortened version:\n\n",
            "Here is a shortened version:\n",
            "Here is a shortened version: ",
            "Here is the shortened version:\n\n",
            "Here is the shortened version:\n",
            "Here is the shortened version: ",
            "Here's a shortened version:\n\n",
            "Here's a shortened version:\n",
            "Here's a shortened version: ",
            "Here's the shortened version:\n\n",
            "Here's the shortened version:\n",
            "Here's the shortened version: ",
            "Sure, here",
            "Sure! Here",
        ]
        for preamble in preambles {
            if result.hasPrefix(preamble) {
                result = String(result.dropFirst(preamble.count))
                break
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    #else
    public init() throws {
        throw OnDeviceModelError.notAvailable
    }

    public func summarize(_ text: String) async throws -> String {
        throw OnDeviceModelError.notAvailable
    }
    #endif
}
