import Foundation

public enum DDEVError: Error, Equatable, Sendable {
    case ddevNotFound
    case launchFailed(String)
    case nonZeroExit(code: Int32, stderr: String)
    case invalidJSON(String)
}

extension DDEVError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ddevNotFound:
            "Le binaire ddev est introuvable. Installez DDEV ou indiquez son chemin."
        case .launchFailed(let reason):
            "Impossible de lancer ddev : \(reason)"
        case .nonZeroExit(let code, let stderr):
            stderr.isEmpty ? "ddev s'est terminé avec le code \(code)." : "ddev s'est terminé avec le code \(code) : \(stderr)"
        case .invalidJSON(let reason):
            "La sortie JSON de ddev est invalide : \(reason)"
        }
    }
}
