import DDEVKit
import SwiftUI

/// La couleur reste sur la pastille : en texte, le vert et l'orange système
/// passent sous 3:1 en mode clair.
struct StatusBadge: View {
    let status: DDEVProjectStatus

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(status: status)
            Text(status.label)
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.15), in: Capsule())
    }
}

struct StatusDot: View {
    let status: DDEVProjectStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

extension DDEVProjectStatus {
    var label: String {
        switch self {
        case .running: "En cours"
        case .starting: "Démarrage"
        case .stopped: "Arrêté"
        case .paused: "En pause"
        case .other(let value): value.isEmpty ? "Inconnu" : value
        }
    }

    var color: Color {
        switch self {
        case .running: .green
        case .starting: .yellow
        case .stopped: .secondary
        case .paused: .orange
        case .other: .red
        }
    }
}
