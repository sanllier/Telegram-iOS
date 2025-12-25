import UIKit
import LegacyComponents

public final class LGSlider: UIControl {

    // MARK: - Public Nested

    public struct TrackConfiguration: Equatable {
        public var numberOfTicks: Int

        public init(numberOfTicks: Int) {
            self.numberOfTicks = numberOfTicks
        }
    }

    // MARK: - Public Properties

    public override var intrinsicContentSize: CGSize { .init(width: UIView.noIntrinsicMetric, height: 34.0) }

    public var minimumValue: CGFloat = 0.0 { didSet {
        if minimumValue > _value { _value = minimumValue }
        setNeedsLayout()
    }}
    public var maximumValue: CGFloat = 1.0 { didSet {
        if maximumValue < _value { _value = maximumValue }
        setNeedsLayout()
    }}
    public var trackConfiguration: TrackConfiguration? { didSet {
        guard oldValue != trackConfiguration else { return }
        repaint()
        updateLayout()
    }}
    public var minimumTrackTintColor: UIColor? { didSet { repaint() } }
    public var maximumTrackTintColor: UIColor? { didSet { repaint() } }
    public var value: CGFloat {
        get { _value }
        set { setValue(newValue, animated: false) }
    }

    // MARK: - Constructors

    public override init(frame: CGRect) {
        super.init(frame: frame)
        [maximumTrackLayer, minimumTrackLayer].forEach {
            $0.anchorPoint = .init(x: 0.0, y: 0.5)
            $0.allowsEdgeAntialiasing = true
            layer.addSublayer($0)
        }
        ticksContainerLayer.contentsScale = UIScreen.main.scale
        ticksContainerLayer.addSublayer(tickDotLayer)
        ticksContainerLayer.allowsEdgeAntialiasing = true
        layer.addSublayer(ticksContainerLayer)
        thumbView.moveOnWindowWhileSelected = true
        thumbView.bounds.size = .init(width: Static.thumbWidth, height: Static.thumbHeight)
        thumbView.shouldAnimateSpeed = true
        addSubview(thumbView)
        addGestureRecognizer(longPressRecognizer)
        repaint()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        repaint()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard acceptedBoundsSize != bounds.size else { return }
        acceptedBoundsSize = bounds.size
        updateLayout()
        if let anim = pop_animation(forKey: Static.desiredThumbXCenterAnimatablePropName) as? POPSpringAnimation {
            anim.toValue = desiredThumbXCenter(forValue: _value)
        } else if let _ = pop_animation(forKey: Static.desiredThumbXCenterAnimatablePropName) as? POPDecayAnimation {
            pop_removeAnimation(forKey: Static.desiredThumbXCenterAnimation)
            startThumbSpringAnimation(to: desiredThumbXCenter(forValue: _value), shouldUpdateValue: false)
        } else if trackingTouchContext == nil {
            desiredThumbXCenter = desiredThumbXCenter(forValue: _value)
        }
    }

    public func setValue(_ value: CGFloat, animated: Bool) {
        _value = snappedValueIfNeeded(forValue: value, mode: .nearest)
        if trackingTouchContext == nil {
            if let anim = pop_animation(forKey: Static.desiredThumbXCenterAnimation) as? POPSpringAnimation {
                anim.toValue = desiredThumbXCenter(forValue: _value)
            } else {
                pop_removeAnimation(forKey: Static.desiredThumbXCenterAnimation)
                if animated {
                    startThumbSpringAnimation(to: desiredThumbXCenter(forValue: _value), shouldUpdateValue: false)
                } else {
                    desiredThumbXCenter = desiredThumbXCenter(forValue: _value)
                }
            }
        }
    }

    // MARK: - Private Properties

    private var _value: CGFloat = 0.0

    private var acceptedBoundsSize: CGSize?

    private let minimumTrackLayer = CALayer()
    private let maximumTrackLayer = CALayer()
    private let thumbView = LGControlThumbView(
        baseLensProperties: .clear().updating {
            $0.effectsProperties?.mainShadowRequired = true
            $0.effectsProperties?.mirroringZoneWidth = 5.0
            $0.effectsProperties?.visibleMirrorWidth = 2.0
            $0.effectsProperties?.mirrorBlurTransitionWidth = 1.5
            $0.effectsProperties?.mirrorBlurRadius = 4.0
        },
        magnification: (deselected: 1.1, selected: 1.0),
        selectionScale: Static.thumbSelectionScale,
        valocityScaleRangeWidth: 0.3,
        deselectedShadowRequired: true,
        deselectionMode: .tinting
    )
    private lazy var tickDotLayer: CALayer = {
        let obj = CALayer()
        obj.anchorPoint = .init(x: 0.5, y: 0.0)
        obj.position = .zero
        obj.bounds.size = .init(width: Static.tickDotDimSize, height: Static.tickDotDimSize)
        obj.cornerRadius = Static.tickDotDimSize / 2.0
        obj.contentsScale = UIScreen.main.scale
        obj.allowsEdgeAntialiasing = true
        return obj
    }()
    private var ticksContainerLayer = CAReplicatorLayer()
    
