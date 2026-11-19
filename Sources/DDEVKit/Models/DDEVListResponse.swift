import Foundation

/// Enveloppe JSON produite par `ddev list --json-output` : les projets sont dans `raw`.
struct DDEVListResponse: Decodable {
    let raw: [DDEVProject]?

    /// Extrait les projets de la sortie standard de `ddev list --json-output`.
    /// DDEV écrit une ligne JSON par message (des avertissements peuvent précéder la liste),
    /// donc on retient la première ligne qui porte la clé `raw`.
    static func projects(from data: Data) throws(DDEVError) -> [DDEVProject] {
        let lines = data.split(separator: UInt8(ascii: "\n")).filter { !$0.allSatisfy(Self.isWhitespace) }
        guard !lines.isEmpty else { throw .invalidJSON("sortie vide") }

        let decoder = JSONDecoder()
        var lastError: (any Error)?
        for line in lines {
            do {
                let envelope = try decoder.decode(RawKeyProbe.self, from: Data(line))
                guard envelope.hasRaw else { continue }
                return try decoder.decode(DDEVListResponse.self, from: Data(line)).raw ?? []
            } catch {
                lastError = error
            }
        }
        throw .invalidJSON(lastError.map { String(describing: $0) } ?? "clé raw absente")
    }

    private static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: "\r")
    }
}

/// Détecte la présence de `raw` sans décoder les projets, pour distinguer un message d'une liste.
private struct RawKeyProbe: Decodable {
    let hasRaw: Bool

    private enum CodingKeys: String, CodingKey { case raw }

    init(from decoder: any Decoder) throws {
        hasRaw = try decoder.container(keyedBy: CodingKeys.self).contains(.raw)
    }
}
