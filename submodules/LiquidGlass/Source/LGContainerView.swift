import UIKit
import LegacyComponents

public final class LGContainerView: UIView {

    // MARK: - Public Properties

    override public class var layerClass: AnyClass { LGContainerLayer.self }

    public let contentView = UIView(frame: .zero)
    public var lensProperties: LGLayer.LensProperties {
        get { _lensProperties }
        set { _lensProperties = newValue }
    }
    public var isInteractive: Bool {
        get { longPressRecognizer.isEnabled }
        set { longPressRecognizer.isEnabled = newValue }
    }
    public var alwaysRubberBanding = true

    // MARK: - Constructors

    public override init(frame: CGRect) {
        super.init(frame: frame)
        glassLayer.lensProperties = _lensProperties
        if let layer = layer as? LGContainerLayer {
            layer.onCornerRadiusChanged = { [weak self] in
                self?.glassLayer.cornerRadius = $0
                self?.selectionEffectContainer.cornerRadius = $0
            }
        } else {
            assert(false)
        }
        layer.addSublayer(glassLayer)
        super.addSubview(contentView)
        selectionEffectContainer.masksToBounds = true
        contentView.layer.addSublayer(selectionEffectContainer)
        updateLightEnvironment()
        addGestureRecognizer(longPressRecognizer)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    public override func addSubview(_ view: UIView) {
        assert(false, "Add subviews to contentView instead not container itself!")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        glassLayer.position = .init(x: bounds.midX, y: bounds.midY)
        glassLayer.bounds.size = bounds.size
        contentView.center = .init(x: bounds.midX, y: bounds.midY)
        contentView.bounds.size = bounds.size
        selectionEffectContainer.position = .init(x: bounds.midX, y: bounds.midY)
        selectionEffectContainer.bounds.size = bounds.size
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateLightEnvironment()
    }

    // MARK: - Private Properties

    private let glassLayer = LGLayer()
    private var _lensProperties: LGLayer.LensProperties = .regular() { didSet {
        glassLayer.lensProperties = _lensProperties
    }}

    private let selectionEffectContainer = CALayer()
    private var activeSelectionHighlight: CALayer?
    private var activeSelectionGradient: CALayer?
    
    private lazy var longPressRecognizer = LGGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
    private var trackingTouchContext: TouchContext?

    private var isBigEnoughView: Bool { max(bounds.width, bounds.height) >= 200.0 }
    
    private var gravityPoint: Point3D? { didSet {
        guard let gravityPoint else {
            oldValue.map { setIdentityPlainStateAnimated(from: .init(x: $0.x, y: $0.y)) }
            return
        }
        let scale = gravityPoint.lgScale(
            in: bounds,
            maxScale: isBigEnoughView ? 1.02 : 1.08,
            maxZScale: 1.4,
            stiffness: 0.07
        )
        gravityScale = scale
        gravityTranslation = gravityPoint.lgTanslation(
            forScale: scale,
            size: bounds.size,
            maxRadius: isBigEnoughView ? 5.0 : 50.0,
            stiffness: 0.05
        )
    }}
    private var elevation: CGFloat = 0.0 { didSet {
        guard abs(elevation - oldValue) > 0.0001 else { return }
        gravityPoint = .init(x: gravityPoint?.x ?? 0.0, y: gravityPoint?.y ?? 0.0, z: elevation)
    }}
    private var gravityScale: CGSize {
        get { glassLayer.scaleTransform }
        set {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            glassLayer.scaleTransform = newValue
            updateContentTransform()
            CATransaction.commit()
        }
    }
    private var gravityTranslation: CGPoint = .zero { didSet {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glassLayer.setAffineTransform(.init(translationX: gravityTranslation.x, y: gravityTranslation.y))
        updateContentTransform()
        CATransaction.commit()
    }}

    private var selectionTimestamp: CFTimeInterval?
    private var delayedDeselectionAction: DispatchWorkItem?
    
    private lazy var gravityPlainPointAnimatable = POPAnimatableProperty.property(
        withName: Static.gravityPlainPointPropName,
        initializer: { prop in
            guard let prop else { return }
            prop.readBlock = { obj, values in
                guard let slf = obj as? LGContainerView else { assert(false); return }
                guard let values, let gravityPoint = slf.gravityPoint else { return }
                values[0] = gravityPoint.x
                values[1] = gravityPoint.y
            }
            prop.writeBlock = { obj, values in
                guard let slf = obj as? LGContainerView else { assert(false); return }
                guard let values else { return }
                let ground: (CGFloat) -> CGFloat = { abs($0) < 0.1 ? 0.0 : $0 }
                slf.gravityPoint = .init(x: ground(values[0]), y: ground(values[1]), z: slf.elevation)
            }
            prop.threshold = 0.1
        }
    ) as? POPAnimatableProperty
    private lazy var elevationAnimatable = POPAnimatableProperty.property(
        withName: Static.elevationPropName,
        initializer: { prop in
            guard let prop else { return }
            prop.readBlock = { obj, values in
                guard let slf = obj as? LGContainerView else { assert(false); return }
                guard let values else { return }
                values[0] = slf.elevation
            }
            prop.writeBlock = { obj, values in
                guard let slf = obj as? LGContainerView else { assert(false); return }
                guard let values else { return }
                let ground: (CGFloat) -> CGFloat = { abs($0) < 0.1 ? 0.0 : $0 }
                slf.elevation = ground(values[0])
            }
            prop.threshold = 0.1
        }
    ) as? POPAnimatableProperty
    
}

fileprivate extension LGContainerView {

    // MARK: - Private Nested

    enum Static {
        static let gravityPlainPointAnimationKey = "gravity-plain-point"
        static let gravityPlainPointPropName = "lg.gravity-plain-point-animatable"

        static let elevationAnimationKey = "lg.elevation"
        static let elevationPropName = "lg.elevation-animatable"

        static let gradientImage = UIImage.generateRadialGradientImage(
            size: 250.0,
            colors: [.white.withAlphaComponent(0.1), .white.withAlphaComponent(0.0)]
        )
    }

    final class LGContainerLayer: CALayer {
        override var masksToBounds: Bool { get { false } set { } }
        override var cornerRadius: CGFloat { didSet { onCornerRadiusChanged?(cornerRadius) } }
        var onCornerRadiusChanged: ((CGFloat) -> Void)?
    }

    struct TouchContext {
        var initialTouchLocation: CGPoint
    }
    
    // MARK: - Private Methods

    func updateContentTransform() {
        contentView.transform = .init(translationX: gravityTranslation.x, y: gravityTranslation.y)
            .scaledBy(x: gravityScale.width, y: gravityScale.height)
    }

    func updateLightEnvironment() {
        switch traitCollection.userInterfaceStyle {
        case .dark: glassLayer.isLightEnvironment = false
        default: glassLayer.isLightEnvironment = true
        }
    }
    
    @objc func onLongPress(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            cancelRunningAnimations()
            trackingTouchContext = .init(initialTouchLocation: sender.location(in: self))
            updateGravityPoint()
            setSelected(true)
            updateSelectionGradient()
        case .changed:
            updateGravityPoint()
            updateSelectionGradient()
        case .ended, .cancelled, .failed:
            trackingTouchContext = nil
            updateGravityPoint()
            setSelected(false)
            updateSelectionGradient()
        default:
            break
        }
    }

