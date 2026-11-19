import Foundation
import Observation

/// État des projets DDEV partagé par l'interface.
@MainActor
@Observable
public final class ProjectStore {
    public typealias EventSource = @Sendable () -> AsyncThrowingStream<DockerEvent, any Error>

    public private(set) var projects: [DDEVProject] = []
    public private(set) var hasLoaded = false
    public private(set) var isRefreshing = false
    /// Noms des projets dont une action `ddev` est en cours.
    public private(set) var busyProjects: Set<String> = []
    public var lastError: DDEVError?

    private let client: DDEVClient
    private let events: EventSource?
    private let refreshDelay: Duration
    private let reconnectDelay: Duration
    @ObservationIgnored private var refreshRequested = false
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?

    /// - Parameters:
    ///   - events: source des events Docker ; `nil` désactive le rafraîchissement automatique.
    ///   - refreshDelay: un `ddev start` émet une rafale d'events, relus en un seul `ddev list`.
    ///   - reconnectDelay: attente avant de réécouter Docker après son arrêt.
    public init(
        client: DDEVClient = DDEVClient(),
        events: EventSource? = { DockerEventsClient().events() },
        refreshDelay: Duration = .milliseconds(500),
        reconnectDelay: Duration = .seconds(5)
    ) {
        self.client = client
        self.events = events
        self.refreshDelay = refreshDelay
        self.reconnectDelay = reconnectDelay
    }

    /// Une demande reçue pendant une lecture en relance une à la fin, pour ne pas garder un état périmé.
    public func refresh() async {
        guard !isRefreshing else {
            refreshRequested = true
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        repeat {
            refreshRequested = false
            do {
                projects = try await client.listProjects()
                lastError = nil
            } catch {
                lastError = error
            }
        } while refreshRequested
        hasLoaded = true
    }

    /// Écoute Docker jusqu'à l'annulation de la tâche appelante et rafraîchit après chaque rafale d'events.
    public func watchDockerEvents() async {
        guard let events else { return }
        while !Task.isCancelled {
            do {
                for try await _ in events() {
                    scheduleRefresh()
                }
            } catch {
                // Docker arrêté ou introuvable : on réessaie plus tard, sans bruit dans l'interface.
            }
            try? await Task.sleep(for: reconnectDelay)
        }
        pendingRefresh?.cancel()
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

    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [refreshDelay] in
            do {
                try await Task.sleep(for: refreshDelay)
            } catch {
                return
            }
            await refresh()
        }
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
