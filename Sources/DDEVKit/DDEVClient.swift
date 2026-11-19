import Foundation

/// Client asynchrone de la CLI `ddev`.
public struct DDEVClient: Sendable {
    private let executableURL: URL?
    private let runner: any ProcessRunning
    private let locator: DDEVLocator

    /// - Parameter executableURL: chemin explicite de `ddev` ; sinon `locator` le cherche à chaque appel.
    public init(
        executableURL: URL? = nil,
        runner: any ProcessRunning = SystemProcessRunner(),
        locator: DDEVLocator = DDEVLocator()
    ) {
        self.executableURL = executableURL
        self.runner = runner
        self.locator = locator
    }

    public func listProjects() async throws(DDEVError) -> [DDEVProject] {
        let output = try await run(["list", "--json-output"])
        return try DDEVListResponse.projects(from: output.stdout)
    }

    private func run(_ arguments: [String]) async throws(DDEVError) -> ProcessOutput {
        guard let url = executableURL ?? locator.locate() else { throw .ddevNotFound }

        let output: ProcessOutput
        do {
            output = try await runner.run(url, arguments: arguments)
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
}
