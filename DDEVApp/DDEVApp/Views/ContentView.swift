import DDEVKit
import SwiftUI

struct ContentView: View {
    @Environment(ProjectStore.self) private var store
    @State private var selection: DDEVProject.ID?

    var body: some View {
        Group {
            if !store.hasLoaded {
                ProgressView("Lecture des projets DDEV…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.projects.isEmpty {
                EmptyStateView(error: store.lastError)
            } else {
                projectsSplitView
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Rafraîchir", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
                .disabled(store.isRefreshing)
                .help("Relire la liste des projets (⌘R)")
            }
        }
        .task {
            await store.refresh()
            selection = selection ?? store.projects.first?.id
        }
    }

    private var projectsSplitView: some View {
        NavigationSplitView {
            List(store.projects, selection: $selection) { project in
                ProjectRow(project: project)
                    .contextMenu { ProjectActionButtons(project: project) }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let project = store.projects.first(where: { $0.id == selection }) {
                ProjectDetailView(project: project)
            } else {
                ContentUnavailableView("Aucun projet sélectionné", systemImage: "sidebar.left",
                                       description: Text("Choisissez un projet dans la liste."))
            }
        }
        .alert(
            "L'opération DDEV a échoué",
            isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } }),
            presenting: store.lastError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
