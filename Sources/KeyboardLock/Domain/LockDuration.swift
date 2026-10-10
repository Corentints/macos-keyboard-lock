enum LockDuration: CaseIterable {
    case thirtySeconds
    case oneMinute
    case fiveMinutes
    case tenMinutes
    case unlimited

    static let `default` = LockDuration.oneMinute

    var title: String {
        switch self {
        case .thirtySeconds: "30 s"
        case .oneMinute: "1 min"
        case .fiveMinutes: "5 min"
        case .tenMinutes: "10 min"
        case .unlimited: "∞"
        }
    }

    /// `nil` means the keyboard stays locked until the user unlocks it.
    var seconds: Int? {
        switch self {
        case .thirtySeconds: 30
        case .oneMinute: 60
        case .fiveMinutes: 300
        case .tenMinutes: 600
        case .unlimited: nil
        }
    }
}
