// ZurufAPI.swift
// Shared
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

enum APIError: LocalizedError {
    case insecureServer
    case status(Int, String?)

    var errorDescription: String? {
        switch self {
        case .insecureServer:
            "The server address must use https."
        case .status(_, let code?) where code == "invalid_invite":
            "That invite code is not valid or has already been used."
        case .status(let status, let code):
            "The server answered \(status)\(code.map { " (\($0))" } ?? "")."
        }
    }

    // A request the server refused outright; sending it again will not help.
    var isPermanent: Bool {
        if case .status(let status, _) = self {
            return (400..<500).contains(status) && status != 408 && status != 429
        }
        return false
    }
}

struct ZurufAPI {
    let account: Account

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    // Accepts a bare host name and refuses anything but https.
    static func serverURL(from text: String) throws -> URL {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") {
            text = "https://" + text
        }
        guard let url = URL(string: text), url.scheme == "https", url.host() != nil else {
            throw APIError.insecureServer
        }
        return url
    }

    private struct Credentials: Decodable {
        let userId: String
        let token: String
        let serverId: String
    }

    static func redeem(server: URL, code: String, displayName: String) async throws -> Account {
        var request = URLRequest(url: server.appending(path: "v1/invites/redeem"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["code": code, "display_name": displayName])
        let credentials: Credentials = try await send(request)
        return Account(
            serverURL: server,
            serverID: credentials.serverId,
            userID: credentials.userId,
            displayName: displayName,
            token: credentials.token
        )
    }

    // A new device under this account, for the paired watch or phone.
    func linkDevice() async throws -> Account {
        let credentials: Credentials = try await Self.send(request("v1/devices/link", method: "POST"))
        return Account(
            serverURL: account.serverURL,
            serverID: credentials.serverId,
            userID: credentials.userId,
            displayName: account.displayName,
            token: credentials.token
        )
    }

    func registerDevice(apnsToken: String, environment: String, platform: String) async throws {
        var request = request("v1/devices", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["apns_token": apnsToken, "apns_env": environment, "platform": platform])
        _ = try await Self.data(for: request)
    }

    func deleteAccount() async throws {
        _ = try await Self.data(for: request("v1/account", method: "DELETE"))
    }

    func contacts() async throws -> Contacts {
        try await Self.send(request("v1/contacts"))
    }

    func clips() async throws -> ClipList {
        try await Self.send(request("v1/clips"))
    }

    func audio(clipID: String) async throws -> Data {
        try await Self.data(for: request("v1/clips/\(clipID)/audio"))
    }

    func markPlayed(clipID: String) async throws {
        _ = try await Self.data(for: request("v1/clips/\(clipID)/played", method: "POST"))
    }

    func deleteClip(clipID: String) async throws {
        _ = try await Self.data(for: request("v1/clips/\(clipID)", method: "DELETE"))
    }

    func uploadClip(file: URL, to recipient: Recipient) async throws {
        let boundary = "zuruf-\(UUID().uuidString)"
        var request = request("v1/clips", method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let field: (String, String) = switch recipient {
        case .person(let id, _): ("to_user", id)
        case .group(let id, _): ("to_group", id)
        }
        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(field.0)\"\r\n\r\n\(field.1)\r\n")
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"clip.m4a\"\r\n")
        body.append("Content-Type: audio/mp4\r\n\r\n")
        body.append(try Data(contentsOf: file))
        body.append("\r\n--\(boundary)--\r\n")

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        try Self.check(data, response)
    }

    private func request(_ path: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: account.serverURL.appending(path: path))
        request.httpMethod = method
        request.setValue("Bearer \(account.token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        try decoder.decode(T.self, from: try await data(for: request))
    }

    private static func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(data, response)
        return data
    }

    private static func check(_ data: Data, _ response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let code = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw APIError.status(status, code)
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
