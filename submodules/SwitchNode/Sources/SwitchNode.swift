import Foundation
import UIKit
import AsyncDisplayKit
import LiquidGlass

public protocol SwitchItem: UIControl {
    var tintColor: UIColor! { get set }
    var onTintColor: UIColor? { get set }
    var thumbTintColor: UIColor? { get set }
    var backgroundColor: UIColor? { get set }
    var isOn: Bool { get set }
    func setOn(_ value: Bool, animated: Bool)
}

extension UISwitch: SwitchItem {}
extension LGSwitch: SwitchItem {}

open class SwitchNode: ASDisplayNode {
    public var valueUpdated: ((Bool) -> Void)?
    
    public var frameColor = UIColor(rgb: 0xe0e0e0) {
        didSet {
            if self.isNodeLoaded {
                if oldValue != self.frameColor {
                    (self.view as! SwitchItem).tintColor = self.frameColor
                }
            }
        }
    }
    public var handleColor = UIColor(rgb: 0xffffff) {
        didSet {
            if self.isNodeLoaded {
                //(self.view as! SwitchItem).thumbTintColor = self.handleColor
            }
        }
    }
    public var contentColor = UIColor(rgb: 0x42d451) {
        didSet {
            if self.isNodeLoaded {
                if oldValue != self.contentColor {
                    (self.view as! SwitchItem).onTintColor = self.contentColor
                }
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
                    (self.view as! SwitchItem).setOn(value, animated: false)
                }
            }
        }
    }

    override public init() {
        super.init()

        self.setViewBlock({
            if #available(iOS 26.0, *) {
                return UISwitch(frame: .zero)
            } else {
                return LGSwitch(frame: .zero)
            }
        })
    }

    override open func didLoad() {
        super.didLoad()
        
        self.view.isAccessibilityElement = false
        
        (self.view as! SwitchItem).backgroundColor = self.backgroundColor
        (self.view as! SwitchItem).tintColor = self.frameColor
        (self.view as! SwitchItem).onTintColor = self.contentColor

        (self.view as? LGSwitch)?.disablesInteractiveTransitionGestureRecognizer = true

        (self.view as! SwitchItem).setOn(self._isOn, animated: false)
        
        (self.view as! SwitchItem).addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
    }
    
    public func setOn(_ value: Bool, animated: Bool) {
        self._isOn = value
        if self.isNodeLoaded {
            (self.view as! SwitchItem).setOn(value, animated: animated)
        }
    }
    
    override open func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 63.0, height: 28.0)
    }
    
    @objc func switchValueChanged(_ view: UIControl) {
        guard let view = view as? SwitchItem else { assert(false); return }
        self._isOn = view.isOn
        self.valueUpdated?(view.isOn)
    }
}
