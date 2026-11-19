import Foundation

public struct ProcessOutput: Equatable, Sendable {
    public var exitCode: Int32
    public var stdout: Data
    public var stderr: Data

    public init(exitCode: Int32, stdout: Data = Data(), stderr: Data = Data()) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public enum ProcessRunnerError: Error, Equatable, Sendable {
    case executableNotFound(String)
    case launchFailed(String)
}

/// Point d'injection pour simuler l'exécution de `ddev` dans les tests.
public protocol ProcessRunning: Sendable {
    /// - Parameter environment: environnement complet du processus ; `nil` hérite de celui de l'app.
    func run(_ executableURL: URL, arguments: [String], environment: [String: String]?) async throws -> ProcessOutput
}
