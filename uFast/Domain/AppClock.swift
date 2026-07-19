import Foundation

protocol AppClock: Sendable {
    var now: Date { get }
}

struct SystemAppClock: AppClock {
    var now: Date {
        Date()
    }
}
