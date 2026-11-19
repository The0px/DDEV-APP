import XCTest
import DDEVKit

final class MockProcessRunner: ProcessRunning, @unchecked Sendable {
    struct Call: Equatable {
        let executableURL: URL
        let arguments: [String]
    }

    private let lock = NSLock()
    private let result: Result<ProcessOutput, any Error>
    private var recordedCalls: [Call] = []

    init(result: Result<ProcessOutput, any Error>) {
        self.result = result
    }

    var calls: [Call] {
        lock.withLock { recordedCalls }
    }

    func run(_ executableURL: URL, arguments: [String]) async throws -> ProcessOutput {
        lock.withLock { recordedCalls.append(Call(executableURL: executableURL, arguments: arguments)) }
        return try result.get()
    }
}

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
