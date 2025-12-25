import UIKit

public final class LGLensEffectsLayer: CALayer {

    // MARK: - Public Nested

    public struct LensEffectsProperties: Equatable {
        public struct Color: Equatable {
            var light: UIColor
            var dark: UIColor

            public init(light: UIColor, dark: UIColor) {
                self.light = light
                self.dark = dark
            }

            fileprivate func get(forLight: Bool) -> UIColor {
                return forLight ? light : dark
            }
        }

        public var mirroringZoneWidth: CGFloat
        public var visibleMirrorWidth: CGFloat
        public var mirrorBlurRadius: CGFloat
        public var mirrorBlurTransitionWidth: CGFloat
        public var mainShadowRequired: Bool
        public var edgesShadowRequired: Bool
        public var tintColor: Color
        public var topLeftGlareColor: Color
        public var bottomRightGlareColor: Color

        public init(mirroringZoneWidth: CGFloat, visibleMirrorWidth: CGFloat, mirrorBlurRadius: CGFloat, mirrorBlurTransitionWidth: CGFloat, mainShadowRequired: Bool, edgesShadowRequired: Bool, tintColor: Color, topLeftGlareColor: Color, bottomRightGlareColor: Color) {
            self.mirroringZoneWidth = mirroringZoneWidth
            self.visibleMirrorWidth = visibleMirrorWidth
            self.mirrorBlurRadius = mirrorBlurRadius
            self.mirrorBlurTransitionWidth = mirrorBlurTransitionWidth
            self.mainShadowRequired = mainShadowRequired
            self.edgesShadowRequired = edgesShadowRequired
            self.tintColor = tintColor
            self.topLeftGlareColor = topLeftGlareColor
            self.bottomRightGlareColor = bottomRightGlareColor
        }
    }
    
    // MARK: - Public Properties

    public override var cornerRadius: CGFloat { didSet {
        guard abs(oldValue - cornerRadius) > 0.001 else { return }
        edgeMirrorLayer.cornerRadius = cornerRadius
        updateSublayersMasks()
    }}
    public var effectsProperties: LensEffectsProperties? { didSet {
        guard oldValue != effectsProperties else { return }
        guard let effectsProperties else { return }
        edgeMirrorLayer.mirroringZoneWidth = effectsProperties.mirroringZoneWidth
        edgeMirrorLayer.visibleWidth = effectsProperties.visibleMirrorWidth
        edgeMirrorLayer.blurRadius = effectsProperties.mirrorBlurRadius
        edgeMirrorLayer.blurTransitionWidth = effectsProperties.mirrorBlurTransitionWidth
        mainShadowLayer.isHidden = !effectsProperties.mainShadowRequired
        topEdgeInnerShadowLayer.isHidden = !effectsProperties.edgesShadowRequired
        bottomEdgeOuterShadowLayer.isHidden = !effectsProperties.edgesShadowRequired
        updateTintColors()
    }}
    public var isLightEnvironment = true { didSet { updateTintColors() } }

    public var mainShadowOpacity: CGFloat {
        get { CGFloat(mainShadowLayer.shadowOpacity) }
        set { mainShadowLayer.shadowOpacity = Float(newValue) }
    }
    public var edgesShadowOpacity: CGFloat {
        get { CGFloat(topEdgeInnerShadowLayer.shadowOpacity) }
        set {
            topEdgeInnerShadowLayer.shadowOpacity = Float(newValue)
            bottomEdgeOuterShadowLayer.shadowOpacity = Float(newValue)
        }
    }

    // MARK: - Constructors

    public override init() {
        super.init()
        clippingLayer.mask = clippingMaskLayer

        outerEffectsContainer.mask = outerEffectsCutoutMaskLayer
        outerEffectsCutoutMaskLayer.fillRule = .evenOdd

        mainShadowLayer.shadowOpacity = 1.0
        mainShadowLayer.shadowRadius = 6.0
        mainShadowLayer.shadowOffset.height = 1.0
        mainShadowLayer.shadowColor = UIColor.black.withAlphaComponent(0.16).cgColor
        mainShadowLayer.backgroundColor = UIColor.clear.cgColor
        [topEdgeInnerShadowLayer, bottomEdgeOuterShadowLayer].forEach {
            $0.shadowOpacity = 1.0
            $0.shadowRadius = 3.0
            $0.shadowColor = UIColor.black.withAlphaComponent(0.11).cgColor
            $0.backgroundColor = UIColor.clear.cgColor
        }
        topEdgeInnerShadowLayer.shadowOffset.height = 7.0
        bottomEdgeOuterShadowLayer.shadowOffset.height = 4.0
        [topLeftGlareLayer, bottomRightGlareLayer].enumerated().forEach { index, layer in
            layer.contentsScale = UIScreen.main.scale
            layer.shadowOpacity = 1.0
            layer.shadowRadius = 0.0
            layer.shadowOffset.width =  index == 0 ? -0.5 : 0.5
            layer.shadowOffset.height = index == 0 ? -0.5 : 0.5
            layer.backgroundColor = UIColor.clear.cgColor
        }

        addSublayer(clippingLayer)
        clippingLayer.addSublayer(edgeMirrorLayer)
        clippingLayer.addSublayer(topEdgeInnerShadowLayer)
        clippingLayer.addSublayer(tintLayer)
        addSublayer(outerEffectsContainer)

        [mainShadowLayer, bottomEdgeOuterShadowLayer, topLeftGlareLayer, bottomRightGlareLayer].forEach {
            outerEffectsContainer.addSublayer($0)
        }
        [mainShadowLayer, topEdgeInnerShadowLayer, bottomRightGlareLayer, topLeftGlareLayer, bottomRightGlareLayer].forEach {
            $0.rasterizationScale = UIScreen.main.scale
            $0.shouldRasterize = true
        }

        allowsGroupOpacity = true
    }

