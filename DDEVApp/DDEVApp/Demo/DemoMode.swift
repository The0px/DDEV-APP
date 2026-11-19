import DDEVKit
import Foundation

/// Mode démo (`--demo`) : des projets fictifs, sans DDEV ni Docker.
/// Sert aux captures d'écran du README sans exposer de vrais projets.
enum DemoMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--demo")
    }

    static func makeClient() -> DDEVClient {
        DDEVClient(executableURL: URL(fileURLWithPath: "/demo/ddev"), runner: DemoProcessRunner())
    }
}

/// Simule `ddev list`, `start`, `stop` et `restart` en gardant l'état en mémoire.
final class DemoProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var projects: [DDEVProject] = [
        demo("blog", .running, "laravel"),
        demo("boutique", .running, "wordpress"),
        demo("intranet", .paused, "drupal11"),
        demo("api-catalogue", .stopped, "symfony"),
        demo("documentation", .stopped, "php"),
    ]

    func run(_ executableURL: URL, arguments: [String], environment: [String: String]?) async throws -> ProcessOutput {
        guard let command = arguments.first else { return ProcessOutput(exitCode: 1) }
        if command == "list" {
            let snapshot = lock.withLock { projects }
            return ProcessOutput(exitCode: 0, stdout: try JSONEncoder().encode(["raw": snapshot]))
        }

        try await Task.sleep(for: .seconds(1.5))
        let newStatus: DDEVProjectStatus = command == "stop" ? .stopped : .running
        lock.withLock {
            if let index = projects.firstIndex(where: { $0.name == arguments.last }) {
                projects[index].status = newStatus
            }
        }
        return ProcessOutput(exitCode: 0)
    }

    private static func demo(_ name: String, _ status: DDEVProjectStatus, _ type: String) -> DDEVProject {
        DDEVProject(
            name: name,
            status: status,
            type: type,
            primaryURL: URL(string: "https://\(name).ddev.site"),
            appRoot: "/Users/demo/Sites/\(name)"
        )
    }
}
