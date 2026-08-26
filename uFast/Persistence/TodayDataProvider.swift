import Foundation
import Observation
import SwiftData

// swiftlint:disable trailing_comma

/// The local calendar interval that owns the Today feature's event records.
/// Both endpoints are absolute instants; the upper endpoint is exclusive.
struct TodayCalendarInterval: Equatable {
    let start: Date
    let end: Date

    init(now: Date, calendar: Calendar) {
        let start = calendar.startOfDay(for: now)
        self.start = start
        end = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(24 * 60 * 60)
    }
}

enum TodayDataProviderFailure: Equatable {
    case snapshotUnavailable
}

/// Application-facing Today persistence seam. SwiftData records are converted
/// to immutable feature snapshots before they cross into the presentation tree.
@MainActor
@Observable
final class SwiftDataTodayDataProvider {
    private let modelContext: ModelContext
    private let clock: any AppClock
    private nonisolated(unsafe) var saveObserver: NSObjectProtocol?

    private(set) var calendar: Calendar
    private(set) var dayInterval: TodayCalendarInterval
    private(set) var failure: TodayDataProviderFailure?
    private(set) var snapshot = TodayFeatureSnapshot(
        settings: [],
        activeFasts: [],
        foodEntries: [],
        hydrationEntries: []
    )

    init(
        modelContext: ModelContext,
        clock: any AppClock,
        calendar: Calendar = .current
    ) {
        self.modelContext = modelContext
        self.clock = clock
        self.calendar = calendar
        dayInterval = TodayCalendarInterval(now: clock.now, calendar: calendar)
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: modelContext,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        refresh()
    }

    deinit {
        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
        }
    }

    /// Reload after a committed local persistence change or a lifecycle event.
    func refresh() {
        refresh(now: clock.now, calendar: calendar)
    }

    /// Reload using explicit temporal inputs. This keeps midnight, DST and
    /// time-zone behavior deterministic in unit tests.
    func refresh(now: Date, calendar: Calendar) {
        refresh(now: now, calendar: calendar) { interval in
            try loadSnapshot(for: interval)
        }
    }

    /// Test seam for exercising an atomic failed refresh without depending on
    /// a wall-clock or a corrupt shared store.
    func refresh(
        now: Date,
        calendar: Calendar,
        using loader: (TodayCalendarInterval) throws -> TodayFeatureSnapshot
    ) {
        let nextInterval = TodayCalendarInterval(now: now, calendar: calendar)
        do {
            let loadedSnapshot = try loader(nextInterval)
            self.calendar = calendar
            dayInterval = nextInterval
            snapshot = loadedSnapshot
            failure = nil
        } catch {
            // Adopt the requested temporal identity so a later parameterless
            // refresh uses the correct calendar day. Clear the timeline and
            // expose a semantic failure state, while preserving the last
            // known authoritative state for fast, settings and favourite controls.
            self.calendar = calendar
            dayInterval = nextInterval
            snapshot = TodayFeatureSnapshot(
                settings: snapshot.settings,
                activeFasts: snapshot.activeFasts,
                foodEntries: [],
                hydrationEntries: [],
                hydrationFavourites: snapshot.hydrationFavourites,
                foodFavourites: snapshot.foodFavourites
            )
            failure = .snapshotUnavailable
        }
    }

    func loadSnapshot(for interval: TodayCalendarInterval) throws -> TodayFeatureSnapshot {
        let lower = interval.start
        let upper = interval.end
        let settings = try settingsRecords().map(AppSettingsSnapshot.init)
        let activeFasts = try activeFastRecords().map(ActiveFastSnapshot.init)
        let foods = try modelContext.fetch(FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate {
                $0.occurredAt >= lower && $0.occurredAt < upper
            },
            sortBy: [
                SortDescriptor(\FoodEntryRecord.occurredAt, order: .reverse),
                SortDescriptor(\FoodEntryRecord.id),
            ]
        )).map(FoodEntrySnapshot.init)
        let drinks = try modelContext.fetch(FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate {
                $0.occurredAt >= lower && $0.occurredAt < upper
            },
            sortBy: [
                SortDescriptor(\HydrationEntryRecord.occurredAt, order: .reverse),
                SortDescriptor(\HydrationEntryRecord.id),
            ]
        )).map(HydrationEntrySnapshot.init)
        let favourites = try modelContext.fetch(FetchDescriptor<HydrationFavouriteRecord>(
            sortBy: [
                SortDescriptor(\HydrationFavouriteRecord.creationOrder),
                SortDescriptor(\HydrationFavouriteRecord.createdAt),
                SortDescriptor(\HydrationFavouriteRecord.id),
            ]
        )).map(\.snapshot)
        let foodFavourites = try modelContext.fetch(FetchDescriptor<FoodFavouriteRecord>(
            sortBy: [
                SortDescriptor(\FoodFavouriteRecord.creationOrder),
                SortDescriptor(\FoodFavouriteRecord.createdAt),
                SortDescriptor(\FoodFavouriteRecord.id),
            ]
        )).map(\.snapshot)

        return TodayFeatureSnapshot(
            settings: settings,
            activeFasts: activeFasts,
            foodEntries: foods,
            hydrationEntries: drinks,
            hydrationFavourites: favourites,
            foodFavourites: foodFavourites
        )
    }

    private func settingsRecords() throws -> [AppSettingsRecord] {
        var descriptor = FetchDescriptor<AppSettingsRecord>()
        descriptor.fetchLimit = 2
        return try modelContext.fetch(descriptor)
    }

    private func activeFastRecords() throws -> [FastRecord] {
        var descriptor = FetchDescriptor<FastRecord>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\FastRecord.startDate)]
        )
        descriptor.fetchLimit = 2
        return try modelContext.fetch(descriptor)
    }
}
