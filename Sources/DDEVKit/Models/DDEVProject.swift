import Foundation

/// Projet DDEV, limité aux champs utiles de `ddev list --json-output`.
public struct DDEVProject: Codable, Hashable, Sendable, Identifiable {
    public var name: String
    public var status: DDEVProjectStatus
    /// Type de projet (`laravel`, `php`, `wordpress`…), vide si DDEV n'en donne pas.
    public var type: String
    public var primaryURL: URL?
    public var appRoot: String

    public var id: String { name }

    public init(name: String, status: DDEVProjectStatus, type: String, primaryURL: URL?, appRoot: String) {
        self.name = name
        self.status = status
        self.type = type
        self.primaryURL = primaryURL
        self.appRoot = appRoot
    }

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case type
        case primaryURL = "primary_url"
        case appRoot = "approot"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        appRoot = try container.decode(String.self, forKey: .appRoot)
        status = try container.decodeIfPresent(DDEVProjectStatus.self, forKey: .status) ?? .other("")
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        // DDEV renvoie une chaîne vide quand le projet n'a pas d'URL, ce que URL refuse de décoder.
        let rawURL = try container.decodeIfPresent(String.self, forKey: .primaryURL) ?? ""
        primaryURL = rawURL.isEmpty ? nil : URL(string: rawURL)
    }
}
