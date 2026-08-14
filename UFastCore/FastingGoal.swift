public struct FastingGoal: Equatable, Hashable, Identifiable, Sendable {
    public static let minimumHours = 8
    public static let maximumHours = 24
    public static let `default` = FastingGoal(validatedHours: 12)
    public static let choices = (minimumHours ... maximumHours).map(FastingGoal.init(validatedHours:))

    public let hours: Int
    public var id: Int {
        hours
    }

    public init?(hours: Int) {
        guard Self.minimumHours ... Self.maximumHours ~= hours else { return nil }
        self.hours = hours
    }

    private init(validatedHours: Int) {
        hours = validatedHours
    }
}
