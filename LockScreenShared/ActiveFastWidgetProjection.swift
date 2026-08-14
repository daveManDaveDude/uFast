import Foundation

struct ActiveFastWidgetProjection: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let supportedGoalHours = 8 ... 24

    let schemaVersion: Int
    let activeRecordIdentifier: UUID
    let startDate: Date
    let targetDate: Date
    let goalHours: Int
    let generatedAt: Date

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        activeRecordIdentifier: UUID,
        startDate: Date,
        targetDate: Date,
        goalHours: Int,
        generatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.activeRecordIdentifier = activeRecordIdentifier
        self.startDate = startDate
        self.targetDate = targetDate
        self.goalHours = goalHours
        self.generatedAt = generatedAt
    }

    func validate(now: Date) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ActiveFastWidgetProjectionError.incompatibleSchema
        }
        guard Self.supportedGoalHours.contains(goalHours) else {
            throw ActiveFastWidgetProjectionError.invalidGoal
        }
        guard targetDate > startDate else {
            throw ActiveFastWidgetProjectionError.invalidTarget
        }

        let expectedTarget = startDate.addingTimeInterval(TimeInterval(goalHours * 60 * 60))
        guard abs(targetDate.timeIntervalSince(expectedTarget)) < 0.001 else {
            throw ActiveFastWidgetProjectionError.inconsistentTarget
        }
        guard startDate <= now else {
            throw ActiveFastWidgetProjectionError.futureStart
        }
    }
}

enum ActiveFastWidgetProjectionError: Error, Equatable {
    case incompatibleSchema
    case invalidGoal
    case invalidTarget
    case inconsistentTarget
    case futureStart
    case unreadable
}
