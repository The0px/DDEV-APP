import XCTest
@testable import DDEVKit

final class ProcessLineStreamTests: XCTestCase {
    private let shell = URL(fileURLWithPath: "/bin/sh")

    func testYieldsLinesIncludingTheLastOneWithoutNewline() async throws {
        let stream = ProcessLineStream.lines(
            shell,
            arguments: ["-c", "printf 'a\\nb\\n'; sleep 0.2; printf 'c\\n\\nd'"],
            environment: nil
        )

        var lines: [String] = []
        for try await line in stream {
            lines.append(String(decoding: line, as: UTF8.self))
        }

        XCTAssertEqual(lines, ["a", "b", "c", "d"])
    }

    func testFailsWithStderrWhenTheProcessExitsWithAnError() async {
        let stream = ProcessLineStream.lines(
            shell,
            arguments: ["-c", "echo 'Cannot connect to the Docker daemon' >&2; exit 1"],
            environment: nil
        )

        do {
            for try await _ in stream {}
            XCTFail("Une erreur était attendue")
        } catch {
            XCTAssertEqual(error as? DDEVError, .nonZeroExit(code: 1, stderr: "Cannot connect to the Docker daemon"))
        }
    }

    func testMissingExecutableFailsImmediately() async {
        let stream = ProcessLineStream.lines(URL(fileURLWithPath: "/nowhere/docker"), arguments: [], environment: nil)

        do {
            for try await _ in stream {}
            XCTFail("Une erreur était attendue")
        } catch {
            XCTAssertEqual(error as? ProcessRunnerError, .executableNotFound("/nowhere/docker"))
        }
    }

    func testStoppingTheConsumerEndsTheStream() async throws {
        let shell = shell
        let started = ContinuousClock.now
        let task = Task {
            var count = 0
            for try await _ in ProcessLineStream.lines(shell, arguments: ["-c", "while true; do echo x; sleep 0.05; done"], environment: nil) {
                count += 1
            }
            return count
        }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()

        let count = try await task.value

        XCTAssertGreaterThan(count, 0)
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(5))
    }
}
