import Foundation

struct FastingGoal: Equatable, Hashable, Identifiable, Sendable {
    static let minimumHours = 8
    static let maximumHours = 24
    static let `default` = FastingGoal(validatedHours: 12)
    static let choices = (minimumHours ... maximumHours).map(FastingGoal.init(validatedHours:))

    let hours: Int

    var id: Int {
        hours
    }

    init?(hours: Int) {
        guard Self.minimumHours ... Self.maximumHours ~= hours else {
            return nil
        }

        self.hours = hours
    }

    private init(validatedHours: Int) {
        hours = validatedHours
    }
}
