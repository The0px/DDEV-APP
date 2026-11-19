import DDEVKit
import SwiftUI

struct ProjectRow: View {
    @Environment(ProjectStore.self) private var store
    let project: DDEVProject

    var body: some View {
        HStack(spacing: 10) {
            // Largeur fixe : l'indicateur d'action est plus large que la pastille et décalerait le texte.
            Group {
                if store.isBusy(project) {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Action en cours")
                } else {
                    StatusDot(status: project.status)
                }
            }
            .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name).font(.body.weight(.medium))
                Text(project.type.isEmpty ? project.status.label : "\(project.type) · \(project.status.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}
