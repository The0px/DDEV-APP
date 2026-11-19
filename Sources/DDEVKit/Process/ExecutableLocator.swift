import Foundation

/// Cherche un exécutable (`ddev`, `docker`) sur le disque.
public struct ExecutableLocator: Sendable {
    public var executableName: String
    public var searchDirectories: [String]
    public var isExecutable: @Sendable (String) -> Bool

    public init(
        executableName: String,
        searchDirectories: [String] = ExecutableLocator.defaultSearchDirectories(),
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.executableName = executableName
        self.searchDirectories = searchDirectories
        self.isExecutable = isExecutable
    }

    public func locate() -> URL? {
        searchDirectories
            .map { URL(fileURLWithPath: $0).appendingPathComponent(executableName).path }
            .first(where: isExecutable)
            .map { URL(fileURLWithPath: $0) }
    }

    /// Une app lancée depuis le Finder n'hérite pas du `PATH` du shell,
    /// donc on ajoute les dossiers d'installation habituels.
    public static func defaultSearchDirectories(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: String = NSHomeDirectory()
    ) -> [String] {
        let fromPath = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        return (fromPath + ProcessEnvironment.extraDirectories(home: home)).filter { seen.insert($0).inserted }
    }
}
