import XCTest
@testable import DDEVKit

@MainActor
final class ProjectStoreTests: XCTestCase {
    private let ddevURL = URL(fileURLWithPath: "/opt/homebrew/bin/ddev")
    private let blog = DDEVProject(name: "blog", status: .stopped, type: "laravel", primaryURL: nil, appRoot: "/a")

    func testRefreshLoadsProjects() async throws {
        let fixture = try Fixture.data("ddev-list")
        let store = makeStore { _ in ProcessOutput(exitCode: 0, stdout: fixture) }

        await store.refresh()

        XCTAssertTrue(store.hasLoaded)
        XCTAssertEqual(store.projects.map(\.name), ["blog", "shop", "legacy"])
        XCTAssertNil(store.lastError)
    }

    func testRefreshExposesErrorWhenDDEVIsMissing() async {
        let runner = MockProcessRunner(result: .success(ProcessOutput(exitCode: 0)))
        let locator = ExecutableLocator(executableName: "ddev", searchDirectories: [], isExecutable: { _ in false })
        let store = ProjectStore(client: DDEVClient(runner: runner, locator: locator))

        await store.refresh()

        XCTAssertTrue(store.hasLoaded)
        XCTAssertEqual(store.lastError, .ddevNotFound)
    }

    func testStartRunsDDEVThenRefreshes() async throws {
        let fixture = try Fixture.data("ddev-list")
        let runner = MockProcessRunner { arguments in
            arguments.first == "list" ? ProcessOutput(exitCode: 0, stdout: fixture) : ProcessOutput(exitCode: 0)
        }
        let store = ProjectStore(client: DDEVClient(executableURL: ddevURL, runner: runner))

        await store.start(blog)

        XCTAssertEqual(runner.calls.map(\.arguments), [["start", "blog"], ["list", "--json-output"]])
        XCTAssertEqual(store.projects.count, 3)
        XCTAssertTrue(store.busyProjects.isEmpty)
    }

    func testFailedActionKeepsItsErrorAfterRefresh() async throws {
        let fixture = try Fixture.data("ddev-list")
        let store = makeStore { arguments in
            arguments.first == "list"
                ? ProcessOutput(exitCode: 0, stdout: fixture)
                : ProcessOutput(exitCode: 1, stderr: Data("port 80 busy".utf8))
        }

        await store.stop(blog)

        XCTAssertEqual(store.lastError, .nonZeroExit(code: 1, stderr: "port 80 busy"))
        XCTAssertEqual(store.projects.count, 3)
        XCTAssertFalse(store.isBusy(blog))
    }

    func testBurstOfDockerEventsTriggersASingleRefresh() async throws {
        let fixture = try Fixture.data("ddev-list")
        let runner = MockProcessRunner { _ in ProcessOutput(exitCode: 0, stdout: fixture) }
        let burst: ProjectStore.EventSource = {
            AsyncThrowingStream { continuation in
                for action in ["start", "start", "die", "start", "start"] {
                    continuation.yield(DockerEvent(action: action, projectName: "blog"))
                }
                continuation.finish()
            }
        }
        let store = ProjectStore(
            client: DDEVClient(executableURL: ddevURL, runner: runner),
            events: burst,
            refreshDelay: .milliseconds(50),
            reconnectDelay: .seconds(60)
        )

        let watcher = Task { await store.watchDockerEvents() }
        try await Task.sleep(for: .milliseconds(400))
        watcher.cancel()
        await watcher.value

        XCTAssertEqual(runner.calls.count, 1)
        XCTAssertEqual(store.projects.count, 3)
    }

    func testRefreshRequestedDuringARefreshRunsOnceMore() async throws {
        let fixture = try Fixture.data("ddev-list")
        let runner = MockProcessRunner { _ in
            try await Task.sleep(for: .milliseconds(100))
            return ProcessOutput(exitCode: 0, stdout: fixture)
        }
        let store = ProjectStore(client: DDEVClient(executableURL: ddevURL, runner: runner), events: nil)

        let first = Task { await store.refresh() }
        try await Task.sleep(for: .milliseconds(20))
        await store.refresh()
        await store.refresh()
        await first.value

        XCTAssertEqual(runner.calls.count, 2)
        XCTAssertFalse(store.isRefreshing)
    }

    private func makeStore(_ handler: @escaping @Sendable ([String]) async throws -> ProcessOutput) -> ProjectStore {
        ProjectStore(client: DDEVClient(executableURL: ddevURL, runner: MockProcessRunner(handler: handler)))
    }
}
