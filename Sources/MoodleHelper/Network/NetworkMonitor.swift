import Foundation
import Network

enum NetworkError: LocalizedError {
    case timeout(seconds: Int)

    var errorDescription: String? {
        switch self {
        case .timeout(let seconds):
            return "Network connectivity not available after waiting \(seconds) seconds."
        }
    }
}

private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var _resumed = false

    /// Returns true only on the first call; all subsequent calls return false.
    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _resumed { return false }
        _resumed = true
        return true
    }
}

enum NetworkMonitor {
    static func waitForConnectivity(timeout: Int, verbose: Bool) async throws {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.moodlehelper.networkmonitor")

        // Check if already connected
        let alreadyConnected: Bool = await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: queue)
        }

        if alreadyConnected {
            if verbose { print("Network: connected") }
            return
        }

        if verbose { print("Network: waiting for connectivity (timeout: \(timeout)s)...") }

        // Race: connectivity vs timeout
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let connectMonitor = NWPathMonitor()
                let connectQueue = DispatchQueue(label: "com.moodlehelper.networkmonitor.wait")
                let guard_ = ResumeGuard()

                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        connectMonitor.pathUpdateHandler = { path in
                            if path.status == .satisfied {
                                connectMonitor.cancel()
                                if guard_.tryResume() {
                                    continuation.resume()
                                }
                            }
                        }
                        connectMonitor.start(queue: connectQueue)
                    }
                } onCancel: {
                    connectMonitor.cancel()
                    _ = guard_.tryResume()
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
                throw NetworkError.timeout(seconds: timeout)
            }

            // First task to finish wins
            try await group.next()
            group.cancelAll()
        }

        if verbose { print("Network: connected") }
    }
}
