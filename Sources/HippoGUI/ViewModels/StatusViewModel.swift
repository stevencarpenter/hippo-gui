import Foundation
import Observation

@MainActor
@Observable
final class StatusViewModel {
    var health: HealthResponse?
    var daemonResponsive = false
    var isLoading = false
    var errorMessage: String?
    var lastCheckedAt: Date?

    @ObservationIgnored private let client: (any BrainClientProtocol)?
    @ObservationIgnored private let daemonClient: DaemonSocketClient

    init(
        client: (any BrainClientProtocol)? = nil,
        daemonClient: DaemonSocketClient = DaemonSocketClient()
    ) {
        self.client = client
        self.daemonClient = daemonClient
    }

    var brainReachable: Bool {
        health?.brainReachable ?? false
    }

    var lastCheckedDescription: String {
        guard let lastCheckedAt else {
            return "Not checked yet"
        }

        let seconds = max(Int(Date().timeIntervalSince(lastCheckedAt)), 0)
        switch seconds {
        case 0..<60:
            return "Checked \(seconds) seconds ago"
        case 60..<3600:
            return "Checked \(seconds / 60) minutes ago"
        default:
            return "Checked \(seconds / 3600) hours ago"
        }
    }

    func refresh() async {
        guard let client else {
            errorMessage = BrainClientError.notConfigured.localizedDescription
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
            lastCheckedAt = Date()
        }

        async let daemonResponse = daemonClient.isResponsive()
        async let healthResponse = client.health()

        do {
            health = try await healthResponse
            daemonResponsive = await daemonResponse
        } catch {
            daemonResponsive = await daemonResponse
            health = nil
            errorMessage = error.localizedDescription
        }
    }

    /// Poll `refresh()` every 30 seconds until the surrounding task is cancelled.
    ///
    /// Driven from a SwiftUI `.task {}`, so the loop is automatically cancelled
    /// when the view disappears.
    func autoRefresh() async {
        while !Task.isCancelled {
            await refresh()
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                break
            }
        }
    }
}