    func updateGravityPoint() {
        guard let trackingTouchContext else { gravityPoint = nil; return }
        switch longPressRecognizer.state {
        case .began, .changed: break
        default: gravityPoint = nil; return
        }
        let currentLocation = longPressRecognizer.location(in: self)
        let targetPlainGravityPoint: CGPoint
        if alwaysRubberBanding {
            targetPlainGravityPoint = .init(
                x: currentLocation.x - trackingTouchContext.initialTouchLocation.x,
                y: currentLocation.y - trackingTouchContext.initialTouchLocation.y
            )
        } else {
            func gravity(of point: CGFloat, dimSize: CGFloat) -> CGFloat {
                if point < 0.0 {
                    return point
                } else if point > dimSize {
                    return point - dimSize
                } else {
                    return 0.0
                }
            }
            targetPlainGravityPoint = .init(
                x: gravity(of: currentLocation.x, dimSize: bounds.width),
                y: gravity(of: currentLocation.y, dimSize: bounds.height),
            )
        }
        if let runningAnimation = pop_animation(forKey: Static.gravityPlainPointAnimationKey) as? POPSpringAnimation {
            runningAnimation.toValue = targetPlainGravityPoint
            runningAnimation.springBounciness = 0.0
        } else {
            beginGravityPlainPointAnimation(
                from: gravityPoint.map { .init(x: $0.x, y: $0.y) } ?? .zero,
                to: targetPlainGravityPoint
            )
        }
    }