    private lazy var longPressRecognizer = LGGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
    private var trackingTouchContext: TouchContext? { didSet {
        if (oldValue == nil) != (trackingTouchContext == nil) {
            if trackingTouchContext != nil {
                pop_removeAnimation(forKey: Static.desiredThumbXCenterAnimatablePropName)
            }
            thumbView.setSelected(trackingTouchContext != nil)
        }
        if (oldValue != nil) && (trackingTouchContext == nil) {
            animateGestureFinalization()
        }
    }}
    
    private var desiredThumbXCenter: CGFloat = Static.thumbWidth / 2.0 { didSet {
        guard abs(oldValue - desiredThumbXCenter) > 0.01 else { return }
        updateLayout()
    }}
    private lazy var desiredThumbXCenterAnimatable = POPAnimatableProperty.property(
        withName: Static.desiredThumbXCenterAnimatablePropName,
        initializer: { prop in
            guard let prop else { return }
            prop.readBlock = { obj, values in
                guard let slf = obj as? LGSlider else { assert(false); return }
                guard let values else { return }
                values[0] = slf.desiredThumbXCenter
            }
            prop.writeBlock = { obj, values in
                guard let slf = obj as? LGSlider else { assert(false); return }
                guard let values else { return }
                if slf.desiredThumbXCenter < slf.lEdge || slf.desiredThumbXCenter > slf.rEdge {
                    slf.desiredThumbXCenter = values[0]
                } else {
                    slf.desiredThumbXCenter = min(slf.rEdge, max(slf.lEdge, values[0]))
                }
            }
            prop.threshold = 0.1
        }
    ) as? POPAnimatableProperty
    
    private var lEdge: CGFloat { min(bounds.width, Static.thumbWidth) / 2.0 }
    private var rEdge: CGFloat { bounds.width - (min(bounds.width, Static.thumbWidth) / 2.0) }

}

extension LGSlider: POPAnimationDelegate {

    public func pop_animationDidApply(_ anim: POPAnimation!) {
        let oldValue = _value
        _value = snappedValueIfNeeded(forDesiredThumbXCenter: desiredThumbXCenter, mode: .nearest)
        notifyValueChangeIfNeeded(oldValue: oldValue, newValue: _value)
    }

}

