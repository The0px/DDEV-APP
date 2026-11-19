import Foundation

/// Écoute `docker events` pour les conteneurs DDEV.
public struct DockerEventsClient: Sendable {
    /// Changements d'état d'un conteneur. Les events `exec_*` sont exclus :
    /// les healthchecks de DDEV en produisent toutes les quelques secondes.
    /// `health_status` n'est émis qu'au changement de santé ; sans lui, un projet resterait
    /// affiché « starting » puisque DDEV ne le dit « running » qu'une fois ses conteneurs sains.
    public static let watchedActions = ["start", "die", "pause", "unpause", "destroy", "health_status"]

    private let executableURL: URL?
    private let locator: ExecutableLocator
    private let baseEnvironment: [String: String]

    public init(
        executableURL: URL? = nil,
        locator: ExecutableLocator = ExecutableLocator(executableName: "docker"),
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.executableURL = executableURL
        self.locator = locator
        self.baseEnvironment = baseEnvironment
    }

    static var arguments: [String] {
        // Un même filtre répété est un OU, des filtres différents un ET.
        ["events", "--format", "{{json .}}", "--filter", "type=container", "--filter", "label=com.ddev.site-name"]
            + watchedActions.flatMap { ["--filter", "event=\($0)"] }
    }

    /// Flux sans fin tant que Docker répond ; il se termine (avec une erreur) quand Docker s'arrête.
    /// Arrêter de le lire termine le processus `docker events`.
    public func events() -> AsyncThrowingStream<DockerEvent, any Error> {
        guard let url = executableURL ?? locator.locate() else {
            return AsyncThrowingStream { $0.finish(throwing: DDEVError.dockerNotFound) }
        }
        let directories = [url.deletingLastPathComponent().path] + ProcessEnvironment.extraDirectories()
        let environment = ProcessEnvironment.withExtendedPath(baseEnvironment, adding: directories)
        let lines = ProcessLineStream.lines(url, arguments: Self.arguments, environment: environment)

        return AsyncThrowingStream { continuation in
            let task = Task {
                let decoder = JSONDecoder()
                do {
                    for try await line in lines {
                        if let event = try? decoder.decode(DockerEvent.self, from: line) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch ProcessRunnerError.executableNotFound {
                    continuation.finish(throwing: DDEVError.dockerNotFound)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
