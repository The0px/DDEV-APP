import DDEVKit
import SwiftUI

struct ProjectRow: View {
    @Environment(ProjectStore.self) private var store
    let project: DDEVProject

    var body: some View {
        HStack(spacing: 10) {
            if store.isBusy(project) {
                ProgressView().controlSize(.small)
            } else {
                Circle()
                    .fill(project.status.color)
                    .frame(width: 9, height: 9)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name).font(.body.weight(.medium))
                Text(project.type.isEmpty ? project.status.label : "\(project.type) · \(project.status.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
