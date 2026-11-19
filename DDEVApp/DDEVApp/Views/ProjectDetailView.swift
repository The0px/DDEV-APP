import DDEVKit
import SwiftUI

struct ProjectDetailView: View {
    @Environment(ProjectStore.self) private var store
    let project: DDEVProject

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                details
                HStack(spacing: 10) {
                    ProjectActionButtons(project: project)
                }
                .controlSize(.large)
                .disabled(store.isBusy(project))
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(project.name)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(project.name).font(.largeTitle.weight(.semibold))
            StatusBadge(status: project.status)
            if store.isBusy(project) {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var details: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                Text("Type").foregroundStyle(.secondary)
                Text(project.type.isEmpty ? "Non défini" : project.type)
            }
            GridRow {
                Text("Dossier").foregroundStyle(.secondary)
                Text(project.appRoot)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            GridRow {
                Text("URL").foregroundStyle(.secondary)
                if let url = project.primaryURL {
                    Link(url.absoluteString, destination: url)
                } else {
                    Text("Aucune").foregroundStyle(.secondary)
                }
            }
        }
    }
}
