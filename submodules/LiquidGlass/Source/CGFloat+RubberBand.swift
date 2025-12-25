import CoreGraphics

extension CGFloat {

    func rubberBanded(in range: ClosedRange<CGFloat>, limit: CGFloat, stiffness: CGFloat = 0.5) -> CGFloat {
        guard !range.contains(self) else { return self }
        let delta = self > range.upperBound ? self - range.upperBound : range.lowerBound - self
        let boundary = self > range.upperBound ? range.upperBound : range.lowerBound
        let sign: CGFloat = self > range.upperBound ? 1 : -1
        if limit <= 0 { return boundary }
        let p = stiffness
        let base = 1.0 + (delta / (limit * p))
        let rubberDistance = limit * (1.0 - pow(base, -p))
        return boundary + (sign * rubberDistance)
    }

}
