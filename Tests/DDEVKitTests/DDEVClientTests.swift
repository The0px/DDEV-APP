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

    func testProjectActionsPassTheProjectName() async throws {
        let runner = MockProcessRunner(result: .success(ProcessOutput(exitCode: 0)))
        let client = DDEVClient(executableURL: ddevURL, runner: runner)
        let project = DDEVProject(name: "blog", status: .stopped, type: "laravel", primaryURL: nil, appRoot: "/a")

        try await client.start(project)
        try await client.stop(project)
        try await client.restart(project)

        XCTAssertEqual(runner.calls.map(\.arguments), [["start", "blog"], ["stop", "blog"], ["restart", "blog"]])
    }

    func testExtendsPathSoDDEVFindsDocker() async throws {
        let runner = MockProcessRunner(result: .success(ProcessOutput(exitCode: 0, stdout: Data(#"{"raw":[]}"#.utf8))))
        let client = DDEVClient(
            executableURL: URL(fileURLWithPath: "/custom/bin/ddev"),
            runner: runner,
            baseEnvironment: ["PATH": "/usr/bin:/opt/homebrew/bin", "HOME": "/Users/dev"]
        )

        _ = try await client.listProjects()

        let environment = try XCTUnwrap(runner.environments.first ?? nil)
        let path = try XCTUnwrap(environment["PATH"]).split(separator: ":").map(String.init)
        XCTAssertEqual(Array(path.prefix(3)), ["/usr/bin", "/opt/homebrew/bin", "/custom/bin"])
        XCTAssertTrue(path.contains("/usr/local/bin"))
        XCTAssertEqual(path.count, Set(path).count)
        XCTAssertEqual(environment["HOME"], "/Users/dev")
    }

    func testThrowsNotFoundWhenLocatorFindsNothing() async {
        let runner = MockProcessRunner(result: .success(ProcessOutput(exitCode: 0)))
        let locator = ExecutableLocator(executableName: "ddev", searchDirectories: ["/nowhere"], isExecutable: { _ in false })
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

    func testThrowsTimedOutWhenDDEVHangs() async {
        let runner = MockProcessRunner { _ in
            try await Task.sleep(for: .seconds(30))
            return ProcessOutput(exitCode: 0)
        }
        let client = DDEVClient(executableURL: ddevURL, runner: runner, listTimeout: .milliseconds(50))

        await assertListProjects(client, throws: .timedOut(seconds: 0))
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
        let locator = ExecutableLocator(
            executableName: "ddev",
            searchDirectories: ["/usr/bin", "/opt/homebrew/bin", "/usr/local/bin"],
            isExecutable: { $0 != "/usr/bin/ddev" }
        )

        XCTAssertEqual(locator.locate(), ddevURL)
    }

    func testDefaultSearchDirectoriesAddKnownFoldersWithoutDuplicates() {
        let directories = ExecutableLocator.defaultSearchDirectories(
            environment: ["PATH": "/usr/bin:/opt/homebrew/bin"],
            home: "/Users/dev"
        )

        XCTAssertEqual(directories, ["/usr/bin", "/opt/homebrew/bin", "/usr/local/bin", "/Users/dev/.orbstack/bin"])
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
