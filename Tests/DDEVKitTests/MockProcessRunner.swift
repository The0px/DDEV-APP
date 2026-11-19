import XCTest
import DDEVKit

final class MockProcessRunner: ProcessRunning, @unchecked Sendable {
    struct Call: Equatable {
        let executableURL: URL
        let arguments: [String]
    }

    private let lock = NSLock()
    private let handler: @Sendable ([String]) async throws -> ProcessOutput
    private var recordedCalls: [Call] = []
    private var recordedEnvironments: [[String: String]?] = []

    init(handler: @escaping @Sendable ([String]) async throws -> ProcessOutput) {
        self.handler = handler
    }

    convenience init(result: Result<ProcessOutput, any Error>) {
        self.init { _ in try result.get() }
    }

    var calls: [Call] {
        lock.withLock { recordedCalls }
    }

    var environments: [[String: String]?] {
        lock.withLock { recordedEnvironments }
    }

    func run(_ executableURL: URL, arguments: [String], environment: [String: String]?) async throws -> ProcessOutput {
        lock.withLock {
            recordedCalls.append(Call(executableURL: executableURL, arguments: arguments))
            recordedEnvironments.append(environment)
        }
        return try await handler(arguments)
    }
}

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
