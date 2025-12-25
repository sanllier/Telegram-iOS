import UIKit
import LegacyComponents

public final class LGControlThumbView: UIView {

    // MARK: - Public Nested

    public enum DeselectionMode {
        case tinting
        case disappearing
    }

    // MARK: - Public Properties

    public let selectionScale: CGSize
    public let valocityScaleRangeWidth: CGFloat
    public override var tintColor: UIColor? { didSet { repaint() } }
    public var shouldAnimateSpeed = false

    public var currentScaleTransform: CGSize { thumbLayer.scaleTransform }
    public var onScaleTransformChanged: ((CGSize) -> Void)?
    public var currentSelectionProgress: CGFloat { thumbSelectionProgress }
    public var onSelectionProgressChanged: ((CGFloat) -> Void)?

    var moveOnWindowWhileSelected = false
    let thumbFaderLayer = CALayer()
    var lastVelocity: CGFloat { thumbVelocityCalculator.lastVelocity }

    // MARK: - Constructors

    public init(
        baseLensProperties: LGLayer.LensProperties,
        magnification: (deselected: CGFloat, selected: CGFloat),
        selectionScale: CGSize,
        valocityScaleRangeWidth: CGFloat,
        deselectedShadowRequired: Bool,
        deselectionMode: DeselectionMode
    ) {
        self.magnification = magnification
        self.selectionScale = selectionScale
        self.valocityScaleRangeWidth = valocityScaleRangeWidth
        self.deselectionMode = deselectionMode
        super.init(frame: .zero)
        tintColor = .white
        layer.masksToBounds = false
        containerLayer.anchorPoint = .zero
        containerLayer.position = .zero
        thumbLayer.lensProperties = baseLensProperties
        thumbFaderLayer.masksToBounds = true
        thumbLayer.anchorPoint = .zero
        thumbLayer.position = .zero
        thumbLayer.mainShadowOpacity = 1.0
        thumbLayer.edgesShadowOpacity = 0.0
        thumbFaderLayer.anchorPoint = .init(x: 0.5, y: 0.5)
        layer.addSublayer(containerLayer)
        containerLayer.addSublayer(thumbLayer)
        containerLayer.addSublayer(thumbFaderLayer)
        updateThumbAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    public override func layoutSubviews() {
        super.layoutSubviews()
        let minDim = min(bounds.width, bounds.height)
        containerLayer.bounds.size = bounds.size
        thumbLayer.bounds.size = .init(width: bounds.width - 1.0, height: bounds.height - 1.0)
        thumbLayer.position = .init(x: 0.5, y: 0.5)
        thumbLayer.cornerRadius = (minDim - 1.0) / 2.0
        thumbFaderLayer.bounds.size = bounds.size
        thumbFaderLayer.position = .init(x: bounds.midX, y: bounds.midY)
        thumbFaderLayer.sublayers?.forEach {
            $0.anchorPoint = .zero
            $0.position = .zero
            $0.bounds.size = thumbFaderLayer.bounds.size
        }
        thumbFaderLayer.cornerRadius = minDim / 2.0
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        repaint()
    }
    
    public func setSelected(_ selected: Bool) {
        delayedDeselectionAction?.cancel()
        if selected {
            selectionTimestamp = CACurrentMediaTime()
            _setSelected(true)
        } else {
            let currentTimestamp = CACurrentMediaTime()
            assert(selectionTimestamp != nil)
            let timeDelta = currentTimestamp - (selectionTimestamp ?? currentTimestamp)
            let minDelay = 0.25
            if timeDelta < minDelay {
                delayedDeselectionAction = {
                    let workItem = DispatchWorkItem { [weak self] in self?._setSelected(false) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + minDelay - timeDelta, execute: workItem)
                    return workItem
                }()
            } else {
                _setSelected(false)
            }
        }
    }

    // MARK: - Private Methods

    private let magnification: (deselected: CGFloat, selected: CGFloat)
    private let deselectionMode: DeselectionMode
    
    private let containerLayer = CALayer()
    private let thumbLayer = LGLayer()
    
    private var thumbSelectionProgress: CGFloat = 0.0 { didSet {
        guard abs(oldValue - thumbSelectionProgress) > 0.000001 else { return }
        if (oldValue > 0.0) != (thumbSelectionProgress > 0.0) {
            if moveOnWindowWhileSelected {
                guard let window else { return }
                if thumbSelectionProgress > 0.0 {
                    window.layer.addSublayer(containerLayer)
                } else {
                    layer.addSublayer(containerLayer)
                }
            } else if containerLayer.superlayer !== layer {
                layer.addSublayer(containerLayer)
            }
            updateDisplayLinkNeeded()
            updateThumbPosition()
        }
        thumbLayer.mainShadowOpacity = 1.0 - thumbSelectionProgress
        thumbLayer.edgesShadowOpacity = thumbSelectionProgress
        updateThumbAppearance()
        onSelectionProgressChanged?(thumbSelectionProgress)
    }}
    private var relativeThumbXSpeed = 1.0 { didSet { updateThumbAppearance() }}

    private var displayLinkNeeded = false { didSet {
        guard oldValue != displayLinkNeeded else { return }
        if displayLinkNeeded {
            displayLink.add(to: .main, forMode: .common)
        } else {
            displayLink.remove(from: .main, forMode: .common)
        }
    }}
    private lazy var displayLink = CADisplayLink(
        target: displayLinkProxy,
        selector: #selector(displayLinkProxy.onTick)
    )
    private lazy var displayLinkProxy = DisplayLinkProxy { [weak self] in
        guard let slf = self else { return }
        slf.thumbVelocityCalculator.onTick()
        slf.updateThumbPosition()
        slf.updateDisplayLinkNeeded()
    }
    private lazy var thumbVelocityCalculator = PointVelocityCalculator(
        pointProvider: { [weak self] in
            guard let slf = self else { return .zero }
            if let presentation = slf.layer.presentation() {
                return presentation.position
            } else {
                return slf.frame.origin
            }
        },
        onSpeedUpdated: { [weak self] in
            guard let slf = self else { return }
            guard slf.shouldAnimateSpeed else {
                if abs(slf.relativeThumbXSpeed - 1.0) > 0.001 {
                    slf.animateRelativeThumbXSpeed(to: 1.0)
                }
                return
            }
            slf.animateRelativeThumbXSpeed(to: CGFloat(1.0 + ($0 / 200.0)).rubberBanded(
                in: (1.0...1.0),
                limit: slf.valocityScaleRangeWidth,
                stiffness: 0.1
            ))
        }
    )

    private lazy var thumbSelectionProgressAnimatable = POPAnimatableProperty.property(
        withName: Static.thumbSelectionProgressAnimatablePropName,
        initializer: { prop in
            guard let prop else { return }
            prop.readBlock = { obj, values in
                guard let slf = obj as? LGControlThumbView else { assert(false); return }
                guard let values else { return }
                values[0] = slf.thumbSelectionProgress
            }
            prop.writeBlock = { obj, values in
                guard let slf = obj as? LGControlThumbView else { assert(false); return }
                guard let values else { return }
                slf.thumbSelectionProgress = values[0]
            }
            prop.threshold = 0.0001
        }
    ) as? POPAnimatableProperty
    private lazy var relativeThumbXSpeedAnimatable = POPAnimatableProperty.property(
        withName: Static.relativeThumbXSpeedAnimatablePropName,
        initializer: { prop in
            guard let prop else { return }
            prop.readBlock = { obj, values in
                guard let slf = obj as? LGControlThumbView else { assert(false); return }
                guard let values else { return }
                values[0] = slf.relativeThumbXSpeed
            }
            prop.writeBlock = { obj, values in
                guard let slf = obj as? LGControlThumbView else { assert(false); return }
                guard let values else { return }
                slf.relativeThumbXSpeed = values[0]
            }
            prop.threshold = 0.001
        }
    ) as? POPAnimatableProperty

    private var selectionTimestamp: CFTimeInterval?
    private var delayedDeselectionAction: DispatchWorkItem?

}

fileprivate extension LGControlThumbView {

    // MARK: - Private Nested

    enum Static {
        static let thumbSelectionProgressAnimatablePropName = "thumb_selection_progress"
        static let thumbSelectionProgressAnimation = "thumb_selection_progress"

        static let relativeThumbXSpeedAnimatablePropName = "relative_thumb_x_speed"
        static let relativeThumbXSpeedAnimation = "relative_thumb_x_speed"
    }
    
    // MARK: - Private Nested

    func updateDisplayLinkNeeded() {
//        let onWindow = containerLayer.superlayer === window?.layer
//        let isMoving = abs(thumbVelocityCalculator.lastVelocity) > 0.0
        displayLinkNeeded = true//onWindow || isMoving
    }
    
    func repaint() {
        thumbFaderLayer.backgroundColor = tintColor?.cgColor
        switch traitCollection.userInterfaceStyle {
        case .dark: thumbLayer.isLightEnvironment = false
        default: thumbLayer.isLightEnvironment = true
        }
    }

    func _setSelected(_ selected: Bool) {
        let toValue = selected ? 1.0 : 0.0
        let springBounciness: CGFloat
        switch deselectionMode {
        case .tinting: springBounciness = selected ? 12.0 : 6.0
        case .disappearing: springBounciness = selected ? 12.0 : 0.0
        }
        if let anim = pop_animation(forKey: Static.thumbSelectionProgressAnimation) as? POPSpringAnimation {
            anim.toValue = toValue
            anim.springBounciness = springBounciness
        } else {
            guard let anim = POPSpringAnimation(propertyNamed: Static.thumbSelectionProgressAnimatablePropName) else {
                assert(false)
                return
            }
            anim.fromValue = thumbSelectionProgress
            anim.toValue = toValue
            anim.springBounciness = springBounciness
            anim.springSpeed = 16.0
            anim.property = thumbSelectionProgressAnimatable
            pop_add(anim, forKey: Static.thumbSelectionProgressAnimation)
        }
    }

    func updateThumbPosition() {
        let targetPosition: CGPoint
        if containerLayer.superlayer === window?.layer {
            let animationShift: CGPoint
            if let presentation = layer.presentation() {
                let model = layer.model()
                animationShift = .init(
                    x: presentation.position.x - model.position.x,
                    y: presentation.position.y - model.position.y
                )
            } else {
                animationShift = .zero
            }
            targetPosition = convert(animationShift, to: nil)
        } else {
            targetPosition = .zero
        }
        guard targetPosition != containerLayer.position else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        containerLayer.position = targetPosition
        CATransaction.commit()
    }

    func updateThumbAppearance() {
        let selectionScaleX = 1.0 + (selectionScale.width - 1.0) * thumbSelectionProgress
        let selectionScaleY = 1.0 + (selectionScale.height - 1.0) * thumbSelectionProgress
        let xScale = selectionScaleX * relativeThumbXSpeed
        let yScale = selectionScaleY * (2.0 - relativeThumbXSpeed)
        thumbLayer.lensProperties?.update {
            let magnificationDelta = magnification.selected - magnification.deselected
            $0.magnification = magnification.deselected + magnificationDelta * thumbSelectionProgress
        }
        thumbLayer.scaleTransform = .init(width: xScale, height: yScale)
        onScaleTransformChanged?(thumbLayer.scaleTransform)
        thumbFaderLayer.setAffineTransform(.init(scaleX: xScale, y: yScale))
        switch deselectionMode {
        case .tinting:
            thumbLayer.opacity = 1.0
            thumbFaderLayer.opacity = Float(1.0 - thumbSelectionProgress)
        case .disappearing:
            thumbLayer.opacity = Float(thumbSelectionProgress)
            thumbFaderLayer.opacity = 0.0
        }
    }

    func animateRelativeThumbXSpeed(to: CGFloat) {
        if let anim = pop_animation(forKey: Static.relativeThumbXSpeedAnimation) as? POPSpringAnimation {
            anim.toValue = to
        } else {
            guard let anim = POPSpringAnimation(propertyNamed: Static.relativeThumbXSpeedAnimatablePropName) else {
                assert(false)
                return
            }
            anim.fromValue = relativeThumbXSpeed
            anim.toValue = to
            anim.springBounciness = 20.0
            anim.springSpeed = 10.0
            anim.property = relativeThumbXSpeedAnimatable
            pop_add(anim, forKey: Static.relativeThumbXSpeedAnimation)
        }
    }

}

fileprivate final class DisplayLinkProxy {
    let _onTick: () -> Void
    init(onTick: @escaping () -> Void) { self._onTick = onTick }
    @objc func onTick() { _onTick() }
}
