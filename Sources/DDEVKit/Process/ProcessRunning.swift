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
    func run(_ executableURL: URL, arguments: [String]) async throws -> ProcessOutput
}
