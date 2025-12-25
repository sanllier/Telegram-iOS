import UIKit

final class LGGestureRecognizer: UILongPressGestureRecognizer {

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        minimumPressDuration = 0.0
        allowableMovement = .infinity
        cancelsTouchesInView = false
        delegate = self
    }

}

extension LGGestureRecognizer: UIGestureRecognizerDelegate {

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return !(otherGestureRecognizer is UIPanGestureRecognizer)
    }

}