    func setSelected(_ selected: Bool) {
        delayedDeselectionAction?.cancel()
        if selected {
            selectionTimestamp = CACurrentMediaTime()
            animateSetSelected(to: true)
        } else {
            let currentTimestamp = CACurrentMediaTime()
            assert(selectionTimestamp != nil)
            let timeDelta = currentTimestamp - (selectionTimestamp ?? currentTimestamp)
            let minDelay = 0.15
            if timeDelta < minDelay {
                delayedDeselectionAction = {
                    let workItem = DispatchWorkItem { [weak self] in self?.animateSetSelected(to: false) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + minDelay - timeDelta, execute: workItem)
                    return workItem
                }()
            } else {
                animateSetSelected(to: false)
            }
        }
    }

    func animateSetSelected(to selected: Bool) {
        let toValue = selected ? 80.0 : 0.0
        if let anim = pop_animation(forKey: Static.elevationAnimationKey) as? POPSpringAnimation {
            anim.toValue = toValue
        } else {
            guard let anim = POPSpringAnimation(propertyNamed: Static.elevationPropName) else {
                assert(false)
                return
            }
            anim.fromValue = elevation
            anim.toValue = toValue
            anim.springBounciness = 18.0
            anim.springSpeed = 12.0
            anim.property = elevationAnimatable
            pop_add(anim, forKey: Static.elevationAnimationKey)
        }
    }
    
    func setIdentityPlainStateAnimated(from plainGravityPoint: CGPoint) {
        beginGravityPlainPointAnimation(from: plainGravityPoint, to: .zero)
    }

    func beginGravityPlainPointAnimation(from: CGPoint, to: CGPoint) {
        cancelRunningAnimations()
        guard let anim = POPSpringAnimation(propertyNamed: Static.gravityPlainPointPropName) else { assert(false); return }
        anim.fromValue = from
        anim.toValue = to
        anim.springBounciness = 10.0
        anim.springSpeed = 5.0
        anim.property = gravityPlainPointAnimatable
        pop_add(anim, forKey: Static.gravityPlainPointAnimationKey)
    }

    func cancelRunningAnimations() {
        pop_removeAnimation(forKey: Static.gravityPlainPointAnimationKey)
    }

