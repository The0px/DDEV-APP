import XCTest
@testable import DDEVKit

final class DockerEventsTests: XCTestCase {
    func testDecodesCurrentDockerFormat() throws {
        let json = #"{"Type":"container","Action":"start","Actor":{"ID":"abc","Attributes":{"com.ddev.site-name":"blog","image":"ddev/ddev-webserver"}},"scope":"local","time":1795110000,"timeNano":1795110000000000000}"#

        let event = try JSONDecoder().decode(DockerEvent.self, from: Data(json.utf8))

        XCTAssertEqual(event, DockerEvent(action: "start", projectName: "blog"))
    }

    func testDecodesLegacyStatusField() throws {
        let event = try JSONDecoder().decode(DockerEvent.self, from: Data(#"{"status":"die","id":"abc"}"#.utf8))

        XCTAssertEqual(event, DockerEvent(action: "die", projectName: nil))
    }

    func testArgumentsFilterDDEVContainerStateChanges() {
        let arguments = DockerEventsClient.arguments

        XCTAssertEqual(Array(arguments.prefix(3)), ["events", "--format", "{{json .}}"])
        XCTAssertTrue(arguments.contains("label=com.ddev.site-name"))
        XCTAssertTrue(arguments.contains("event=die"))
        XCTAssertTrue(arguments.contains("event=health_status"))
        XCTAssertFalse(arguments.contains { $0.hasPrefix("event=exec") })
    }

    func testStreamsEventsFromTheDockerProcessAndSkipsInvalidLines() async throws {
        let script = try makeFakeDocker("""
        #!/bin/sh
        echo '{"Action":"start","Actor":{"Attributes":{"com.ddev.site-name":"blog"}}}'
        echo 'pas du json'
        echo '{"Action":"die","Actor":{"Attributes":{"com.ddev.site-name":"shop"}}}'
        """)

        var events: [DockerEvent] = []
        for try await event in DockerEventsClient(executableURL: script).events() {
            events.append(event)
        }

        XCTAssertEqual(events, [DockerEvent(action: "start", projectName: "blog"), DockerEvent(action: "die", projectName: "shop")])
    }

    func testFailsWhenDockerIsMissing() async {
        let locator = ExecutableLocator(executableName: "docker", searchDirectories: [], isExecutable: { _ in false })

        do {
            for try await _ in DockerEventsClient(locator: locator).events() {}
            XCTFail("Une erreur était attendue")
        } catch {
            XCTAssertEqual(error as? DDEVError, .dockerNotFound)
        }
    }

    private func makeFakeDocker(_ contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("docker")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }
}
