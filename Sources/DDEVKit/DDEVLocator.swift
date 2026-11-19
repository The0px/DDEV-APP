import Foundation

/// Cherche le binaire `ddev` sur le disque.
public struct DDEVLocator: Sendable {
    public var searchDirectories: [String]
    public var isExecutable: @Sendable (String) -> Bool

    public init(
        searchDirectories: [String] = DDEVLocator.defaultSearchDirectories(),
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.searchDirectories = searchDirectories
        self.isExecutable = isExecutable
    }

    public func locate() -> URL? {
        searchDirectories
            .map { URL(fileURLWithPath: $0).appendingPathComponent("ddev").path }
            .first(where: isExecutable)
            .map { URL(fileURLWithPath: $0) }
    }

    /// Une app lancée depuis le Finder n'hérite pas du `PATH` du shell,
    /// donc on ajoute les dossiers d'installation habituels de Homebrew.
    public static func defaultSearchDirectories(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String] {
        let fromPath = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        return (fromPath + ["/opt/homebrew/bin", "/usr/local/bin"]).filter { seen.insert($0).inserted }
    }
}
