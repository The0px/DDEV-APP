import XCTest
@testable import DDEVKit

final class DDEVClientTests: XCTestCase {
    private let ddevURL = URL(fileURLWithPath: "/opt/homebrew/bin/ddev")

    func testListProjectsRunsDDEVAndDecodesOutput() async throws {
        let runner = MockProcessRunner(result: .success(ProcessOutput(exitCode: 0, stdout: try Fixture.data("ddev-list"))))
        let client = DDEVClient(executableURL: ddevURL, runner: runner)

        let projects = try await client.listProjects()

        XCTAssertEqual(projects.count, 3)
        XCTAssertEqual(runner.calls, [.init(executableURL: ddevURL, arguments: ["list", "--json-output"])])
    }

    func testThrowsNotFoundWhenLocatorFindsNothing() async {
        let runner = MockProcessRunner(result: .success(ProcessOutput(exitCode: 0)))
        let locator = DDEVLocator(searchDirectories: ["/nowhere"], isExecutable: { _ in false })
        let client = DDEVClient(runner: runner, locator: locator)

        await assertListProjects(client, throws: .ddevNotFound)
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testThrowsNotFoundWhenExecutableIsMissing() async {
        let runner = MockProcessRunner(result: .failure(ProcessRunnerError.executableNotFound(ddevURL.path)))

        await assertListProjects(DDEVClient(executableURL: ddevURL, runner: runner), throws: .ddevNotFound)
    }

    func testThrowsLaunchFailed() async {
        let runner = MockProcessRunner(result: .failure(ProcessRunnerError.launchFailed("permission denied")))

        await assertListProjects(DDEVClient(executableURL: ddevURL, runner: runner), throws: .launchFailed("permission denied"))
    }

    func testThrowsNonZeroExitWithTrimmedStderr() async {
        let output = ProcessOutput(exitCode: 1, stderr: Data("Docker is not running\n".utf8))
        let runner = MockProcessRunner(result: .success(output))

        await assertListProjects(
            DDEVClient(executableURL: ddevURL, runner: runner),
            throws: .nonZeroExit(code: 1, stderr: "Docker is not running")
        )
    }

    func testThrowsInvalidJSON() async {
        let runner = MockProcessRunner(result: .success(ProcessOutput(exitCode: 0, stdout: Data("oops".utf8))))

        do {
            _ = try await DDEVClient(executableURL: ddevURL, runner: runner).listProjects()
            XCTFail("Une erreur était attendue")
        } catch {
            guard case .invalidJSON = error else { return XCTFail("Erreur inattendue : \(error)") }
        }
    }

    func testLocatorReturnsFirstExecutableCandidate() {
        let locator = DDEVLocator(
            searchDirectories: ["/usr/bin", "/opt/homebrew/bin", "/usr/local/bin"],
            isExecutable: { $0 != "/usr/bin/ddev" }
        )

        XCTAssertEqual(locator.locate(), ddevURL)
    }

    func testDefaultSearchDirectoriesAddHomebrewWithoutDuplicates() {
        let directories = DDEVLocator.defaultSearchDirectories(environment: ["PATH": "/usr/bin:/opt/homebrew/bin"])

        XCTAssertEqual(directories, ["/usr/bin", "/opt/homebrew/bin", "/usr/local/bin"])
    }

    private func assertListProjects(
        _ client: DDEVClient,
        throws expected: DDEVError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await client.listProjects()
            XCTFail("Une erreur était attendue", file: file, line: line)
        } catch {
            XCTAssertEqual(error, expected, file: file, line: line)
        }
    }
}
