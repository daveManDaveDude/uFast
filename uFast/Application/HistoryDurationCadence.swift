import Foundation
import Observation

@MainActor
protocol HistoryDurationCadenceDriver: AnyObject {
    func start(_ pulse: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
protocol HistoryDurationDeadlineDriver: AnyObject {
    func schedule(at deadline: Date, _ fire: @escaping @MainActor () -> Void)
    func cancel()
    func advance(to now: Date)
}

@MainActor
final class SystemHistoryDurationCadence: HistoryDurationCadenceDriver {
    private var task: Task<Void, Never>?

    func start(_ pulse: @escaping @MainActor () -> Void) {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                await MainActor.run { pulse() }
            }
            self?.task = nil
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}

@MainActor
final class SystemHistoryDurationDeadline: HistoryDurationDeadlineDriver {
    private var task: Task<Void, Never>?

    func schedule(at deadline: Date, _ fire: @escaping @MainActor () -> Void) {
        cancel()
        let seconds = max(deadline.timeIntervalSinceNow, 0)
        guard seconds.isFinite else { return }
        task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                fire()
                self?.task = nil
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    func advance(to _: Date) {}

    deinit {
        task?.cancel()
    }
}

@MainActor
final class ManualHistoryDurationDeadline: HistoryDurationDeadlineDriver {
    private var deadline: Date?
    private var fire: (@MainActor () -> Void)?

    func schedule(at deadline: Date, _ fire: @escaping @MainActor () -> Void) {
        self.deadline = deadline
        self.fire = fire
    }

    func cancel() {
        deadline = nil
        fire = nil
    }

    func advance(to now: Date) {
        guard let deadline, now >= deadline else { return }
        let fire = fire
        cancel()
        fire?()
    }
}

@MainActor
final class ManualHistoryDurationCadence: HistoryDurationCadenceDriver {
    private var pulse: (@MainActor () -> Void)?

    func start(_ pulse: @escaping @MainActor () -> Void) {
        self.pulse = pulse
    }

    func stop() {
        pulse = nil
    }

    func emitPulse() {
        pulse?()
    }
}

/// One History-owned cadence. A delayed callback samples the clock once and
/// publishes that instant directly; it never replays missed seconds.
@MainActor
@Observable
final class HistoryDurationPulse {
    @ObservationIgnored let clock: any AppClock
    @ObservationIgnored let driver: any HistoryDurationCadenceDriver
    @ObservationIgnored let deadlineDriver: any HistoryDurationDeadlineDriver
    @ObservationIgnored private(set) var isRunning = false

    private(set) var now: Date
    private(set) var pulseCount = 0
    private(set) var capDeadlineGeneration = 0
    private var capDeadline: Date?
    private var capDeadlineIdentity = 0
    private var capDeadlineHasFired = false
    private var capDeadlineScheduled = false
    private var testScriptSteps = 0
    private var testScriptTask: Task<Void, Never>?

    init(
        clock: any AppClock,
        driver: any HistoryDurationCadenceDriver,
        deadlineDriver: (any HistoryDurationDeadlineDriver)? = nil
    ) {
        self.clock = clock
        self.driver = driver
        self.deadlineDriver = deadlineDriver
            ?? (clock is MutableAppClock
                ? ManualHistoryDurationDeadline()
                : SystemHistoryDurationDeadline())
        now = clock.now
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        now = clock.now
        driver.start { [weak self] in
            self?.deliverPulse()
        }
    }

    func stop() {
        if isRunning {
            driver.stop()
        }
        isRunning = false
        deadlineDriver.cancel()
        capDeadlineScheduled = false
        testScriptTask?.cancel()
        testScriptTask = nil
        testScriptSteps = 0
    }

    func deliverPulse() {
        guard isRunning else { return }
        let nextNow = clock.now
        guard nextNow != now else { return }
        now = nextNow
        pulseCount += 1
    }

    func advanceTestClock(by interval: TimeInterval = 1) {
        guard let clock = clock as? MutableAppClock else { return }
        clock.advance(by: interval)
        if isRunning {
            deliverPulse()
        }
        deadlineDriver.advance(to: clock.now)
    }

    /// Arms an exact, test-only sequence. The sequence is started by the
    /// History movement callback but each pulse remains generated by this
    /// cadence owner, never by scroll geometry or a motion phase.
    func armTestClockScript(steps: Int) {
        guard isRunning, clock is MutableAppClock, steps > 0 else { return }
        testScriptTask?.cancel()
        testScriptTask = nil
        testScriptSteps = steps
    }

    func beginArmedTestClockScript() {
        guard testScriptSteps > 0, testScriptTask == nil else { return }
        let steps = testScriptSteps
        testScriptSteps = 0
        testScriptTask = Task { [weak self] in
            for _ in 0 ..< steps {
                guard !Task.isCancelled else { return }
                await Task.yield()
                guard !Task.isCancelled, let self, isRunning,
                      let clock = clock as? MutableAppClock
                else { return }
                clock.advance(by: 1)
                deliverPulse()
                deadlineDriver.advance(to: clock.now)
                // Let the observation transaction settle before the next
                // scripted instant so the duration leaf sees every test tick.
                await Task.yield()
            }
            self?.testScriptTask = nil
        }
    }

    func armCapDeadline(at deadline: Date?) {
        guard isRunning else { return }
        if capDeadline != deadline {
            deadlineDriver.cancel()
            capDeadline = deadline
            capDeadlineIdentity += 1
            capDeadlineHasFired = false
            capDeadlineScheduled = false
        }

        guard let deadline, !capDeadlineHasFired, !capDeadlineScheduled else { return }
        let identity = capDeadlineIdentity
        deadlineDriver.cancel()
        if deadline <= now {
            fireCapDeadline(identity: identity)
        } else {
            capDeadlineScheduled = true
            deadlineDriver.schedule(at: deadline) { [weak self] in
                self?.fireCapDeadline(identity: identity)
            }
        }
    }

    private func fireCapDeadline(identity: Int) {
        guard isRunning,
              identity == capDeadlineIdentity,
              !capDeadlineHasFired
        else { return }
        deadlineDriver.cancel()
        capDeadlineScheduled = false
        capDeadlineHasFired = true
        now = clock.now
        capDeadlineGeneration += 1
    }
}
