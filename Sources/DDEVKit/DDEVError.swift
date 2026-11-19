import Foundation

public enum DDEVError: Error, Equatable, Sendable {
    case ddevNotFound
    case launchFailed(String)
    case nonZeroExit(code: Int32, stderr: String)
    case invalidJSON(String)
    case timedOut(seconds: Int)
    case dockerNotFound
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
        case .dockerNotFound:
            "Le binaire docker est introuvable. Installez Docker Desktop, OrbStack ou Colima."
        case .timedOut(let seconds):
            "ddev ne répond pas après \(seconds) s. Vérifiez que Docker est démarré (Docker Desktop, OrbStack ou Colima) et qu'aucune demande d'autorisation macOS n'attend votre réponse."
        }
    }
}
