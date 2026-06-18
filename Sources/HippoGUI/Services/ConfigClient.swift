import Foundation
import TOMLDecoder

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

    func loadPort() -> Int {
        decoded()?.brain?.port ?? Self.defaultPort
    }

    func loadQueryTimeout() -> TimeInterval {
        decoded()?.brain?.queryTimeoutSecs ?? Self.defaultQueryTimeout
    }

    func loadDataDirectory() -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let configuredPath = decoded()?.storage?.dataDir?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = homeDirectory.appendingPathComponent(Self.defaultDataDirectory)

        guard let configuredPath, !configuredPath.isEmpty else {
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
