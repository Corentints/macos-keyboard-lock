import Foundation

/// Owns the keyboard lock and its optional countdown. UI-agnostic: observers use the callbacks.
final class LockSession {
    private let blocker = KeyboardBlocker()
    private var countdownTimer: Timer?

    /// Seconds left before the automatic unlock; `nil` when unlocked or unlimited.
    private(set) var remainingSeconds: Int?

    var isLocked: Bool { blocker.isActive }

    /// Called after the lock state flipped, whether the user or the countdown caused it.
    var onLockChange: ((Bool) -> Void)?
    var onTick: ((Int) -> Void)?

    func lock(for duration: LockDuration) throws {
        guard KeyboardBlocker.isAccessibilityGranted(prompting: true) else { throw LockError.accessibilityDenied }
        try blocker.start()

        remainingSeconds = duration.seconds
        if duration.seconds != nil { startCountdown() }
        onLockChange?(true)
    }

    func unlock() {
        guard isLocked else { return }
        countdownTimer?.invalidate()
        countdownTimer = nil
        remainingSeconds = nil
        blocker.stop()
        onLockChange?(false)
    }

    /// Releases the keyboard without notifying observers (app is quitting).
    func shutdown() {
        blocker.stop()
    }

    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let remaining = remainingSeconds else { return }
        let next = remaining - 1
        guard next > 0 else { return unlock() }
        remainingSeconds = next
        onTick?(next)
    }
}
