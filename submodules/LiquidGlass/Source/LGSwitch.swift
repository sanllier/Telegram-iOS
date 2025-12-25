import UIKit
import LegacyComponents

public final class LGSwitch: UIControl {

    // MARK: - Public Properties

    public override var intrinsicContentSize: CGSize { .init(width: 63.0, height: 28.0) }

    public override var tintColor: UIColor! { didSet { repaint() } }
    public var onTintColor: UIColor? = .systemGreen { didSet { repaint() } }
    public var thumbTintColor: UIColor? {
        get { thumbView.tintColor }
        set { thumbView.tintColor = newValue }
    }
    public var icon: (positive: UIImage?, negative: UIImage?)? { didSet {
        updateIcon()
        switchIcon(animated: false)
    }}
    public var positiveIconTintColor: UIColor? { didSet { positiveIconView?.tintColor = positiveIconTintColor } }
    public var negativeIconTintColor: UIColor? { didSet { negativeIconView?.tintColor = negativeIconTintColor } }
    public var isOn: Bool {
        get { _isOn }
        set { setOn(newValue, animated: false) }
    }

    // MARK: - Constructors

    public override init(frame: CGRect) {
        super.init(frame: frame)
        layer.masksToBounds = false
        tintColor = .tertiaryLabel
        backgroundLayer.masksToBounds = true
        backgroundLayer.cornerRadius = intrinsicContentSize.height / 2.0
        backgroundLayer.anchorPoint = .zero
        backgroundLayer.position = .zero
        backgroundLayer.bounds.size = intrinsicContentSize
        layer.addSublayer(backgroundLayer)
        thumbView.bounds.size = .init(
            width: Static.thumbWidth,
            height: intrinsicContentSize.height - 2.0 * Static.thumbMargin
        )
        thumbView.frame.origin = targetThumbPosition()
        addSubview(thumbView)
        addGestureRecognizer(longPressRecognizer)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        intrinsicContentSize
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        repaint()
        updateIcon()
    }

    public func setOn(_ value: Bool, animated: Bool) {
        _isOn = value
        if animated {
            animateThumbPositionX(to: targetThumbPosition().x, withBounciness: false)
            repaint()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            thumbView.frame.origin = targetThumbPosition()
            repaint()
            CATransaction.commit()
        }
        switchIcon(animated: animated)
    }

    // MARK: - Private Properties

    private var _isOn = false

    private let backgroundLayer = CALayer()
    private let thumbView = LGControlThumbView(
        baseLensProperties: .clear().updating {
            $0.effectsProperties?.mirroringZoneWidth = 2.0
            $0.effectsProperties?.visibleMirrorWidth = 1.0
            $0.effectsProperties?.mirrorBlurTransitionWidth = 1.0
            $0.effectsProperties?.mirrorBlurRadius = 3.0
        },
        magnification: (deselected: 1.5, selected: 0.85),
        selectionScale: .init(width: 1.6, height: 1.6),
        valocityScaleRangeWidth: 0.3,
        deselectedShadowRequired: false,
        deselectionMode: .tinting
    )
    private var positiveIconView: UIImageView?
    private var negativeIconView: UIImageView?

