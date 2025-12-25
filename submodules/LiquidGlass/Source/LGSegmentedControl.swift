import UIKit
import LegacyComponents
import ComponentFlow

public final class LGSegmentedControl: UIView {

    // MARK: - Public Nested

    public struct Item {
        public var title: String

        public init(title: String) {
            self.title = title
        }
    }

    // MARK: - Public Properties

    public override var backgroundColor: UIColor? { didSet { shouldApplySystemBackgroundColor = false } }
    public var foregroundColor: UIColor? { didSet { repaint() } }
    public var selectedIndexChanged: ((Int) -> Void)?

    // MARK: - Constructors

    public init(frame: CGRect, items: [Item], initialSelectedSegmentIndex: Int?) {
        self.itemsViews = items.map {
            let obj = ItemView(frame: .zero)
            obj.title = $0.title
            return obj
        }
        super.init(frame: frame)
        addSubview(selectionView)
        selectionLensView.shouldAnimateSpeed = true
        selectionLensView.onSelectionProgressChanged = { [weak self] in
            self?.selectionView.alpha = 1.0 - $0
            self?.selectionLensEffectsLayer.opacity = Float($0)
        }
        selectionLensView.onScaleTransformChanged = { [weak self] in
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let transform = CATransform3DMakeScale($0.width, $0.height, 1.0)
            self?.selectionLensEffectsLayer.transform = transform
            CATransaction.commit()
            self?.selectionView.transform = .init(scaleX: $0.width, y: $0.height)
        }
        addSubview(selectionLensView)
        addSubview(itemsContainer)
        selectionLensEffectsLayer.opacity = 0.0
        layer.addSublayer(selectionLensEffectsLayer)
        selectionLensEffectsLayer.effectsProperties = LGLayer.LensProperties.clear().updating {
            $0.effectsProperties?.mirroringZoneWidth = 5.0
            $0.effectsProperties?.visibleMirrorWidth = 3.0
            $0.effectsProperties?.mirrorBlurTransitionWidth = 3.0
            $0.effectsProperties?.mirrorBlurRadius = 4.0
        }.effectsProperties
        itemsViews.forEach(itemsContainer.addSubview)
        addGestureRecognizer(longPressRecognizer)
        if !items.isEmpty {
            if let initialSelectedSegmentIndex, initialSelectedSegmentIndex < items.count {
                selectedSegmentIndex = initialSelectedSegmentIndex
            } else {
                selectedSegmentIndex = 0
            }
        }
        setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 14.0, weight: .semibold),
            .foregroundColor: UIColor.label
        ])
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

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let paddings = Static.itemPadding * CGFloat(itemsViews.count) * 2.0
        let insets = Static.itemInset * CGFloat(itemsViews.count) * 2.0
        let desiredHeight = min(size.height, 36.0)
        let maxItemWidth = itemsViews
            .map { $0.sizeThatFits(.init(width: .greatestFiniteMagnitude, height: desiredHeight)).width }
            .max() ?? 0.0
        let desiredWidth = maxItemWidth * CGFloat(itemsViews.count) + paddings + insets
        return .init(width: min(desiredWidth, size.width), height: desiredHeight)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard lastAcceptedBounds != bounds else { return }
        lastAcceptedBounds = bounds
        layer.cornerRadius = min(bounds.width, bounds.height) / 2.0
        itemsContainer.frame = bounds
        if itemsViews.count > 0 {
            let paddings = Static.itemPadding * CGFloat(itemsViews.count) * 2.0
            let itemWidth = (bounds.width - paddings) / CGFloat(itemsViews.count)
            let itemHeight = bounds.height - 2.0 * Static.itemPadding
            itemsViews.enumerated().forEach { index, view in
                view.frame = CGRect(
                    x: (CGFloat(index) * (itemWidth + 2.0 * Static.itemPadding)) + Static.itemPadding,
                    y: Static.itemPadding,
                    width: itemWidth,
                    height: itemHeight
                )
            }
        }
        if let selectedSegmentIndex, selectedSegmentIndex < itemsViews.count {
            updateSelectionLayout(frame: itemsViews[selectedSegmentIndex].frame, transition: .immediate)
        } else {
            assert(false)
        }
    }

    public func setTitleTextAttributes(_ attributes: [NSAttributedString.Key : Any]?) {
        itemsViews.forEach { $0.titleTextAttributes = attributes }
    }

    // MARK: - Private Properties

    private let selectionView = UIView(frame: .zero)
    private let selectionLensView = LGControlThumbView(
        baseLensProperties: .clear().updating {
            $0.effectsProperties = nil
        },
        magnification: (deselected: 1.0, selected: 0.8),
        selectionScale: .init(width: 1.12, height: 1.2),
        valocityScaleRangeWidth: 0.25,
        deselectedShadowRequired: false,
        deselectionMode: .disappearing
    )
    private let selectionLensEffectsLayer = LGLensEffectsLayer()

    private let itemsViews: [ItemView]
    private let itemsContainer = UIView(frame: .zero)

    private lazy var longPressRecognizer = LGGestureRecognizer(target: self, action: #selector(onLongPress(_:)))

    private var shouldApplySystemBackgroundColor = true
    private var lastAcceptedBounds: CGRect?
    private var selectedSegmentIndex: Int?

}