fileprivate extension LGSlider {

    // MARK: - Private Nested

    enum Static {
        static let trackHeight = 6.0
        static let thumbWidth = 37.0
        static let thumbHeight = 24.0
        static let tickDotDimSize = 3.0
        static let thumbSelectionScale = CGSize(width: 1.6, height: 1.6)
        static let trackSpeedUpZone = ((thumbWidth * thumbSelectionScale.width) - thumbWidth) / 2.0
        
        static let desiredThumbXCenterAnimatablePropName = "desired-thumb-x-center"
        static let desiredThumbXCenterAnimation = "desired-thumb-x-center"
    }

    struct TouchContext {
        var initialTouchLocation: CGPoint
        var initialThumbXCenter: CGFloat
    }

    enum SnappingMode {
        case nearest
        case previous
        case next
    }

    // MARK: - Private Methods

    @objc func onLongPress(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            let touchLocation = sender.location(in: self)
            guard thumbView.bounds.contains(convert(touchLocation, to: thumbView)) else { return }
            pop_removeAnimation(forKey: Static.desiredThumbXCenterAnimation)
            trackingTouchContext = .init(
                initialTouchLocation: touchLocation,
                initialThumbXCenter: thumbView.center.x
            )
        case .changed:
            guard let trackingTouchContext else { return }
            let currentTouchLocation = longPressRecognizer.location(in: self)
            let touchXTranslation = currentTouchLocation.x - trackingTouchContext.initialTouchLocation.x
            let desiredThumbXCenter = trackingTouchContext.initialThumbXCenter + touchXTranslation
            let oldValue = _value
            _value = snappedValueIfNeeded(forDesiredThumbXCenter: desiredThumbXCenter, mode: .nearest)
            notifyValueChangeIfNeeded(oldValue: oldValue, newValue: _value)
            self.desiredThumbXCenter = desiredThumbXCenter
        case .ended, .cancelled, .failed:
            trackingTouchContext = nil
        default:
            break
        }
    }

    func notifyValueChangeIfNeeded(oldValue: CGFloat, newValue: CGFloat) {
        guard abs(oldValue - newValue) > 0.000001 else { return }
        if trackConfiguration?.numberOfTicks ?? 0 <= 1 {
            if oldValue < maximumValue && newValue >= maximumValue ||
               oldValue > minimumValue && newValue <= minimumValue
            {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            if abs(oldValue - newValue) > 0.00001 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        sendActions(for: .valueChanged)
    }
    
    func desiredThumbXCenter(forValue value: CGFloat) -> CGFloat {
        let progress = (value - minimumValue) / (maximumValue - minimumValue)
        return lEdge + (rEdge - lEdge) * progress
    }

    func value(forDesiredThumbXCenter desiredThumbXCenter: CGFloat) -> CGFloat {
        let progress = min(1.0, max(0.0, (desiredThumbXCenter - lEdge) / (rEdge - lEdge)))
        return minimumValue + (maximumValue - minimumValue) * progress
    }

    func snappedValueIfNeeded(forValue value: CGFloat, mode: SnappingMode) -> CGFloat {
        guard let numberOfTicks = trackConfiguration?.numberOfTicks, numberOfTicks > 0 else { return value }
        guard numberOfTicks > 1 else { return (maximumValue - minimumValue) / 2.0 }
        let segmentSize = (maximumValue - minimumValue) / CGFloat(numberOfTicks - 1)
        let relativePosition = value - minimumValue
        let exactIndex = relativePosition / segmentSize
        let targetIndex: CGFloat
        switch mode {
        case .nearest: targetIndex = round(exactIndex)
        case .previous: targetIndex = floor(exactIndex)
        case .next: targetIndex = ceil(exactIndex)
        }
        let clampedIndex = max(0.0, min(CGFloat(numberOfTicks - 1), targetIndex))
        return minimumValue + clampedIndex * segmentSize
    }
    
    func snappedValueIfNeeded(
        forDesiredThumbXCenter desiredThumbXCenter: CGFloat,
        mode: SnappingMode
    ) -> CGFloat {
        snappedValueIfNeeded(
            forValue: value(forDesiredThumbXCenter: desiredThumbXCenter),
            mode: mode
        )
    }

    func repaint() {
        minimumTrackLayer.backgroundColor = (minimumTrackTintColor ?? .systemBlue).cgColor
        maximumTrackLayer.backgroundColor = {
            switch traitCollection.userInterfaceStyle {
            case .dark: UIColor.white.withAlphaComponent(0.1).cgColor
            default: UIColor.black.withAlphaComponent(0.1).cgColor
            }
        }()
        tickDotLayer.backgroundColor = UIColor.opaqueSeparator.cgColor
    }

    func updateLayout() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        thumbView.center.y = bounds.height / 2.0
        let limit = (2.0 * Static.thumbWidth) / 3.0
        thumbView.center.x = desiredThumbXCenter.rubberBanded(in: (lEdge...rEdge), limit: limit, stiffness: 0.3)
        let undershoot = min(0.0, thumbView.center.x - (Static.thumbWidth / 2.0))
        let overshoot = max(0.0, thumbView.center.x - rEdge)
        let tracksScale = 1.0 - (min(1.0, (max(-undershoot, overshoot) / limit)))
        let trackHeightChange = Static.trackHeight * (1.0 - tracksScale)
        let trackPositionShift = (thumbView.center.x < lEdge ? -trackHeightChange : trackHeightChange)
        let trackHeight = Static.trackHeight * tracksScale
        [maximumTrackLayer, minimumTrackLayer].forEach {
            $0.position = .init(x: undershoot + trackPositionShift, y: bounds.midY)
            $0.bounds.size.height = trackHeight
            $0.cornerRadius = $0.bounds.size.height / 2.0
        }
        maximumTrackLayer.bounds.size.width = bounds.width - undershoot + overshoot - trackHeightChange
        if thumbView.frame.minX < Static.trackSpeedUpZone {
            let edgeProgress = max(0.0, thumbView.frame.minX / Static.trackSpeedUpZone)
            minimumTrackLayer.bounds.size.width = edgeProgress * thumbView.center.x
        } else if bounds.width - thumbView.frame.maxX < Static.trackSpeedUpZone {
            let edgeProgress = 1.0 - max(0.0, (bounds.width - thumbView.frame.maxX) / Static.trackSpeedUpZone)
            minimumTrackLayer.bounds.size.width = thumbView.center.x + (edgeProgress * (bounds.width - thumbView.center.x)) + overshoot
        } else {
            minimumTrackLayer.bounds.size.width = thumbView.center.x
        }
        let targetTicksNumber = trackConfiguration?.numberOfTicks ?? 0
        let ticksContainerWidth = bounds.width - Static.thumbWidth
        if targetTicksNumber > 1 && ticksContainerWidth > 0.0 {
            ticksContainerLayer.instanceCount = targetTicksNumber
            ticksContainerLayer.isHidden = false
            ticksContainerLayer.bounds.size = .init(
                width: ticksContainerWidth,
                height: Static.tickDotDimSize
            )
            let ticksContainerLayerY = bounds.midY + (trackHeight / 2.0) + 4.0
            if trackPositionShift > 0.0 {
                ticksContainerLayer.anchorPoint = .init(x: 0.0, y: 0.0)
                ticksContainerLayer.position = .init(
                    x: lEdge + trackPositionShift,
                    y: ticksContainerLayerY
                )
            } else {
                ticksContainerLayer.anchorPoint = .init(x: 1.0, y: 0.0)
                ticksContainerLayer.position = .init(
                    x: rEdge + trackPositionShift,
                    y: ticksContainerLayerY
                )
            }
            let dotsSpacing = ticksContainerLayer.bounds.size.width / CGFloat(targetTicksNumber - 1)
            ticksContainerLayer.instanceTransform = CATransform3DMakeTranslation(dotsSpacing, 0.0, 0.0)
            let scale = maximumTrackLayer.bounds.size.width / bounds.width
            ticksContainerLayer.setAffineTransform(.init(scaleX: scale, y: 1.0))
        } else {
            ticksContainerLayer.isHidden = true
        }
        CATransaction.commit()
    }

    func animateGestureFinalization() {
        pop_removeAnimation(forKey: Static.desiredThumbXCenterAnimatablePropName)
        if desiredThumbXCenter < lEdge {
            startThumbSpringAnimation(to: lEdge, shouldUpdateValue: true)
        } else if desiredThumbXCenter > rEdge {
            startThumbSpringAnimation(to: rEdge, shouldUpdateValue: true)
        } else if (trackConfiguration?.numberOfTicks ?? 0) > 1 {
            let targetValue = snappedValueIfNeeded(
                forDesiredThumbXCenter: desiredThumbXCenter,
                mode: {
                    if thumbView.lastVelocity > 0.0 {
                        .next
                    } else if thumbView.lastVelocity < 0.0 {
                        .previous
                    } else {
                        .nearest
                    }
                }()
            )
            startThumbSpringAnimation(to: desiredThumbXCenter(forValue: targetValue), shouldUpdateValue: true)
        } else if abs(thumbView.lastVelocity) > 0.0 {
            startThumbDecayAnimation(with: thumbView.lastVelocity, shouldUpdateValue: true)
        }
    }

    func startThumbSpringAnimation(to: CGFloat, shouldUpdateValue: Bool) {
        guard let anim = POPSpringAnimation(propertyNamed: Static.desiredThumbXCenterAnimatablePropName) else {
            assert(false)
            return
        }
        anim.fromValue = desiredThumbXCenter
        anim.toValue = to
        anim.springBounciness = 0.0
        anim.springSpeed = 10.0
        anim.property = desiredThumbXCenterAnimatable
        anim.delegate = shouldUpdateValue ? self : nil
        pop_add(anim, forKey: Static.desiredThumbXCenterAnimation)
    }

    func startThumbDecayAnimation(with velocity: CGFloat, shouldUpdateValue: Bool) {
        guard let anim = POPDecayAnimation(propertyNamed: Static.desiredThumbXCenterAnimatablePropName) else {
            assert(false)
            return
        }
        anim.velocity = velocity
        anim.deceleration = 0.985
        anim.property = desiredThumbXCenterAnimatable
        anim.delegate = shouldUpdateValue ? self : nil
        pop_add(anim, forKey: Static.desiredThumbXCenterAnimation)
    }

}
