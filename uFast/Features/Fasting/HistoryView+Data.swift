import Foundation

extension HistoryView {
    func reloadHistory(in window: DateInterval? = nil) {
        guard let requestedWindow = window
            ?? settledVisibleWindow?.interval
            ?? TemporalHistoryPresentation.calendarDayWindow(
                containing: selectedDate,
                calendar: calendar
            )?.interval
        else { return }
        let provider = SwiftDataHistoryDataProvider(modelContext: modelContext)
        do {
            let data = try provider.fetch(window: requestedWindow)
            historyData = data
            historyPresentation = presentationCache.presentation(
                for: data,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone,
                referenceNow: clock.now
            )
        } catch {
            clearHistoryPresentations()
            return
        }
        reloadMotionHistory(using: provider)
    }

    func rebuildHistoryPresentation() {
        guard let historyData else { return }
        presentationCache.invalidate()
        historyPresentation = presentationCache.presentation(
            for: historyData,
            locale: locale,
            calendar: calendar,
            timeZone: timeZone,
            referenceNow: clock.now
        )
        guard let motionHistoryData else { return }
        motionPresentationCache.invalidate()
        motionHistoryPresentation = motionPresentationCache.presentation(
            for: motionHistoryData,
            locale: locale,
            calendar: calendar,
            timeZone: timeZone,
            referenceNow: clock.now
        )
    }

    private func reloadMotionHistory(using provider: SwiftDataHistoryDataProvider) {
        guard let motionWindow = HistoryMotionWindow.interval(
            centeredOn: selectedDate,
            maximumDate: historyDisplayMaximumDay,
            calendar: calendar
        ) else {
            useSettledPresentationForMotion()
            return
        }
        do {
            let data = try provider.fetch(window: motionWindow)
            motionHistoryData = data
            motionHistoryPresentation = motionPresentationCache.presentation(
                for: data,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone,
                referenceNow: clock.now
            )
        } catch {
            useSettledPresentationForMotion()
        }
    }

    private func useSettledPresentationForMotion() {
        motionHistoryData = historyData
        motionHistoryPresentation = historyPresentation
    }

    private func clearHistoryPresentations() {
        historyData = nil
        historyPresentation = nil
        motionHistoryData = nil
        motionHistoryPresentation = nil
    }
}
