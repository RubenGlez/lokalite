import Foundation
#if canImport(Darwin)
import Darwin
#endif

public enum VaultSocketError: Error, LocalizedError {
    case pathTooLong
    case notRunning
    case noResponse
    case systemError(String, Int32)

    public var errorDescription: String? {
        switch self {
        case .pathTooLong:
            return "The daemon socket path is too long (max 103 bytes)."
        case .notRunning:
            return "The Lokalite daemon is not running."
        case .noResponse:
            return "The Lokalite daemon closed the connection without responding."
        case .systemError(let call, let code):
            return "Socket \(call) failed (errno \(code))."
        }
    }
}

// MARK: - Server

/// Listens on a Unix domain socket and brokers `VaultRequest`s to a local
/// `VaultService` (ADR 0014). The menu-bar app runs one of these backed by the
/// real `Vault`; the CLI and MCP server connect as clients and never hold the key.
public final class VaultSocketServer {
    private let socketPath: String
    private let service: VaultService
    private let approveAgentAccess: AgentApprovalHandler
    // `listenFD` is written once in start() (before the accept loop is dispatched)
    // and only read afterwards, so it needs no lock. `running` is read by the
    // accept loop and written by stop() on another thread, so it is lock-guarded.
    private var listenFD: Int32 = -1
    private let runningLock = NSLock()
    private var _running = false
    private var running: Bool {
        get { runningLock.lock(); defer { runningLock.unlock() }; return _running }
        set { runningLock.lock(); defer { runningLock.unlock() }; _running = newValue }
    }
    private let acceptQueue = DispatchQueue(label: "com.lokalite.daemon.accept")
    private let connectionQueue = DispatchQueue(label: "com.lokalite.daemon.conn", attributes: .concurrent)
    /// Vault access is serialized — the underlying store is not assumed thread-safe.
    private let dispatchQueue = DispatchQueue(label: "com.lokalite.daemon.dispatch")

    public init(
        socketPath: String,
        service: VaultService,
        approveAgentAccess: @escaping AgentApprovalHandler = { _ in false }
    ) {
        self.socketPath = socketPath
        self.service = service
        self.approveAgentAccess = approveAgentAccess
    }

    public func start() throws {
        let directory = (socketPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        unlink(socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw VaultSocketError.systemError("socket", errno) }

        var addr = try makeUnixSockaddr(path: socketPath)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else { close(fd); throw VaultSocketError.systemError("bind", errno) }
        chmod(socketPath, 0o600)
        guard listen(fd, 16) == 0 else { close(fd); throw VaultSocketError.systemError("listen", errno) }

        listenFD = fd
        running = true
        acceptQueue.async { [weak self] in self?.acceptLoop() }
    }

    public func stop() {
        running = false
        if listenFD >= 0 { close(listenFD) } // closing breaks the blocked accept()
        unlink(socketPath)
    }

    private func acceptLoop() {
        while running {
            let clientFD = accept(listenFD, nil, nil)
            if clientFD < 0 {
                if running { continue } else { break }
            }
            connectionQueue.async { [weak self] in self?.serve(clientFD) }
        }
    }

    private func serve(_ fd: Int32) {
        defer { close(fd) }
        // The peer is fixed for the connection; resolve its identity once.
        let peerPID = SocketIO.peerPID(fd: fd)
        let caller = CallerContext(pid: peerPID, agent: peerPID.flatMap { AgentDetection.detectAgent(startingFrom: $0) })

        while let line = SocketIO.readLine(fd: fd) {
            let response: VaultResponse
            if let request = try? JSONDecoder().decode(VaultRequest.self, from: line) {
                response = dispatchQueue.sync { VaultRequestDispatcher.handle(request, using: service, caller: caller, approveAgentAccess: approveAgentAccess) }
            } else {
                response = .failure(message: "Malformed request.")
            }
            guard var out = try? JSONEncoder().encode(response) else { return }
            out.append(0x0A)
            if !SocketIO.writeAll(fd: fd, out) { return }
        }
    }
}

// MARK: - Client

/// Connects to the daemon for each request. Suitable as a `RemoteVaultService`
/// transport: `RemoteVaultService(transport: client.send)`.
public final class VaultSocketClient {
    private let socketPath: String

    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    public func send(_ request: VaultRequest) throws -> VaultResponse {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw VaultSocketError.systemError("socket", errno) }
        defer { close(fd) }

        var addr = try makeUnixSockaddr(path: socketPath)
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { throw VaultSocketError.notRunning }

        var data = try JSONEncoder().encode(request)
        data.append(0x0A)
        guard SocketIO.writeAll(fd: fd, data) else { throw VaultSocketError.systemError("write", errno) }

        guard let line = SocketIO.readLine(fd: fd) else { throw VaultSocketError.noResponse }
        return try JSONDecoder().decode(VaultResponse.self, from: line)
    }
}

// MARK: - Low-level helpers

private func makeUnixSockaddr(path: String) throws -> sockaddr_un {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let capacity = MemoryLayout.size(ofValue: addr.sun_path)
    guard path.utf8.count < capacity else { throw VaultSocketError.pathTooLong }
    _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { dst in
        path.withCString { strncpy(dst, $0, capacity - 1) }
    }
    return addr
}

enum SocketIO {
    /// Reads one newline-delimited frame (without the newline). Returns nil at EOF
    /// with no data.
    static func readLine(fd: Int32) -> Data? {
        var data = Data()
        var byte: UInt8 = 0
        while true {
            let n = read(fd, &byte, 1)
            if n <= 0 { return data.isEmpty ? nil : data }
            if byte == 0x0A { return data }
            data.append(byte)
        }
    }

    /// The PID of the connected peer, from the kernel (`LOCAL_PEERPID`) — not
    /// anything the peer can forge.
    static func peerPID(fd: Int32) -> pid_t? {
        var pid: pid_t = 0
        var length = socklen_t(MemoryLayout<pid_t>.size)
        let result = getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &pid, &length)
        return result == 0 ? pid : nil
    }

    static func writeAll(fd: Int32, _ data: Data) -> Bool {
        data.withUnsafeBytes { raw -> Bool in
            guard var pointer = raw.baseAddress else { return true }
            var remaining = raw.count
            while remaining > 0 {
                let n = write(fd, pointer, remaining)
                if n <= 0 { return false }
                pointer = pointer.advanced(by: n)
                remaining -= n
            }
            return true
        }
    }
}
