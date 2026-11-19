import Foundation

/// Lance un vrai processus avec `Process`.
public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    public func run(_ executableURL: URL, arguments: [String]) async throws -> ProcessOutput {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            throw ProcessRunnerError.executableNotFound(executableURL.path)
        } catch {
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }

        // Les deux tubes sont lus en parallèle : un tampon plein bloquerait le processus.
        async let stdout = Self.readToEnd(stdoutPipe.fileHandleForReading)
        async let stderr = Self.readToEnd(stderrPipe.fileHandleForReading)
        let (out, err) = await (stdout, stderr)
        let exitCode = await Self.waitForExit(process)
        return ProcessOutput(exitCode: exitCode, stdout: out, stderr: err)
    }

    private static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }

    private static func waitForExit(_ process: Process) async -> Int32 {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus)
            }
        }
    }
}