    func updateSelectionGradient() {
        switch longPressRecognizer.state {
        case .began:
            if activeSelectionGradient == nil {
                guard let gradientImage = Static.gradientImage else { assert(false); return }
                let gradient = CALayer()
                gradient.contentsScale = UIScreen.main.scale
                gradient.contents = gradientImage.cgImage
                gradient.bounds.size = .init(width: gradientImage.size.width, height: gradientImage.size.height)
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                selectionEffectContainer.addSublayer(gradient)
                CATransaction.commit()
                activeSelectionGradient = gradient
            }
            if activeSelectionHighlight == nil {
                let highlight = CALayer()
                highlight.backgroundColor = UIColor.white.withAlphaComponent(0.05).cgColor
                highlight.position = .init(x: bounds.midX, y: bounds.midY)
                highlight.bounds.size = bounds.size
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                selectionEffectContainer.addSublayer(highlight)
                CATransaction.commit()
                activeSelectionHighlight = highlight
            }
            let touchLocation = longPressRecognizer.location(in: self)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            activeSelectionGradient?.position = .init(
                x: max(0.0, min(bounds.width, touchLocation.x)),
                y: max(0.0, min(bounds.height, touchLocation.y))
            )
            if !isBigEnoughView {
                activeSelectionGradient?.setAffineTransform(.init(scaleX: 0.5, y: 0.5))
            }
            CATransaction.commit()
        case .changed:
            let touchLocation = longPressRecognizer.location(in: self)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            activeSelectionGradient?.position = .init(
                x: max(0.0, min(bounds.width, touchLocation.x)),
                y: max(0.0, min(bounds.height, touchLocation.y))
            )
            CATransaction.commit()
            guard isBigEnoughView else { return }
            guard let activeSelectionGradient, let trackingTouchContext else { assert(false); return }
            let dimmedOpacity: Float = 0.27
            guard activeSelectionGradient.opacity > dimmedOpacity else { return }
            let vector = CGPoint(
                x: touchLocation.x - trackingTouchContext.initialTouchLocation.x,
                y: touchLocation.y - trackingTouchContext.initialTouchLocation.y
            )
            guard hypot(vector.x, vector.y) > 60.0 else { return }
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.4)
            activeSelectionGradient.opacity = dimmedOpacity
            activeSelectionGradient.transform = CATransform3DMakeScale(1.8, 1.8, 1.0)
            CATransaction.commit()
        default:
            guard let activeSelectionGradient, let activeSelectionHighlight else { return }
            self.activeSelectionGradient = nil
            self.activeSelectionHighlight = nil
            let gradientAnimationGroup = CAAnimationGroup()
            gradientAnimationGroup.duration = 0.5
            gradientAnimationGroup.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            let gradientScaleAnimationX = CABasicAnimation(keyPath: "transform.scale.x")
            gradientScaleAnimationX.toValue = 3.5

            let gradientScaleAnimationY = CABasicAnimation(keyPath: "transform.scale.y")
            gradientScaleAnimationY.toValue = 3.5

            let gradientOpacityAnimation = CABasicAnimation(keyPath: "opacity")
            gradientOpacityAnimation.toValue = 0.0
            gradientOpacityAnimation.beginTime = 0.1
            gradientOpacityAnimation.duration = 0.4

            gradientAnimationGroup.animations = [gradientScaleAnimationX, gradientScaleAnimationY, gradientOpacityAnimation]
            gradientAnimationGroup.isRemovedOnCompletion = false
            gradientAnimationGroup.fillMode = .forwards

            let highlightOpacityAnimation = CABasicAnimation(keyPath: "opacity")
            highlightOpacityAnimation.toValue = 0.0
            highlightOpacityAnimation.duration = 0.5
            highlightOpacityAnimation.isRemovedOnCompletion = false
            highlightOpacityAnimation.fillMode = .forwards

            CATransaction.begin()
            CATransaction.setCompletionBlock {
                activeSelectionHighlight.removeFromSuperlayer()
                activeSelectionGradient.removeFromSuperlayer()
            }
            activeSelectionHighlight.add(highlightOpacityAnimation, forKey: "highlight_disappearing")
            activeSelectionGradient.add(gradientAnimationGroup, forKey: "gradient_disappearing")
            CATransaction.commit()
        }
    }

}

