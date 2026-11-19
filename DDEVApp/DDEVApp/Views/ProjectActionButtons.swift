import AppKit
import DDEVKit
import SwiftUI

/// Actions d'un projet, partagées par la fiche et le menu contextuel de la liste.
struct ProjectActionButtons: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.openURL) private var openURL
    let project: DDEVProject

    var body: some View {
        if project.status == .running {
            Button {
                Task { await store.stop(project) }
            } label: {
                Label("Arrêter", systemImage: "stop.fill")
            }
        } else {
            Button {
                Task { await store.start(project) }
            } label: {
                Label("Démarrer", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }

        Button {
            Task { await store.restart(project) }
        } label: {
            Label("Redémarrer", systemImage: "arrow.triangle.2.circlepath")
        }

        if let url = project.primaryURL {
            Button {
                openURL(url)
            } label: {
                Label("Ouvrir le site", systemImage: "safari")
            }
            .disabled(project.status != .running)
        }

        Button {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.appRoot)])
        } label: {
            Label("Afficher dans le Finder", systemImage: "folder")
        }
    }
}
