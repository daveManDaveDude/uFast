import SwiftData

struct PersistenceBootstrapFailure: Equatable, Sendable {
    let diagnosticDescription: String
}

enum PersistenceBootstrapResult {
    case ready(ModelContainer)
    case unavailable(PersistenceBootstrapFailure)

    static func open(
        containerFactory: () throws -> ModelContainer = { try PersistenceContainer.make() }
    ) -> Self {
        do {
            return try .ready(containerFactory())
        } catch {
            return .unavailable(
                PersistenceBootstrapFailure(
                    diagnosticDescription: String(describing: error)
                )
            )
        }
    }
}
