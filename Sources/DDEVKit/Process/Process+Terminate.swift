import Foundation

extension Process {
    /// Envoie SIGTERM, puis SIGKILL si le processus tourne encore après le délai :
    /// ddev intercepte SIGTERM et reste bloqué si un appel système attend,
    /// par exemple une demande d'accès macOS au dossier Documents.
    func terminate(killingAfter delay: TimeInterval = 2) {
        guard isRunning else { return }
        terminate()
        let pid = processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
            if isRunning { kill(pid, SIGKILL) }
        }
    }
}
