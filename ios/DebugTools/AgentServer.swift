#if DEBUG
import Foundation
import Network

/// The agent driver's transport (ios/Journeys/Tests/Driver/PROTOCOL.md): plain HTTP on 127.0.0.1
/// only, started by `-fpDriver` on a simulator (`DebugModel.driverPort`). `GET /ls` and
/// `POST /do` reach the app through `handle`; the app answers with JSON. One request per connection.
public enum AgentServer {
    /// Not the board (8765) or WebDriverAgent (8100).
    public static let port: UInt16 = 8790

    public struct Request: Equatable, Sendable {
        public var method: String
        public var path: String
        public var body: Data

        public init(method: String, path: String, body: Data) {
            self.method = method
            self.path = path
            self.body = body
        }
    }

    public struct Response: Equatable, Sendable {
        public var status: Int
        public var body: Data

        public init(status: Int, body: Data) {
            self.status = status
            self.body = body
        }
    }

    /// Serves until the calling task is cancelled. Listens on the loopback address only, so nothing
    /// off this machine (or off the simulator's host) can reach it.
    public static func serve(port: UInt16 = port,
                             handle: @escaping @Sendable (Request) async -> Response) async {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { return }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: endpointPort)
        parameters.allowLocalEndpointReuse = true
        let listener: NWListener
        do {
            listener = try NWListener(using: parameters)
        } catch {
            print("AgentServer: cannot listen on 127.0.0.1:\(port): \(error)")
            return
        }
        listener.stateUpdateHandler = { state in print("AgentServer 127.0.0.1:\(port): \(state)") }
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global(qos: .userInitiated))
            receive(on: connection, buffer: Data(), handle: handle)
        }
        listener.start(queue: .global(qos: .userInitiated))
        // An AsyncStream that never yields ends when the task is cancelled.
        let (wait, _) = AsyncStream<Never>.makeStream()
        for await _ in wait {}
        listener.cancel()
    }

    /// One request from the bytes read so far, or nil while its head or body is incomplete.
    public static func request(from data: Data) -> Request? {
        guard let end = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let lines = String(decoding: data[..<end.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
        let start = lines.first?.split(separator: " ").map(String.init) ?? []
        let length = lines.dropFirst().compactMap { line -> Int? in
            let pair = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard pair.count == 2, pair[0].lowercased() == "content-length" else { return nil }
            return Int(pair[1].trimmingCharacters(in: .whitespaces))
        }.first ?? 0
        let body = data[end.upperBound...]
        guard body.count >= length else { return nil }
        return Request(method: start.first ?? "", path: start.count > 1 ? start[1] : "",
                       body: Data(body.prefix(length)))
    }

    /// The bytes of an HTTP/1.1 response with a JSON body; the connection closes after it.
    public static func bytes(of response: Response) -> Data {
        let reason = response.status == 200 ? "OK" : response.status == 404 ? "Not Found" : "Bad Request"
        let head = "HTTP/1.1 \(response.status) \(reason)\r\nContent-Type: application/json\r\n"
            + "Content-Length: \(response.body.count)\r\nConnection: close\r\n\r\n"
        return Data(head.utf8) + response.body
    }

    private static func receive(on connection: NWConnection, buffer: Data,
                                handle: @escaping @Sendable (Request) async -> Response) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
            var buffer = buffer
            if let data { buffer.append(data) }
            if let request = request(from: buffer) {
                Task {
                    let response = await handle(request)
                    connection.send(content: bytes(of: response), completion: .contentProcessed { _ in connection.cancel() })
                }
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                receive(on: connection, buffer: buffer, handle: handle)
            }
        }
    }
}
#endif
