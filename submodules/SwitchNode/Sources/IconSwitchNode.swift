import Foundation
import Display
import UIKit
import AsyncDisplayKit
import LiquidGlass

import LegacyComponents

public protocol IconSwitchItem: SwitchItem {
    func setPositiveContentColor(_ color: UIColor!)
    func setNegativeContentColor(_ color: UIColor!)
    func updateIsLocked(_ isLocked: Bool)
}

extension LGSwitch: IconSwitchItem {
    public func setPositiveContentColor(_ color: UIColor!) {
        onTintColor = color
    }
    public func setNegativeContentColor(_ color: UIColor!) {
        tintColor = color
    }
    public func updateIsLocked(_ isLocked: Bool) {
        icon = (
            positive: TGComponentsImageNamed("PermissionSwitchOn.png"),
            negative: TGComponentsImageNamed(isLocked ? "Item List/SwitchLockIcon" : "PermissionSwitchOff.png")
        )
    }
}

private final class IconSwitchNodeViewLayer: CALayer {
    override func setNeedsDisplay() {
    }
}

private final class IconSwitchNodeView: TGIconSwitchView, IconSwitchItem {
    override class var layerClass: AnyClass {
        return IconSwitchNodeViewLayer.self
    }
}

open class IconSwitchNode: ASDisplayNode {
    public var valueUpdated: ((Bool) -> Void)?
    
    public var frameColor = UIColor(rgb: 0xe0e0e0) {
        didSet {
            if self.isNodeLoaded {
                (self.view as! IconSwitchItem).tintColor = self.frameColor
            }
        }
    }
    public var handleColor = UIColor(rgb: 0xffffff) {
        didSet {
            if self.isNodeLoaded {
                //(self.view as! IconSwitchItem).thumbTintColor = self.handleColor
            }
        }
    }
    public var contentColor = UIColor(rgb: 0x42d451) {
        didSet {
            if self.isNodeLoaded {
                (self.view as! IconSwitchItem).onTintColor = self.contentColor
            }
        }
    }
    public var positiveContentColor = UIColor(rgb: 0x00ff00) {
        didSet {
            if self.isNodeLoaded {
                (self.view as! IconSwitchItem).setPositiveContentColor(self.positiveContentColor)
            }
        }
    }
    public var negativeContentColor = UIColor(rgb: 0xff0000) {
        didSet {
            if self.isNodeLoaded {
                (self.view as! IconSwitchItem).setNegativeContentColor(self.negativeContentColor)
            }
        }
    }
    
    private var _isOn: Bool = false
    public var isOn: Bool {
        get {
            return self._isOn
        } set(value) {
            if (value != self._isOn) {
                self._isOn = value
                if self.isNodeLoaded {
                    (self.view as! IconSwitchItem).setOn(value, animated: false)
                }
            }
        }
    }
    
    private var _isLocked: Bool = false
    
    override public init() {
        super.init()
        
        self.setViewBlock({
            if #available(iOS 26.0, *) {
                return IconSwitchNodeView()
            } else {
                return LGSwitch(frame: .zero)
            }
        })
    }
    
    override open func didLoad() {
        super.didLoad()
        
        (self.view as! IconSwitchItem).backgroundColor = self.backgroundColor
        (self.view as! IconSwitchItem).tintColor = self.frameColor
        (self.view as! IconSwitchItem).onTintColor = self.contentColor
        (self.view as? IconSwitchItem)?.updateIsLocked(self._isLocked)
        (self.view as! IconSwitchItem).setNegativeContentColor(self.negativeContentColor)
        (self.view as! IconSwitchItem).setPositiveContentColor(self.positiveContentColor)

        (self.view as? LGSwitch)?.disablesInteractiveTransitionGestureRecognizer = true

        (self.view as! IconSwitchItem).setOn(self._isOn, animated: false)
        
        (self.view as! IconSwitchItem).addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
    }
    
    public func setOn(_ value: Bool, animated: Bool) {
        self._isOn = value
        if self.isNodeLoaded {
            (self.view as! IconSwitchItem).setOn(value, animated: animated)
        }
    }
    
    public func updateIsLocked(_ value: Bool) {
        if self._isLocked == value {
            return
        }
        self._isLocked = value
        if self.isNodeLoaded {
            (self.view as? IconSwitchItem)?.updateIsLocked(value)
        }
    }
    
    override open func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 63.0, height: 28.0)
    }

    @objc func switchValueChanged(_ view: UIControl) {
        guard let view = view as? IconSwitchItem else { assert(false); return }
        self.valueUpdated?(view.isOn)
    }
}
