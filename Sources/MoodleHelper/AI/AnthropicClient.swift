import Foundation
import FoundationModels

enum OnDeviceModelError: LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "On-device language model is not available on this Mac."
        }
    }
}

struct OnDeviceModelClient {
    private let session: LanguageModelSession

    init() throws {
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
                Output 2-4 short sentences. Plain text, no markdown. \
                If the input is already short, return it unchanged.
                """
        )
    }

    func summarize(_ text: String) async throws -> String {
        let response = try await session.respond(to: "Shorten this reminder note:\n\n\(text)")
        return response.content
    }
}
