import DDEVKit
import SwiftUI

/// Écran affiché quand aucun projet ne peut être montré.
struct EmptyStateView: View {
    @Environment(ProjectStore.self) private var store
    let error: DDEVError?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            Button("Réessayer") {
                Task { await store.refresh() }
            }
            .disabled(store.isRefreshing)
        }
    }

    private var title: String {
        switch error {
        case .ddevNotFound: "DDEV est introuvable"
        case .some: "Impossible de lire les projets"
        case nil: "Aucun projet DDEV"
        }
    }

    private var systemImage: String {
        switch error {
        case .ddevNotFound: "shippingbox"
        case .some: "exclamationmark.triangle"
        case nil: "tray"
        }
    }

    private var message: String {
        switch error {
        case .ddevNotFound:
            "Installez DDEV (par exemple avec « brew install ddev/ddev/ddev ») puis réessayez."
        case .some(let error):
            error.localizedDescription
        case nil:
            "Créez un projet avec « ddev config » dans le dossier d'un site, puis rafraîchissez."
        }
    }
}
