import Combine
import CoreMotion
import Foundation

enum TiltDirection {
    case left
    case right
}

@MainActor
final class TiltDecisionController: ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isActive = false
    @Published private(set) var lastDirection: TiltDirection?

    private let motionManager = CMMotionManager()
    private var onTilt: ((TiltDirection) -> Void)?
    private var canTrigger = true
    private var lastTriggerDate = Date.distantPast

    private let triggerThreshold = 0.24
    private let neutralThreshold = 0.10
    private let cooldown: TimeInterval = 0.55

    func start(onTilt: @escaping (TiltDirection) -> Void) {
        self.onTilt = onTilt
        isAvailable = motionManager.isDeviceMotionAvailable

        guard isAvailable else {
            isActive = false
            return
        }

        guard !isActive else { return }

        canTrigger = true
        lastDirection = nil
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            self?.handleTilt(gravityX: motion.gravity.x)
        }
        isActive = true
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        onTilt = nil
        canTrigger = true
        lastDirection = nil
        isActive = false
    }

    private func handleTilt(gravityX: Double) {
        if abs(gravityX) <= neutralThreshold {
            canTrigger = true
            lastDirection = nil
            return
        }

        guard canTrigger else { return }
        guard Date().timeIntervalSince(lastTriggerDate) >= cooldown else { return }

        if gravityX <= -triggerThreshold {
            trigger(.left)
        } else if gravityX >= triggerThreshold {
            trigger(.right)
        }
    }

    private func trigger(_ direction: TiltDirection) {
        canTrigger = false
        lastTriggerDate = Date()
        lastDirection = direction
        onTilt?(direction)
    }
}
