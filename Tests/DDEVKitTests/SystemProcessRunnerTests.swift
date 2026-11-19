import XCTest
@testable import DDEVKit

/// Lance de vrais processus `/bin/sh` : vérifie la lecture des tubes et l'arrêt forcé.
final class SystemProcessRunnerTests: XCTestCase {
    private let shell = URL(fileURLWithPath: "/bin/sh")

    func testCapturesOutputAndExitCode() async throws {
        let output = try await SystemProcessRunner().run(
            shell,
            arguments: ["-c", "echo sortie; echo erreur >&2; exit 3"],
            environment: nil
        )

        XCTAssertEqual(output.exitCode, 3)
        XCTAssertEqual(String(decoding: output.stdout, as: UTF8.self), "sortie\n")
        XCTAssertEqual(String(decoding: output.stderr, as: UTF8.self), "erreur\n")
    }

    func testPassesEnvironment() async throws {
        let output = try await SystemProcessRunner().run(
            shell,
            arguments: ["-c", "printf %s \"$DDEVKIT_TEST\""],
            environment: ["DDEVKIT_TEST": "ok"]
        )

        XCTAssertEqual(String(decoding: output.stdout, as: UTF8.self), "ok")
    }

    func testMissingExecutableThrowsNotFound() async {
        do {
            _ = try await SystemProcessRunner().run(URL(fileURLWithPath: "/nowhere/ddev"), arguments: [], environment: nil)
            XCTFail("Une erreur était attendue")
        } catch {
            XCTAssertEqual(error as? ProcessRunnerError, .executableNotFound("/nowhere/ddev"))
        }
    }

    func testCancellationKillsProcessThatIgnoresSIGTERM() async throws {
        let started = ContinuousClock.now
        let shell = shell
        let task = Task {
            try await SystemProcessRunner().run(shell, arguments: ["-c", "trap '' TERM; exec sleep 30"], environment: nil)
        }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()

        let output = try await task.value

        XCTAssertLessThan(ContinuousClock.now - started, .seconds(10))
        XCTAssertNotEqual(output.exitCode, 0)
    }
}
