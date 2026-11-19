import Foundation

enum ProcessEnvironment {
    /// Une app lancée depuis le Finder n'a pas le `PATH` du shell : sans ces dossiers,
    /// `ddev` ne trouve ni `docker` ni les outils d'OrbStack ou de Colima.
    static func extraDirectories(home: String = NSHomeDirectory()) -> [String] {
        ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.orbstack/bin"]
    }

    /// Ajoute les dossiers manquants à la fin du `PATH`, pour respecter l'ordre choisi par l'utilisateur.
    static func withExtendedPath(_ base: [String: String], adding directories: [String]) -> [String: String] {
        var environment = base
        var path = (base["PATH"] ?? "").split(separator: ":").map(String.init)
        for directory in directories where !path.contains(directory) {
            path.append(directory)
        }
        environment["PATH"] = path.joined(separator: ":")
        return environment
    }
}
