import Foundation
import Observation

/// État des projets DDEV partagé par l'interface.
@MainActor
@Observable
public final class ProjectStore {
    public private(set) var projects: [DDEVProject] = []
    public private(set) var hasLoaded = false
    public private(set) var isRefreshing = false
    /// Noms des projets dont une action `ddev` est en cours.
    public private(set) var busyProjects: Set<String> = []
    public var lastError: DDEVError?

    private let client: DDEVClient

    public init(client: DDEVClient = DDEVClient()) {
        self.client = client
    }

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            projects = try await client.listProjects()
            lastError = nil
        } catch {
            lastError = error
        }
        hasLoaded = true
    }

    public func isBusy(_ project: DDEVProject) -> Bool {
        busyProjects.contains(project.name)
    }

    public func start(_ project: DDEVProject) async {
        await perform(on: project) { (client) throws(DDEVError) in try await client.start(project) }
    }

    public func stop(_ project: DDEVProject) async {
        await perform(on: project) { (client) throws(DDEVError) in try await client.stop(project) }
    }

    public func restart(_ project: DDEVProject) async {
        await perform(on: project) { (client) throws(DDEVError) in try await client.restart(project) }
    }

    private func perform(
        on project: DDEVProject,
        _ action: @Sendable (DDEVClient) async throws(DDEVError) -> Void
    ) async {
        guard busyProjects.insert(project.name).inserted else { return }
        defer { busyProjects.remove(project.name) }

        var actionError: DDEVError?
        do {
            try await action(client)
        } catch {
            actionError = error
        }
        // L'état réel du projet est relu même après un échec, car ddev a pu s'arrêter à mi-chemin.
        await refresh()
        if let actionError { lastError = actionError }
    }
}
