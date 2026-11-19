import XCTest
@testable import DDEVKit

final class DDEVProjectDecodingTests: XCTestCase {
    func testDecodesProjectsFromListOutput() throws {
        let projects = try DDEVListResponse.projects(from: Fixture.data("ddev-list"))

        XCTAssertEqual(projects.map(\.name), ["blog", "shop", "legacy"])
        XCTAssertEqual(projects[0], DDEVProject(
            name: "blog",
            status: .running,
            type: "laravel",
            primaryURL: URL(string: "https://blog.ddev.site"),
            appRoot: "/Users/dev/Sites/blog"
        ))
        XCTAssertEqual(projects[1].status, .stopped)
        XCTAssertEqual(projects[1].type, "php")
    }

    func testKeepsUnknownStatusAndTreatsEmptyURLAsNil() throws {
        let legacy = try DDEVListResponse.projects(from: Fixture.data("ddev-list"))[2]

        XCTAssertEqual(legacy.status, .other("project directory missing"))
        XCTAssertNil(legacy.primaryURL)
        XCTAssertEqual(legacy.type, "")
    }

    func testIgnoresUnknownFields() throws {
        let json = #"{"raw":[{"name":"a","approot":"/a","status":"paused","future_field":{"nested":[1,2]}}]}"#

        let projects = try DDEVListResponse.projects(from: Data(json.utf8))

        XCTAssertEqual(projects.first?.status, .paused)
        XCTAssertEqual(projects.first?.type, "")
    }

    func testSkipsMessageLinesBeforeTheList() throws {
        let output = """
        {"level":"warning","msg":"Docker is slow"}
        {"level":"info","msg":"","raw":[{"name":"a","approot":"/a","status":"running"}]}
        """

        let projects = try DDEVListResponse.projects(from: Data(output.utf8))

        XCTAssertEqual(projects.map(\.name), ["a"])
    }

    func testNullRawMeansNoProjects() throws {
        let projects = try DDEVListResponse.projects(from: Data(#"{"level":"info","raw":null}"#.utf8))

        XCTAssertEqual(projects, [])
    }

    func testRejectsOutputWithoutRaw() {
        assertInvalidJSON(#"{"level":"info","msg":"hello"}"#)
    }

    func testRejectsMalformedJSON() {
        assertInvalidJSON("not json")
        assertInvalidJSON("")
        assertInvalidJSON(#"{"raw":[{"status":"running"}]}"#)
    }

    func testStatusRoundTripsThroughEncoding() throws {
        let project = DDEVProject(name: "a", status: .other("starting"), type: "php", primaryURL: nil, appRoot: "/a")

        let decoded = try JSONDecoder().decode(DDEVProject.self, from: JSONEncoder().encode(project))

        XCTAssertEqual(decoded, project)
    }

    private func assertInvalidJSON(_ output: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try DDEVListResponse.projects(from: Data(output.utf8)), file: file, line: line) { error in
            guard case DDEVError.invalidJSON = error else {
                return XCTFail("Erreur inattendue : \(error)", file: file, line: line)
            }
        }
    }
}
