import Foundation

/// Client asynchrone de la CLI `ddev`.
public struct DDEVClient: Sendable {
    private let executableURL: URL?
    private let runner: any ProcessRunning
    private let locator: DDEVLocator
    private let baseEnvironment: [String: String]
    private let listTimeout: Duration
    private let actionTimeout: Duration

    /// - Parameters:
    ///   - executableURL: chemin explicite de `ddev` ; sinon `locator` le cherche à chaque appel.
    ///   - listTimeout: `ddev list` attend sans fin quand Docker est arrêté, d'où cette limite.
    ///   - actionTimeout: un premier `ddev start` télécharge des images et peut durer plusieurs minutes.
    public init(
        executableURL: URL? = nil,
        runner: any ProcessRunning = SystemProcessRunner(),
        locator: DDEVLocator = DDEVLocator(),
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        listTimeout: Duration = .seconds(20),
        actionTimeout: Duration = .seconds(600)
    ) {
        self.executableURL = executableURL
        self.runner = runner
        self.locator = locator
        self.baseEnvironment = baseEnvironment
        self.listTimeout = listTimeout
        self.actionTimeout = actionTimeout
    }

    public func listProjects() async throws(DDEVError) -> [DDEVProject] {
        let output = try await run(["list", "--json-output"], timeout: listTimeout)
        return try DDEVListResponse.projects(from: output.stdout)
    }

    public func start(_ project: DDEVProject) async throws(DDEVError) {
        _ = try await run(["start", project.name], timeout: actionTimeout)
    }

    public func stop(_ project: DDEVProject) async throws(DDEVError) {
        _ = try await run(["stop", project.name], timeout: actionTimeout)
    }

    public func restart(_ project: DDEVProject) async throws(DDEVError) {
        _ = try await run(["restart", project.name], timeout: actionTimeout)
    }

    private func run(_ arguments: [String], timeout: Duration) async throws(DDEVError) -> ProcessOutput {
        guard let url = executableURL ?? locator.locate() else { throw .ddevNotFound }

        let directories = [url.deletingLastPathComponent().path] + ProcessEnvironment.extraDirectories()
        let environment = ProcessEnvironment.withExtendedPath(baseEnvironment, adding: directories)

        let output: ProcessOutput
        do {
            output = try await runWithTimeout(url, arguments, environment, timeout)
        } catch let error as DDEVError {
            throw error
        } catch ProcessRunnerError.executableNotFound {
            throw .ddevNotFound
        } catch ProcessRunnerError.launchFailed(let reason) {
            throw .launchFailed(reason)
        } catch {
            throw .launchFailed(error.localizedDescription)
        }

        guard output.exitCode == 0 else {
            let stderr = String(decoding: output.stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw .nonZeroExit(code: output.exitCode, stderr: stderr)
        }
        return output
    }

    /// Le premier des deux gagne ; l'annulation de l'autre tâche termine le processus `ddev`.
    private func runWithTimeout(
        _ url: URL,
        _ arguments: [String],
        _ environment: [String: String],
        _ timeout: Duration
    ) async throws -> ProcessOutput {
        let runner = runner
        return try await withThrowingTaskGroup(of: ProcessOutput?.self) { group in
            group.addTask { try await runner.run(url, arguments: arguments, environment: environment) }
            group.addTask {
                try await Task.sleep(for: timeout)
                return nil
            }
            defer { group.cancelAll() }

            guard let first = try await group.next(), let output = first else {
                throw DDEVError.timedOut(seconds: Int(timeout.components.seconds))
            }
            return output
        }
    }
}
