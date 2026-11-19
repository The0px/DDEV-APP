import DDEVKit
import SwiftUI

struct StatusBadge: View {
    let status: DDEVProjectStatus

    var body: some View {
        Text(status.label)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.15), in: Capsule())
    }
}

extension DDEVProjectStatus {
    var label: String {
        switch self {
        case .running: "En cours"
        case .stopped: "Arrêté"
        case .paused: "En pause"
        case .other(let value): value.isEmpty ? "Inconnu" : value
        }
    }

    var color: Color {
        switch self {
        case .running: .green
        case .stopped: .secondary
        case .paused: .orange
        case .other: .red
        }
    }
}
