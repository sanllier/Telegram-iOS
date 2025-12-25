import UIKit
import CoreImage.CIFilterBuiltins
import UIKitRuntimeUtils

public final class LGLayer: CALayer {

    // MARK: - Public Nested

    public struct LensProperties: Equatable {
        public var lensBlurRequired: Bool
        public var effectsProperties: LGLensEffectsLayer.LensEffectsProperties?
        public var magnification: CGFloat

        public init(
            lensBlurRequired: Bool,
            effectsProperties: LGLensEffectsLayer.LensEffectsProperties?,
            magnification: CGFloat
        ) {
            self.lensBlurRequired = lensBlurRequired
            self.effectsProperties = effectsProperties
            self.magnification = magnification
        }

        public mutating func update(_ actions: (inout Self) -> Void) {
            actions(&self)
        }

        public func updating(_ actions: (inout Self) -> Void) -> Self {
            var ret = self
            actions(&ret)
            return ret
        }
    }

    // MARK: - Public Properties

    public override var cornerRadius: CGFloat { didSet {
        effectsLayer.cornerRadius = cornerRadius
        updateSublayersTransforms()
    }}
    var scaleTransform: CGSize = .init(width: 1.0, height: 1.0) { didSet {
        guard oldValue != scaleTransform else { return }
        updateSublayersTransforms()
    }}
    var lensProperties: LensProperties? { didSet {
        guard oldValue != lensProperties else { return }
        guard let lensProperties else { return }
        if let effectsProperties = lensProperties.effectsProperties {
            effectsLayer.isHidden = false
            effectsLayer.effectsProperties = effectsProperties
        } else {
            effectsLayer.isHidden = true
        }
        updateLensBlur()
        updateLensMeshTransform()
    }}
    var mainShadowOpacity: CGFloat {
        get { effectsLayer.mainShadowOpacity }
        set { effectsLayer.mainShadowOpacity = newValue }
    }
    var edgesShadowOpacity: CGFloat {
        get { effectsLayer.edgesShadowOpacity }
        set { effectsLayer.edgesShadowOpacity = newValue }
    }
    var isLightEnvironment: Bool {
        get { effectsLayer.isLightEnvironment }
        set { effectsLayer.isLightEnvironment = newValue }
    }

    // MARK: - Constructors

    override init() {
        self.magnifyingLayer = createCABackdropLayer() ?? .init()
        super.init()
        containerLayer.mask = containerLayerMaskLayer
        magnifyingLayer.rasterizationScale = UIScreen.main.scale
        addSublayer(containerLayer)
        containerLayer.addSublayer(magnifyingLayer)
        addSublayer(effectsLayer)
        allowsGroupOpacity = true
    }