fileprivate extension UIImage {

    static func generateRadialGradientImage(size: CGFloat, colors: [UIColor]) -> UIImage? {
        let rect = CGRect(x: 0.0, y: 0.0, width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        let cgColors = colors.map { $0.cgColor } as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: cgColors,
            locations: nil
        ) else {
            UIGraphicsEndImageContext()
            return nil
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = size / 2.0
        context.drawRadialGradient(
            gradient,
            startCenter: center, startRadius: 0,
            endCenter: center, endRadius: radius,
            options: []
        )
        return UIGraphicsGetImageFromCurrentImageContext()
    }

}

fileprivate struct Point3D {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat

    static var zero: Point3D { .init(x: 0.0, y: 0.0, z: 0.0) }
}

fileprivate extension Point3D {

    func lgScale(in bounds: CGRect, maxScale: CGFloat, maxZScale: CGFloat, stiffness: CGFloat) -> CGSize {
        let magnitudeXY = hypot(x, y)
        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0
        if magnitudeXY > 0.0 {
            let normX = abs(x) / magnitudeXY
            let normY = abs(y) / magnitudeXY
            let sxMagnitude = (normX - 0.5) * magnitudeXY
            let syMagnitude = (normY - 0.5) * magnitudeXY
            scaleX = scale(dimension: bounds.width, magnitude: sxMagnitude, maxScale: maxScale, stiffness: stiffness)
            scaleY = scale(dimension: bounds.height, magnitude: syMagnitude, maxScale: maxScale, stiffness: stiffness)
        }
        let zDimension = max(bounds.width, bounds.height)
        let scaleZ = scale(dimension: zDimension, magnitude: z, maxScale: maxZScale, stiffness: 0.2)
        return .init(
            width: scaleX * scaleZ,
            height: scaleY * scaleZ
        )
    }

    func lgTanslation(forScale scale: CGSize, size: CGSize, maxRadius: CGFloat, stiffness: CGFloat) -> CGPoint {
        let scaleOffsetX = (size.width * (1.0 - scale.width)) / 2.0
        let scaleOffsetY = (size.height * (1.0 - scale.height)) / 2.0
        let fullTranslationX = x + (x >= 0 ? scaleOffsetX : -scaleOffsetX)
        let fullTranslationY = y + (y >= 0 ? scaleOffsetY : -scaleOffsetY)
        let magnitude = hypot(fullTranslationX, fullTranslationY)
        guard magnitude > 0.0 else { return .zero }
        let clampedMagnitude = (1.0 - (1.0 / ((magnitude * stiffness / maxRadius) + 1.0))) * maxRadius
        let scale = clampedMagnitude / magnitude
        return .init(x: fullTranslationX * scale, y: fullTranslationY * scale)
    }

}

fileprivate func scale(
    dimension: CGFloat,
    magnitude: CGFloat,
    maxScale: CGFloat,
    stiffness: CGFloat
) -> CGFloat {
    guard dimension > 0 else { return 1.0 }
    if magnitude >= 0 {
        let maxOverflow = (maxScale - 1.0) * dimension
        let overflow = (1.0 - (1.0 / ((magnitude * stiffness / dimension) + 1.0))) * dimension
        let clampedOverflow = min(overflow, maxOverflow)
        let scale = 1.0 + (clampedOverflow / dimension)
        return smoothNearUnity(scale: scale, maxScale: maxScale)
    } else {
        let minScale = 1.0 / (maxScale * 2.0)
        let absMagnitude = abs(magnitude)
        let maxShrink = 1.0 - minScale
        let linearShrink = (1.0 - (1.0 / ((absMagnitude * stiffness / dimension) + 1.0))) * dimension
        let normalizedShrink = min(linearShrink / dimension, maxShrink) / maxShrink
        let scale = 1.0 - (normalizedShrink * maxShrink)
        return smoothNearUnity(scale: scale, maxScale: maxScale)
    }
}

fileprivate func smoothNearUnity(scale: CGFloat, maxScale: CGFloat) -> CGFloat {
    let minScale = 1.0 / maxScale
    let threshold = 1.0
    let easing = 1.5
    if scale >= 1.0 {
        let upperBound = 1.0 + threshold * (maxScale - 1.0)
        if scale <= upperBound {
            let t = (scale - 1.0) / (upperBound - 1.0)
            let eased = pow(t, easing)
            return 1.0 + eased * (upperBound - 1.0)
        }
    } else {
        let lowerBound = 1.0 - threshold * (1.0 - minScale)
        if scale >= lowerBound {
            let t = (1.0 - scale) / (1.0 - lowerBound)
            let eased = pow(t, easing)
            return 1.0 - eased * (1.0 - lowerBound)
        }
    }
    return scale
}
