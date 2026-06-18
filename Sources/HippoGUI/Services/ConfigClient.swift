import Foundation
import TOMLDecoder

/// An immutable, internally-consistent view of Hippo's config, resolved from a
/// single read of the file. Derive all values a consumer needs from one
/// `ConfigClient.snapshot()` so they can't be torn across separate reads.
struct ConfigSnapshot: Sendable {
    let port: Int
    let queryTimeout: TimeInterval
    let dataDirectory: URL
}

/// Reads a handful of scalar values from Hippo's `~/.config/hippo/config.toml`.
///
/// Parsing is delegated to TOMLDecoder (a pure-Swift, Codable-based TOML
/// parser), so the full TOML grammar is supported. The file is decoded into the
/// small `ParsedConfig` shape below; every field is optional, so a missing,
/// unreadable, malformed, or partial file falls back to the defaults.
struct ConfigClient: Sendable {
    static let defaultPort = 9175
    static let defaultQueryTimeout: TimeInterval = 300
    static let defaultDataDirectory = ".local/share/hippo"

    private let configPath: URL

    init(configPath: URL? = nil) {
        if let configPath {
            self.configPath = configPath
        } else {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            self.configPath = homeDir.appendingPathComponent(".config/hippo/config.toml")
        }
    }

    /// Read and parse the config file exactly once and resolve every value from
    /// that single parse.
    ///
    /// This is the consistency backstop: a consumer that needs more than one
    /// setting (e.g. `BrainClient` needs both port and timeout) must take one
    /// snapshot rather than calling several `loadX()` accessors, otherwise an
    /// edit to the file between reads could yield a torn mix of old and new
    /// values.
    func snapshot() -> ConfigSnapshot {
        let parsed = decoded()
        return ConfigSnapshot(
            port: parsed?.brain?.port ?? Self.defaultPort,
            queryTimeout: parsed?.brain?.queryTimeoutSecs ?? Self.defaultQueryTimeout,
            dataDirectory: Self.resolveDataDirectory(parsed?.storage?.dataDir)
        )
    }

    func loadPort() -> Int {
        snapshot().port
    }

    func loadQueryTimeout() -> TimeInterval {
        snapshot().queryTimeout
    }

    func loadDataDirectory() -> URL {
        snapshot().dataDirectory
    }

    private static func resolveDataDirectory(_ configuredValue: String?) -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let fallback = homeDirectory.appendingPathComponent(Self.defaultDataDirectory)

        guard let configuredPath = configuredValue?.trimmingCharacters(in: .whitespacesAndNewlines),
            !configuredPath.isEmpty
        else {
            return fallback
        }

        if configuredPath.hasPrefix("~/") {
            return homeDirectory.appendingPathComponent(String(configuredPath.dropFirst(2)))
        }

        if configuredPath == "~" {
            return homeDirectory
        }

        return URL(fileURLWithPath: configuredPath, isDirectory: true)
    }

    /// Decode the config file, or `nil` if it is missing, unreadable, or invalid TOML.
    ///
    /// TOML is parsed as a whole: a single malformed line invalidates the entire
    /// document, so every accessor falls back to its default rather than reading
    /// a partially-valid file. This is intentional — a malformed config is
    /// treated as no config.
    private func decoded() -> ParsedConfig? {
        guard let content = try? String(contentsOf: configPath, encoding: .utf8) else {
            return nil
        }
        return try? TOMLDecoder().decode(ParsedConfig.self, from: content)
    }
}

/// Mirrors the subset of `config.toml` that the GUI reads. Unknown sections and
/// keys are ignored, and every field is optional so a partial file still decodes
/// with unspecified values left to the caller's defaults.
private struct ParsedConfig: Decodable {
    let brain: BrainSection?
    let storage: StorageSection?
}

private struct BrainSection: Decodable {
    let port: Int?
    let queryTimeoutSecs: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case port
        case queryTimeoutSecs = "query_timeout_secs"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        port = try? container.decode(Int.self, forKey: .port)
        // `query_timeout_secs` may be written as a TOML integer (120) or
        // float (120.5); accept either.
        if let double = try? container.decode(Double.self, forKey: .queryTimeoutSecs) {
            queryTimeoutSecs = double
        } else if let int = try? container.decode(Int.self, forKey: .queryTimeoutSecs) {
            queryTimeoutSecs = TimeInterval(int)
        } else {
            queryTimeoutSecs = nil
        }
    }
}

private struct StorageSection: Decodable {
    let dataDir: String?

    enum CodingKeys: String, CodingKey {
        case dataDir = "data_dir"
    }
}