fileprivate extension LGSegmentedControl {
    
    // MARK: - Private Nested

    enum Static {
        static let containerExtension = 50.0
        static let itemPadding = 2.0
        static let itemInset = 8.0
    }

    final class ItemView: UIView {
        var title: String = "" { didSet { updateTitle() } }
        var titleTextAttributes: [NSAttributedString.Key : Any]? { didSet { updateTitle() } }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            titleView.textAlignment = .center
            addSubview(titleView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func sizeThatFits(_ size: CGSize) -> CGSize {
            return titleView.sizeThatFits(size)
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            titleView.frame = bounds.insetBy(dx: Static.itemInset, dy: 0.0)
        }
        
        private let titleView = UILabel(frame: .zero)
        
        private func updateTitle() {
            titleView.attributedText = NSAttributedString(string: title, attributes: titleTextAttributes)
        }
        
    }
    
    // MARK: - Private Methods

    @objc func onLongPress(_ sender: UILongPressGestureRecognizer) {
        let transition = ComponentTransition(animation: .curve(duration: 0.32, curve: .spring))
        switch sender.state {
        case .began:
            selectionLensView.setSelected(true)
            let point = sender.location(in: self)
            if let closestItemView = getClosestItemView(to: point) {
                updateSelectionLayout(frame: closestItemView.frame, transition: transition)
            }
        case .changed:
            let touchLocation = sender.location(in: self)
            let maxXOrigin = bounds.width - selectionLensView.bounds.width - Static.itemPadding
            let clampedXOrigin = min(max(Static.itemPadding, touchLocation.x - selectionLensView.bounds.width / 2.0), maxXOrigin)
            let targetFrame = CGRect(
                x: clampedXOrigin,
                y: Static.itemPadding,
                width: selectionLensView.frame.size.width,
                height: selectionLensView.frame.size.height
            )
            updateSelectionLayout(frame: targetFrame, transition: transition)
        case .ended, .cancelled, .failed:
            selectionLensView.setSelected(false)
            let point = sender.location(in: self)
            if let closestItemView = getClosestItemView(to: point) {
                updateSelectionLayout(frame: closestItemView.frame, transition: transition)
                if let itemIndex = itemsViews.firstIndex(where: { $0 === closestItemView }) {
                    if selectedSegmentIndex != itemIndex {
                        selectedSegmentIndex = itemIndex
                        selectedIndexChanged?(itemIndex)
                    }
                } else {
                    assert(false)
                }
            }
        default:
            break
        }
    }

    func getClosestItemView(to point: CGPoint) -> UIView? {
        var closestItemView: (UIView, CGFloat)?
        for itemView in itemsViews {
            let distance = abs(point.x - itemView.center.x)
            if let previousClosestItemView = closestItemView {
                if previousClosestItemView.1 > distance {
                    closestItemView = (itemView, distance)
                }
            } else {
                closestItemView = (itemView, distance)
            }
        }
        return closestItemView?.0
    }

    func updateSelectionLayout(frame: CGRect, transition: ComponentTransition) {
        let cornerRadius = min(frame.width, frame.height) * 0.5
        transition.setPosition(view: selectionView, position: .init(x: frame.midX, y: frame.midY))
        transition.setBounds(view: selectionView, bounds: .init(origin: .zero, size: frame.size))
        transition.setCornerRadius(layer: selectionView.layer, cornerRadius: cornerRadius)
        transition.setFrame(view: selectionLensView, frame: frame)
        transition.setPosition(layer: selectionLensEffectsLayer, position: selectionView.center)
        transition.setBounds(layer: selectionLensEffectsLayer, bounds: .init(origin: .zero, size: selectionView.bounds.size))
        transition.setCornerRadius(layer: selectionLensEffectsLayer, cornerRadius: cornerRadius)
    }

    func repaint() {
        if shouldApplySystemBackgroundColor {
            switch traitCollection.userInterfaceStyle {
            case .dark: backgroundColor = .init(red: 0.11, green: 0.11, blue: 0.11, alpha: 1.0)
            default: backgroundColor = .init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.06)
            }
            shouldApplySystemBackgroundColor = true
        }
        if let foregroundColor {
            selectionView.backgroundColor = foregroundColor
        } else {
            switch traitCollection.userInterfaceStyle {
            case .dark: selectionView.backgroundColor = .init(red: 0.44, green: 0.44, blue: 0.46, alpha: 1.0)
            default: selectionView.backgroundColor = .init(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
            }
        }
    }

}
