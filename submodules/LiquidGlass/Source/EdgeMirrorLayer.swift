import UIKit
import UIKitRuntimeUtils

public final class EdgeMirrorLayer: CALayer {

    // MARK: - Public Properties

    public override var cornerRadius: CGFloat { didSet { shouldUpdateBlurMask = true; setNeedsLayout() } }
    public var mirroringZoneWidth: CGFloat = 2.0 { didSet { updateMesh() } }
    public var visibleWidth: CGFloat = 2.0 { didSet { updateClippingMasks() } }
    public var blurRadius = 1.0 { didSet { blurBackdropLayer?.setValue(blurRadius, forKeyPath: "filters.blur.inputRadius") } }
    public var blurTransitionWidth = 8.0 { didSet { shouldUpdateBlurMask = true; setNeedsLayout() } }

    // MARK: - Constructors

    public override init() {
        super.init()
        mirrorBackdropLayer.map {
            addSublayer($0)
            $0.rasterizationScale = UIScreen.main.scale
            $0.mask = innerCutoutMaskLayer
            innerCutoutMaskLayer.fillRule = .evenOdd
        }
        blurBackdropLayer.map {
            addSublayer($0)
            $0.rasterizationScale = UIScreen.main.scale
            $0.filters = [
                createCAFilter("variableBlur").map {
                    $0.setValue("blur", forKey: "name")
                    $0.setValue(blurRadius, forKey: "inputRadius")
                    $0.setValue(true, forKey: "inputNormalizeEdges")
                    return $0
                } as Any
            ]
        }
        mask = clippingMaskLayer
    }

