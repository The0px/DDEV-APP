import Foundation

/// Lance un vrai processus avec `Process`.
public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    public func run(_ executableURL: URL, arguments: [String], environment: [String: String]?) async throws -> ProcessOutput {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if let environment { process.environment = environment }
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        // Le gestionnaire est posé avant run() : le processus peut se terminer avant qu'on l'attende.
        let exit = ExitStatus()
        process.terminationHandler = { exit.resolve($0.terminationStatus) }

        do {
            try process.run()
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            throw ProcessRunnerError.executableNotFound(executableURL.path)
        } catch {
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }

        return await withTaskCancellationHandler {
            // Les deux tubes sont lus en parallèle : un tampon plein bloquerait le processus.
            async let stdout = Self.readToEnd(stdoutPipe.fileHandleForReading)
            async let stderr = Self.readToEnd(stderrPipe.fileHandleForReading)
            let (out, err) = await (stdout, stderr)
            return ProcessOutput(exitCode: await exit.value, stdout: out, stderr: err)
        } onCancel: {
            process.terminate()
            // ddev intercepte SIGTERM et reste bloqué si un appel système attend,
            // par exemple une demande d'accès macOS au dossier Documents.
            let pid = process.processIdentifier
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if process.isRunning { kill(pid, SIGKILL) }
            }
        }
    }

    private static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }
}

/// Code de sortie attendu sans bloquer de thread.
private final class ExitStatus: @unchecked Sendable {
    private let lock = NSLock()
    private var status: Int32?
    private var waiter: CheckedContinuation<Int32, Never>?

    func resolve(_ code: Int32) {
        lock.lock()
        status = code
        let pending = waiter
        waiter = nil
        lock.unlock()
        pending?.resume(returning: code)
    }

    var value: Int32 {
        get async {
            await withCheckedContinuation { continuation in
                lock.lock()
                if let status {
                    lock.unlock()
                    continuation.resume(returning: status)
                } else {
                    waiter = continuation
                    lock.unlock()
                }
            }
        }
    }
}
