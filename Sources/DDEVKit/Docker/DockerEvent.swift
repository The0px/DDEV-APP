import Foundation

/// Event d'un conteneur DDEV, tel que produit par `docker events --format '{{json .}}'`.
public struct DockerEvent: Decodable, Equatable, Sendable {
    /// `start`, `die`, `pause`… Les versions anciennes de Docker l'appellent `status`.
    public let action: String
    /// Valeur du label `com.ddev.site-name` posé par DDEV sur ses conteneurs.
    public let projectName: String?

    public init(action: String, projectName: String?) {
        self.action = action
        self.projectName = projectName
    }

    private enum CodingKeys: String, CodingKey {
        case action = "Action"
        case status
        case actor = "Actor"
    }

    private struct Actor: Decodable {
        let attributes: [String: String]?

        private enum CodingKeys: String, CodingKey { case attributes = "Attributes" }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let action = try container.decodeIfPresent(String.self, forKey: .action) {
            self.action = action
        } else {
            action = try container.decode(String.self, forKey: .status)
        }
        let actor = try container.decodeIfPresent(Actor.self, forKey: .actor)
        projectName = actor?.attributes?["com.ddev.site-name"]
    }
}
