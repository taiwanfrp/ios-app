import Foundation

struct UserMeResponse: Codable {
    let id: String?
    let username: String?
    let status: String?
    let avatar: String?
    let discordId: String?
    let mfaEnabled: Bool?
    let locale: String?
    let email: String?
    let verified: Bool?
    let permissions: [String]
    let roles: [String]

    enum CodingKeys: String, CodingKey {
        case id = "internal_user_id"
        case username
        case status = "internal_account_status"
        case avatar
        case discordId = "discord_id"
        case mfaEnabled = "mfa_enabled"
        case locale, email, verified, permissions, roles
    }
}

struct NodeResponse: Codable, Identifiable {
    let id: Int?
    var name: String?
    var description: String?
    var host: String?
    var portStart: Int?
    var portEnd: Int?
    var status: String?
    var isPublic: Bool?
    let ownerId: String?
    var isOnline: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, description, host, status
        case portStart = "port_start"
        case portEnd = "port_end"
        case isPublic = "is_public"
        case ownerId = "owner_id"
        case isOnline = "is_online"
    }
}

struct TunnelResponse: Codable, Identifiable {
    let id: String?
    var name: String?
    var description: String?
    var nodeId: Int?
    var protocolName: String?
    var localIP: String?
    var localPort: Int?
    var remotePort: Int?
    var isKCPEnabled: Bool?
    var isProxyProtocolV2Enabled: Bool?
    var isEnabled: Bool?
    var status: String?
    let createdAt: String?
    let updatedAt: String?
    let ownerId: String?
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case ownerId = "owner_id"
        case userId = "user_id"
        case nodeId = "node_id"
        case protocolName = "protocol"
        case localIP = "local_ip"
        case localPort = "local_port"
        case remotePort = "remote_port"
        case isKCPEnabled = "is_kcp_enabled"
        case isProxyProtocolV2Enabled = "is_proxy_protocol_v2_enabled"
        case isEnabled = "is_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SystemStatusResponse: Codable {
    let api: String?
    let version: String?
    let database: String?
    let redis: String?
}

struct CreateNodeRequest: Codable {
    let name: String
    let description: String
    let host: String
    let portStart: Int
    let portEnd: Int
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case name, description, host
        case portStart = "port_start"
        case portEnd = "port_end"
        case isPublic = "is_public"
    }
}

struct CreateTunnelRequest: Codable {
    let name: String
    let description: String
    let nodeId: Int
    let protocolName: String
    let localIP: String
    let localPort: Int
    let remotePort: Int?
    let isKCPEnabled: Bool
    let isProxyProtocolV2Enabled: Bool

    enum CodingKeys: String, CodingKey {
        case name, description
        case nodeId = "node_id"
        case protocolName = "protocol"
        case localIP = "local_ip"
        case localPort = "local_port"
        case remotePort = "remote_port"
        case isKCPEnabled = "is_kcp_enabled"
        case isProxyProtocolV2Enabled = "is_proxy_protocol_v2_enabled"
    }
}

struct NodeUpdateRequest: Codable {
    let status: String?
    let isPublic: Bool?
    let name: String?
    let description: String?
    let host: String?
    let portStart: Int?
    let portEnd: Int?

    enum CodingKeys: String, CodingKey {
        case status, name, description, host
        case isPublic = "is_public"
        case portStart = "port_start"
        case portEnd = "port_end"
    }
}

struct TunnelUpdateRequest: Codable {
    let name: String?
    let description: String?
    let nodeId: Int?
    let protocolName: String?
    let localIP: String?
    let localPort: Int?
    let remotePort: Int?
    let isKCPEnabled: Bool?
    let isProxyProtocolV2Enabled: Bool?
    let isEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case name, description
        case nodeId = "node_id"
        case protocolName = "protocol"
        case localIP = "local_ip"
        case localPort = "local_port"
        case remotePort = "remote_port"
        case isKCPEnabled = "is_kcp_enabled"
        case isProxyProtocolV2Enabled = "is_proxy_protocol_v2_enabled"
        case isEnabled = "is_enabled"
    }
}