    public required override init(layer: Any) {
        super.init(layer: layer)
        if let layer = layer as? EdgeMirrorLayer {
            self.mirroringZoneWidth = layer.mirroringZoneWidth
            self.visibleWidth = layer.visibleWidth
            self.blurRadius = layer.blurRadius
            self.blurTransitionWidth = layer.blurTransitionWidth
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    public override func layoutSublayers() {
        super.layoutSublayers()
        mirrorBackdropLayer?.position = .init(x: bounds.midX, y: bounds.midY)
        mirrorBackdropLayer?.bounds.size = bounds.size
        blurBackdropLayer?.position = .init(x: bounds.midX, y: bounds.midY)
        blurBackdropLayer?.bounds.size = bounds.size
        [clippingMaskLayer, innerCutoutMaskLayer].forEach {
            $0.position = .init(x: bounds.midX, y: bounds.midY)
            $0.bounds.size = bounds.size
        }
        if acceptedBoundsSize != bounds.size || shouldUpdateBlurMask {
            updateClippingMasks()
            updateMesh()
            let maskImage = UIImage.generateVariableBlurMask(
                size: bounds.size,
                cornerRadius: cornerRadius,
                transitionWidth: blurTransitionWidth
            ).cgImage
            blurBackdropLayer?.setValue(maskImage, forKeyPath: "filters.blur.inputMaskImage")
            innerCutoutMaskLayer.contents = maskImage
            shouldUpdateBlurMask = false
        }
        acceptedBoundsSize = bounds.size
    }

    // MARK: - Private Properties

    private let blurBackdropLayer = createCABackdropLayer()
    private let mirrorBackdropLayer = createCABackdropLayer()
    private let clippingMaskLayer = CAShapeLayer()
    private let innerCutoutMaskLayer = CAShapeLayer()

    private var acceptedBoundsSize: CGSize?
    private var shouldUpdateBlurMask = true
    
}

fileprivate extension EdgeMirrorLayer {

    // MARK: - Private Nested

    enum Static {
        static let сornerSteps = 4
        static let stepWidth = (.pi / 2.0) / CGFloat(сornerSteps + 1)
        static let coss = (0..<сornerSteps).map { cos(CGFloat($0) * stepWidth) }
        static let sins = (0..<сornerSteps).map { sin(CGFloat($0) * stepWidth) }
    }
    
    // MARK: - Private Methods

    func updateClippingMasks() {
        clippingMaskLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }

    func updateMesh() {
        guard bounds.width > 0.0 && bounds.height > 0.0 else { return }
        var verticesBuffer: [CAMeshVertex] = []
        var facesBuffer: [CAMeshFace] = []

        verticesBuffer.reserveCapacity(48)
        facesBuffer.reserveCapacity(24)

        for i in (1...Static.сornerSteps) {
            let angleCos = Static.coss[i - 1]
            let angleSin = Static.sins[i - 1]
            verticesBuffer.append(contentsOf: [
                .init(
                    from: .init(
                        x: cornerRadius - (cornerRadius * angleCos),
                        y: cornerRadius - (cornerRadius * angleSin)
                    ),
                    to: .init(
                        x: cornerRadius - ((cornerRadius - mirroringZoneWidth) * angleCos),
                        y: cornerRadius - ((cornerRadius - mirroringZoneWidth) * angleSin),
                        z: 1.0
                    )
                )
            ])
        }

        let leftVertex = CAMeshVertex(
            from: .init(x: 0.0, y: cornerRadius),
            to: .init(x: mirroringZoneWidth, y: cornerRadius, z: 1.0)
        )
        let rightVertex = CAMeshVertex(
            from: .init(x: bounds.width, y: cornerRadius),
            to: .init(x: bounds.width - mirroringZoneWidth, y: cornerRadius, z: 1.0)
        )
        let topVertex = CAMeshVertex(
            from: .init(x: cornerRadius, y: 0.0),
            to: .init(x: cornerRadius, y: mirroringZoneWidth, z: 1.0)
        )
        if bounds.height > cornerRadius * 2.0 {
            verticesBuffer.insert(leftVertex, at: 0)
        }
        if bounds.width > cornerRadius * 2.0 {
            verticesBuffer.append(topVertex)
            verticesBuffer.append(contentsOf: verticesBuffer.reversed().mirroringX(width: bounds.width))
        } else {
            verticesBuffer.append(contentsOf: [topVertex] + verticesBuffer.reversed().mirroringX(width: bounds.width))
        }
        if bounds.height > cornerRadius * 2.0 {
            verticesBuffer.append(contentsOf: verticesBuffer.reversed().mirroringY(height: bounds.height))
        } else {
            verticesBuffer.append(contentsOf: [rightVertex] + verticesBuffer.reversed().mirroringY(height: bounds.height))
            verticesBuffer.insert(leftVertex, at: 0)
        }

        verticesBuffer.append(contentsOf: verticesBuffer.antagonists())
        verticesBuffer.normalize(size: bounds.size)

        let rowSize = verticesBuffer.count / 2
        for i in (0..<rowSize) {
            let topL = UInt32(i)
            let topR = UInt32((i + 1) % rowSize)
            let bottomL = UInt32(rowSize + i)
            let bottomR = UInt32(rowSize + ((i + 1) % rowSize))
            facesBuffer.append(.init(
                indices: (topL, topR, bottomR, bottomL),
                w: (1.0, 1.0, 1.0, 1.0)
            ))
        }

        let mesh = createCAMutableMeshTransform(
            UInt(verticesBuffer.count),
            &verticesBuffer,
            UInt(facesBuffer.count),
            &facesBuffer,
            kCADepthNormalizationAverage
        )
        mesh?.setSubdivisionSteps(0)
        mirrorBackdropLayer?.setValue(mesh, forKey: "meshTransform")
    }

}

fileprivate extension UIImage {

    static func generateVariableBlurMask(
        size: CGSize,
        cornerRadius: CGFloat,
        transitionWidth: CGFloat
    ) -> UIImage {
        let r = min(cornerRadius, min(size.width, size.height) / 2.0)
        let patchSize = CGSize(width: r * 2.0 + 1.0, height: r * 2.0 + 1.0)
        let patchRenderer = UIGraphicsImageRenderer(size: patchSize)
        let patchImage = patchRenderer.image { context in
            let cgContext = context.cgContext
            let center = CGPoint(x: r, y: r)
            let w = min(transitionWidth, r)
            let innerColor = UIColor.white.withAlphaComponent(0.0).cgColor
            let outerColor = UIColor.white.withAlphaComponent(1.0).cgColor
            let colors = [innerColor, outerColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else { return }
            cgContext.drawRadialGradient(
                gradient,
                startCenter: center, startRadius: r - w,
                endCenter: center, endRadius: r,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
        let insets = UIEdgeInsets(top: r, left: r, bottom: r, right: r)
        let resizableImage = patchImage.resizableImage(withCapInsets: insets, resizingMode: .stretch)
        return UIGraphicsImageRenderer(size: size).image { _ in
            resizableImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }

}

fileprivate extension Array where Element == CAMeshVertex {

    mutating func normalize(size: CGSize) {
        for i in (0..<count) {
            self[i].from.x /= size.width
            self[i].from.y /= size.height
            self[i].to.x /= size.width
            self[i].to.y /= size.height
        }
    }
    
    func antagonists() -> [CAMeshVertex] {
        map {
            .init(
                from: .init(x: $0.to.x, y: $0.to.y),
                to: .init(x: $0.from.x, y: $0.from.y, z: 1.0)
            )
        }
    }

    func mirroringX(width: CGFloat) -> [CAMeshVertex] {
        map {
            .init(
                from: .init(x: width - $0.from.x, y: $0.from.y),
                to: .init(x: width - $0.to.x, y: $0.to.y, z: $0.to.z)
            )
        }
    }
    
    func mirroringY(height: CGFloat) -> [CAMeshVertex] {
        map {
            .init(
                from: .init(x: $0.from.x, y: height - $0.from.y),
                to: .init(x: $0.to.x, y: height - $0.to.y, z: $0.to.z)
            )
        }
    }
    
}
