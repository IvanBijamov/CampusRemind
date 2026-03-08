import Foundation

@available(macOS 26.0, iOS 26.0, *)
public actor DescriptionSummarizer {
    private let client: OnDeviceModelClient
    private let verbose: Bool

    public init(verbose: Bool = false) throws {
        self.client = try OnDeviceModelClient()
        self.verbose = verbose
    }

    public func summarize(_ description: String?) async -> String? {
        guard let description, !description.isEmpty else {
            return description
        }

        // Short descriptions pass through unchanged
        if description.count < 100 {
            return description
        }

        do {
            let summary = try await client.summarize(description)
            if verbose {
                print("    [summarized] \(description.count) -> \(summary.count) chars")
            }
            return summary
        } catch {
            // Graceful fallback: return original description on any error
            if verbose { print("    [summarize-error] \(error.localizedDescription), using original") }
            return description
        }
    }
}
