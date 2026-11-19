import Foundation

/// Lance un processus de longue durée (`docker events`) et publie sa sortie standard ligne par ligne.
/// Aucun thread n'attend : les tubes sont lus par des sources dispatch (`readabilityHandler`).
enum ProcessLineStream {
    static func lines(
        _ executableURL: URL,
        arguments: [String],
        environment: [String: String]?
    ) -> AsyncThrowingStream<Data, any Error> {
        // Un consommateur lent perd les lignes les plus anciennes plutôt que de faire grossir la mémoire.
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            if let environment { process.environment = environment }
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.standardInput = FileHandle.nullDevice

            let state = LineStreamState()
            let finishIfDone: @Sendable () -> Void = {
                guard let result = state.completion() else { return }
                switch result {
                case .success: continuation.finish()
                case .failure(let error): continuation.finish(throwing: error)
                }
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    if let last = state.markStdoutClosed() { continuation.yield(last) }
                    finishIfDone()
                } else {
                    for line in state.appendStdout(chunk) { continuation.yield(line) }
                }
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    state.appendStderr(chunk)
                }
            }
            process.terminationHandler = { finished in
                state.markExited(finished.terminationStatus)
                finishIfDone()
            }
            continuation.onTermination = { _ in
                process.terminate(killingAfter: 2)
            }

            do {
                try process.run()
            } catch let error as CocoaError where error.code == .fileNoSuchFile {
                continuation.finish(throwing: ProcessRunnerError.executableNotFound(executableURL.path))
            } catch {
                continuation.finish(throwing: ProcessRunnerError.launchFailed(error.localizedDescription))
            }
        }
    }
}

/// Découpe la sortie en lignes et attend la fin du tube et du processus avant de clore le flux,
/// pour ne perdre aucune ligne écrite juste avant la sortie.
private final class LineStreamState: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var stderr = Data()
    private var stdoutClosed = false
    private var exitCode: Int32?
    private var completed = false

    func appendStdout(_ chunk: Data) -> [Data] {
        lock.withLock {
            buffer.append(chunk)
            var lines: [Data] = []
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[buffer.startIndex..<newline]
                if !line.isEmpty { lines.append(Data(line)) }
                buffer.removeSubrange(buffer.startIndex...newline)
            }
            return lines
        }
    }

    func appendStderr(_ chunk: Data) {
        lock.withLock { stderr.append(chunk) }
    }

    /// Renvoie la dernière ligne sans retour à la ligne final, s'il y en a une.
    func markStdoutClosed() -> Data? {
        lock.withLock {
            stdoutClosed = true
            defer { buffer.removeAll() }
            return buffer.isEmpty ? nil : buffer
        }
    }

    func markExited(_ code: Int32) {
        lock.withLock { exitCode = code }
    }

    /// Résultat à transmettre une seule fois, quand le tube est fermé et le processus terminé.
    func completion() -> Result<Void, DDEVError>? {
        lock.withLock {
            guard stdoutClosed, let exitCode, !completed else { return nil }
            completed = true
            guard exitCode == 0 else {
                let message = String(decoding: stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                return .failure(.nonZeroExit(code: exitCode, stderr: message))
            }
            return .success(())
        }
    }
}
