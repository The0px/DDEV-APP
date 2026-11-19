/// État d'un projet tel que rapporté par `ddev list`.
public enum DDEVProjectStatus: Hashable, Sendable {
    case running
    /// Conteneurs lancés mais pas encore sains.
    case starting
    case stopped
    case paused
    /// DDEV expose d'autres états (`unhealthy`, `project directory missing`…) qu'on conserve tels quels.
    case other(String)

    public init(rawValue: String) {
        switch rawValue {
        case "running": self = .running
        case "starting": self = .starting
        case "stopped": self = .stopped
        case "paused": self = .paused
        default: self = .other(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .running: "running"
        case .starting: "starting"
        case .stopped: "stopped"
        case .paused: "paused"
        case .other(let value): value
        }
    }

    /// Conteneurs démarrés : on peut les arrêter.
    public var isUp: Bool {
        self == .running || self == .starting
    }
}

extension DDEVProjectStatus: Codable {
    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