    private var stagedIsOn: Bool? { didSet {
        if let stagedIsOn, oldValue != stagedIsOn {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        repaint()
    }}

    private lazy var longPressRecognizer = LGGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
    private var trackingTouchContext: TouchContext? { didSet {
        thumbView.shouldAnimateSpeed = trackingTouchContext != nil
        if (oldValue == nil) != (trackingTouchContext == nil) {
            thumbView.setSelected(trackingTouchContext != nil)
        }
        if (oldValue != nil) && (trackingTouchContext == nil) {
            animateThumbPositionX(to: targetThumbPosition().x, withBounciness: true)
        }
        if let stagedIsOn {
            self.stagedIsOn = nil
            if _isOn != stagedIsOn {
                _isOn = stagedIsOn
                sendActions(for: .valueChanged)
            }
            repaint()
            switchIcon(animated: false)
        }
    }}

    private lazy var positionXAnimatable = POPAnimatableProperty.property(
        withName: Static.positionXAnimatablePropName,
        initializer: { prop in
            guard let prop else { return }
            prop.readBlock = { obj, values in
                guard let slf = obj as? LGSwitch else { assert(false); return }
                guard let values else { return }
                values[0] = slf.thumbView.frame.origin.x
            }
            prop.writeBlock = { obj, values in
                guard let slf = obj as? LGSwitch else { assert(false); return }
                guard let values else { return }
                slf.thumbView.frame.origin.x = values[0]
            }
            prop.threshold = 0.1
        }
    ) as? POPAnimatableProperty

}

fileprivate extension LGSwitch {

    // MARK: - Private Nested

    enum Static {
        static let thumbMargin = 2.0
        static let thumbWidth = 37.0

        static let thumbSelectionProgressAnimatablePropName = "thumb_selection_progress"
        static let thumbSelectionProgressAnimation = "thumb_selection_progress"

        static let thumbXSpeedAnimatablePropName = "thumb_x_speed"
        static let thumbXSpeedAnimation = "thumb_x_speed"

        static let positionXAnimatablePropName = "position_x"
        static let positionXAnimation = "position_x"
    }

    struct TouchContext {
        var initialTouchLocation: CGPoint
        var initialThumbXPosition: CGFloat
    }

    // MARK: - Private Methods
    
    func targetThumbPosition() -> CGPoint {
        if stagedIsOn ?? _isOn {
            .init(
                x: intrinsicContentSize.width - thumbView.bounds.width - Static.thumbMargin,
                y: Static.thumbMargin,
            )
        } else {
            .init(x: Static.thumbMargin, y: Static.thumbMargin)
        }
    }

    func repaint() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.4)
        if stagedIsOn ?? _isOn {
            backgroundLayer.backgroundColor = onTintColor?.cgColor
        } else {
            backgroundLayer.backgroundColor = tintColor?.cgColor
        }
        CATransaction.commit()
    }

    func createIconImageView() -> UIImageView {
        let obj = UIImageView()
        obj.contentMode = .center
        thumbView.thumbFaderLayer.addSublayer(obj.layer)
        return obj
    }

    func updateIcon() {
        typealias Item = (
            imageViewPath: WritableKeyPath<LGSwitch, UIImageView?>,
            icon: UIImage?,
            tintColor: UIColor?
        )
        [
            (\.positiveIconView, icon?.positive, positiveIconTintColor),
            (\.negativeIconView, icon?.negative, negativeIconTintColor)
        ].forEach { (item: Item) in
            var mutSelf = self
            if let icon = item.icon {
                let imageView: UIImageView
                if let existingView = mutSelf[keyPath: item.imageViewPath] {
                    imageView = existingView
                } else {
                    imageView = createIconImageView()
                    imageView.tintColor = item.tintColor
                    mutSelf[keyPath: item.imageViewPath] = imageView
                }
                imageView.image = icon
            } else {
                mutSelf[keyPath: item.imageViewPath]?.image = nil
            }
        }
    }

    func switchIcon(animated: Bool) {
        let action = {
            self.positiveIconView?.alpha = self._isOn ? 1.0 : 0.0
            self.negativeIconView?.alpha = self._isOn ? 0.0 : 1.0
        }
        if animated {
            action()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            action()
            CATransaction.commit()
        }
    }

    @objc func onLongPress(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            pop_removeAnimation(forKey: Static.positionXAnimation)
            trackingTouchContext = .init(
                initialTouchLocation: sender.location(in: self),
                initialThumbXPosition: thumbView.frame.origin.x
            )
        case .changed:
            guard let trackingTouchContext else { assert(false); return }
            let currentTouchLocation = longPressRecognizer.location(in: self)
            let touchXTranslation = currentTouchLocation.x - trackingTouchContext.initialTouchLocation.x
            let desiredXPosition = trackingTouchContext.initialThumbXPosition + touchXTranslation
            let clampedXPosition = desiredXPosition.rubberBanded(
                in: (0.0...(intrinsicContentSize.width - thumbView.bounds.width - Static.thumbMargin)),
                limit: 15.0,
                stiffness: 0.2
            )
            animateThumbPositionX(to: clampedXPosition, withBounciness: false)
            let shouldBeIsOn: Bool
            if stagedIsOn ?? _isOn {
                shouldBeIsOn = desiredXPosition > 0.0
            } else {
                shouldBeIsOn = desiredXPosition >= (intrinsicContentSize.width - thumbView.bounds.width - Static.thumbMargin)
            }
            if stagedIsOn != nil || shouldBeIsOn != _isOn {
                stagedIsOn = shouldBeIsOn
            }
        case .ended:
            if stagedIsOn == nil {
                stagedIsOn = !_isOn
            }
            trackingTouchContext = nil
        case .cancelled, .failed:
            trackingTouchContext = nil
        default:
            break
        }
    }

    func animateThumbPositionX(to: CGFloat, withBounciness: Bool) {
        let springBounciness = withBounciness ? 6.0 : 0.0
        let springSpeed = withBounciness ? 16.0 : 20.0
        if let anim = pop_animation(forKey: Static.positionXAnimation) as? POPSpringAnimation {
            anim.toValue = to
            anim.springBounciness = springBounciness
            anim.springSpeed = springSpeed
        } else {
            guard let anim = POPSpringAnimation(propertyNamed: Static.positionXAnimatablePropName) else {
                assert(false)
                return
            }
            anim.fromValue = thumbView.frame.origin.x
            anim.toValue = to
            anim.springBounciness = springBounciness
            anim.springSpeed = springSpeed
            anim.property = positionXAnimatable
            pop_add(anim, forKey: Static.positionXAnimation)
        }
    }

}
