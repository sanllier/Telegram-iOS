import CoreGraphics
import QuartzCore

final class PointVelocityCalculator {

    // MARK: - Public Properties

    var lastVelocity: CGFloat = 0.0 { didSet {
        guard abs(oldValue - lastVelocity) > 0.00001 else { return }
        onSpeedUpdated(lastVelocity)
    }}

    // MARK: - Constructors

    init(
        pointProvider: @escaping () -> CGPoint,
        onSpeedUpdated: @escaping (CGFloat) -> Void
    ) {
        self.lastPoint = pointProvider()
        self.lastTimestamp = CACurrentMediaTime()
        self.pointProvider = pointProvider
        self.onSpeedUpdated = onSpeedUpdated
    }

    // MARK: - Public Methods

    @objc func onTick() {
        let currentTimestamp = CACurrentMediaTime()
        let elapsedTime = currentTimestamp - lastTimestamp
        let currentPoint = pointProvider()
        let distance = hypot(currentPoint.x - lastPoint.x, currentPoint.y - lastPoint.y)
        let direction = currentPoint.x >= lastPoint.x ? 1.0 : -1.0
        lastTimestamp = currentTimestamp
        lastPoint = currentPoint
        guard elapsedTime > 0.0 else { return }
        let velocity = direction * (distance / CGFloat(elapsedTime))
        lastVelocity = velocity
    }

    // MARK: - Private Nested

    private var lastPoint: CGPoint
    private var lastTimestamp: CFTimeInterval
    private let pointProvider: () -> CGPoint
    private let onSpeedUpdated: (CGFloat) -> Void

}