    public required override init(layer: Any) {
        super.init(layer: layer)
        if let layer = layer as? LGLensEffectsLayer {
            self.effectsProperties = layer.effectsProperties
            self.isLightEnvironment = layer.isLightEnvironment
            self.mainShadowOpacity = layer.mainShadowOpacity
            self.edgesShadowOpacity = layer.edgesShadowOpacity
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    public override func layoutSublayers() {
        super.layoutSublayers()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let midPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        [clippingLayer, clippingMaskLayer, tintLayer, edgeMirrorLayer, outerEffectsContainer, mainShadowLayer, topEdgeInnerShadowLayer, bottomEdgeOuterShadowLayer, topLeftGlareLayer, bottomRightGlareLayer].forEach {
            $0.position = midPosition
            $0.bounds.size = bounds.size
        }
        if lastAcceptedBounds != bounds {
            lastAcceptedBounds = bounds
            updateSublayersMasks()
        }
        CATransaction.commit()
    }

    // MARK: - Private Properties

    private let clippingLayer = CALayer()
    private let edgeMirrorLayer = EdgeMirrorLayer()
    private let outerEffectsContainer = CALayer()
    private let mainShadowLayer = CALayer()
    private let topEdgeInnerShadowLayer = CALayer()
    private let bottomEdgeOuterShadowLayer = CALayer()
    private let topLeftGlareLayer = CALayer()
    private let bottomRightGlareLayer = CALayer()
    private let tintLayer = CALayer()

    private let clippingMaskLayer = CAShapeLayer()
    private let outerEffectsCutoutMaskLayer = CAShapeLayer()

    private var lastAcceptedBounds: CGRect?

}

fileprivate extension LGLensEffectsLayer {

    // MARK: - Private Methods

    func updateSublayersMasks() {
        guard bounds.width > 0.0, bounds.height > 0.0 else { return }
        let clippingMaskPath = UIBezierPath.roundedRect(rect: bounds, cornerRadius: cornerRadius)
        clippingMaskLayer.path = clippingMaskPath.cgPath

        let effectsPath = UIBezierPath.roundedRect(
            rect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerRadius: max(0.0, cornerRadius - 0.5)
        )
        [mainShadowLayer, bottomEdgeOuterShadowLayer, topLeftGlareLayer, bottomRightGlareLayer].forEach {
            $0.shadowPath = effectsPath.cgPath
        }
        let outerEffectsCutoutPath = UIBezierPath(rect: bounds.insetBy(
            dx: -2.0 * (mainShadowLayer.shadowRadius + mainShadowLayer.shadowOffset.width),
            dy: -2.0 * (mainShadowLayer.shadowRadius + mainShadowLayer.shadowOffset.height)
        ))
        outerEffectsCutoutPath.append(effectsPath)
        outerEffectsCutoutMaskLayer.path = outerEffectsCutoutPath.cgPath
        
        let topEdgeInnerShadowCutoutPath = UIBezierPath(rect: bounds.insetBy(
            dx: -(topEdgeInnerShadowLayer.shadowRadius + topEdgeInnerShadowLayer.shadowOffset.width),
            dy: -(topEdgeInnerShadowLayer.shadowRadius + topEdgeInnerShadowLayer.shadowOffset.height)
        ))
        topEdgeInnerShadowCutoutPath.append(UIBezierPath.roundedRect(
            rect: bounds,
            cornerRadius: cornerRadius
        ).reversing())
        topEdgeInnerShadowLayer.shadowPath = topEdgeInnerShadowCutoutPath.cgPath
    }

    func updateTintColors() {
        guard let effectsProperties else { return }
        tintLayer.backgroundColor = effectsProperties.tintColor.get(forLight: isLightEnvironment).cgColor
        topLeftGlareLayer.shadowColor = effectsProperties.topLeftGlareColor.get(forLight: isLightEnvironment).cgColor
        bottomRightGlareLayer.shadowColor = effectsProperties.bottomRightGlareColor.get(forLight: isLightEnvironment).cgColor
    }

}

fileprivate extension CGRect {
    var topRight: CGPoint { CGPoint(x: maxX, y: minY) }
    var topLeft: CGPoint { CGPoint(x: minX, y: minY) }
    var bottomRight: CGPoint { CGPoint(x: maxX, y: maxY) }
    var bottomLeft: CGPoint { CGPoint(x: minX, y: maxY) }
}

fileprivate extension UIBezierPath {
    static func roundedRect(rect: CGRect, cornerRadius: CGFloat) -> UIBezierPath {
        let path = CGMutablePath()
        let start = CGPoint(x: rect.midX, y: rect.minY)
        path.move(to: start)
        path.addArc(tangent1End: rect.topRight, tangent2End: rect.bottomRight, radius: cornerRadius)
        path.addArc(tangent1End: rect.bottomRight, tangent2End: rect.bottomLeft, radius: cornerRadius)
        path.addArc(tangent1End: rect.bottomLeft, tangent2End: rect.topLeft, radius: cornerRadius)
        path.addArc(tangent1End: rect.topLeft, tangent2End: start, radius: cornerRadius)
        return UIBezierPath(cgPath: path)
    }
}
