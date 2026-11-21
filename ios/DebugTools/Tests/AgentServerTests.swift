#if DEBUG
import ComposableArchitecture
import DebugTools
import Foundation
import XCTest

/// The agent driver's transport: off unless `-fpDriver` asks on a simulator, loopback only, and one
/// HTTP request in, one JSON answer out.
@MainActor
final class AgentServerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }

    func testDriverFlag() {
        XCTAssertTrue(LaunchOptions(arguments: ["App", "-fpDriver"], calendar: calendar).drivesAgent)
        XCTAssertFalse(LaunchOptions(arguments: ["App"], calendar: calendar).drivesAgent)
    }

    /// Nothing listens without the flag. With it the driver serves on the iPad too: test mode keeps
    /// the family in memory there (user, 2026-11-21).
    func testDriverPortOnlyWithTheFlag() throws {
        XCTAssertEqual(try installed(["App", "-fpDriver"], simulator: true).driverPort, AgentServer.port)
        XCTAssertEqual(try installed(["App", "-fpDriver"], simulator: false).driverPort, AgentServer.port)
        XCTAssertNil(try installed(["App"], simulator: true).driverPort)
        XCTAssertNil(try installed(["App"], simulator: false).driverPort)
    }

    func testRequestNeedsItsWholeBody() {
        let head = "POST /do HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: 10\r\n\r\n"
        XCTAssertNil(AgentServer.request(from: Data((head + "{\"a\":").utf8)), "body still arriving")
        XCTAssertNil(AgentServer.request(from: Data("GET /ls HTTP/1.1\r\nHost: x".utf8)), "head still arriving")
        let whole = AgentServer.request(from: Data((head + "{\"a\": 12 }").utf8))  // 10 bytes
        XCTAssertEqual(whole, AgentServer.Request(method: "POST", path: "/do", body: Data("{\"a\": 12 }".utf8)))
        XCTAssertEqual(AgentServer.request(from: Data("GET /ls HTTP/1.1\r\n\r\n".utf8))?.path, "/ls")
    }

    func testResponseBytes() {
        let bytes = AgentServer.bytes(of: AgentServer.Response(status: 200, body: Data("{}".utf8)))
        XCTAssertEqual(String(decoding: bytes, as: UTF8.self),
                       "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}")
    }

    /// A real request over loopback reaches `handle` and its answer comes back.
    func testServesOverLoopback() async throws {
        let port: UInt16 = 8791
        let server = Task {
            await AgentServer.serve(port: port) { request in
                AgentServer.Response(status: 200, body: Data("{\"path\":\"\(request.path)\"}".utf8))
            }
        }
        defer { server.cancel() }
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/ls"))
        var answer: Data?
        for _ in 0..<20 where answer == nil {
            answer = try? await URLSession.shared.data(from: url).0
            if answer == nil { try await Task.sleep(for: .milliseconds(100)) }
        }
        XCTAssertEqual(answer.map { String(decoding: $0, as: UTF8.self) }, "{\"path\":\"/ls\"}")
    }

    private func installed(_ arguments: [String], simulator: Bool) throws -> DebugModel {
        let suite = "fp.debug.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        var dependencies = DependencyValues()
        dependencies.calendar = calendar
        DebugModel.install(into: &dependencies, arguments: arguments, defaults: defaults,
                           allowsSkipFaceID: simulator)
        return try XCTUnwrap(dependencies.debugTools)
    }
}
#endif