    required override init(layer: Any) {
        self.magnifyingLayer = CALayer()
        super.init(layer: layer)
        if let layer = layer as? LGLayer {
            self.lensProperties = layer.lensProperties
            self.scaleTransform = layer.scaleTransform
            self.lastAcceptedBounds = layer.lastAcceptedBounds
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    public override func layoutSublayers() {
        super.layoutSublayers()
        let midPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        containerLayer.position = midPosition
        containerLayer.bounds.size = bounds.size
        containerLayerMaskLayer.position = midPosition
        containerLayerMaskLayer.bounds.size = bounds.size
        magnifyingLayer.position = midPosition
        magnifyingLayer.bounds.size = .init(
            width: bounds.width + 2 * Static.lensOutline,
            height: bounds.height + 2 * Static.lensOutline
        )
        effectsLayer.position = midPosition
        effectsLayer.bounds.size = bounds.size
        if lastAcceptedBounds != bounds {
            lastAcceptedBounds = bounds
            updateLensMeshTransform()
        }
        updateSublayersTransforms()
    }

    // MARK: - Private Properties

    private let containerLayer = CALayer()
    private let magnifyingLayer: CALayer
    private let effectsLayer = LGLensEffectsLayer()

    private let containerLayerMaskLayer = CAShapeLayer()

    private var lastAcceptedBounds: CGRect?

}

fileprivate extension LGLayer {

    // MARK: - Private Nested

    enum Static {
        static let lensOutline = 100.0
    }

    // MARK: - Private Methods

    func updateLensBlur() {
        guard let lensProperties else { return }
        if lensProperties.lensBlurRequired {
            magnifyingLayer.filters = [
                createCAFilter("gaussianBlur").map {
                    $0.setValue(3.5, forKey: "inputRadius")
                    return $0
                } as Any
            ]
        } else {
            magnifyingLayer.filters = []
        }
    }

    func updateLensMeshTransform() {
        guard let lensProperties, bounds.height > 0.0, bounds.width > 0.0 else { return }
        let value = (lensProperties.magnification - 1.0) / 2.0
        let lValue = -value
        let rValue = 1.0 + value
        var verticesBuffer: [CAMeshVertex] = [
            .init(from: .init(x: 0.0, y: 0.0), to: .init(x: lValue, y: lValue, z: 0.0)),
            .init(from: .init(x: 1.0, y: 0.0), to: .init(x: rValue, y: lValue, z: 0.0)),
            .init(from: .init(x: 1.0, y: 1.0), to: .init(x: rValue, y: rValue, z: 0.0)),
            .init(from: .init(x: 0.0, y: 1.0), to: .init(x: lValue, y: rValue, z: 0.0))
        ]
        var facesBuffer: [CAMeshFace] = [.init(indices: (0, 1, 2, 3), w: (0.0, 0.0, 0.0, 0.0))]
        magnifyingLayer.setValue(
            createCAMutableMeshTransform(
                UInt(verticesBuffer.count),
                &verticesBuffer,
                UInt(facesBuffer.count),
                &facesBuffer,
                kCADepthNormalizationNone
            ),
            forKey: "meshTransform"
        )
    }

    func updateSublayersTransforms() {
        guard bounds.width > 0.0, bounds.height > 0.0 else { return }
        let containerMaskPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        containerLayerMaskLayer.path = containerMaskPath.cgPath
        let transform = CATransform3DMakeScale(scaleTransform.width, scaleTransform.height, 1.0)
        containerLayerMaskLayer.transform = transform
        effectsLayer.transform = transform
    }

}

public extension LGLayer.LensProperties {

    static func regular() -> Self {
        .init(
            lensBlurRequired: true,
            effectsProperties: .init(
                mirroringZoneWidth: 13.0,
                visibleMirrorWidth: 13.0,
                mirrorBlurRadius: 2.5,
                mirrorBlurTransitionWidth: 13.0,
                mainShadowRequired: true,
                edgesShadowRequired: false,
                tintColor: .init(
                    light: .white.withAlphaComponent(0.6),
                    dark: .init(white: 0.05, alpha: 0.5)
                ),
                topLeftGlareColor: .init(
                    light: .white.withAlphaComponent(0.3),
                    dark: .white.withAlphaComponent(0.3)
                ),
                bottomRightGlareColor: .init(
                    light: .white.withAlphaComponent(0.3),
                    dark: .white.withAlphaComponent(0.3)
                )
            ),
            magnification: 1.0
        )
    }

    static func clear() -> Self {
        .init(
            lensBlurRequired: false,
            effectsProperties: .init(
                mirroringZoneWidth: 3.0,
                visibleMirrorWidth: 3.0,
                mirrorBlurRadius: 2.5,
                mirrorBlurTransitionWidth: 6.0,
                mainShadowRequired: false,
                edgesShadowRequired: true,
                tintColor: .init(
                    light: .black.withAlphaComponent(0.008),
                    dark: .white.withAlphaComponent(0.08)
                ),
                topLeftGlareColor: .init(
                    light: .black.withAlphaComponent(0.25),
                    dark: .black.withAlphaComponent(0.25)
                ),
                bottomRightGlareColor: .init(
                    light: .white.withAlphaComponent(0.4),
                    dark: .white.withAlphaComponent(0.4)
                )
            ),
            magnification: 0.8
        )
    }

}
