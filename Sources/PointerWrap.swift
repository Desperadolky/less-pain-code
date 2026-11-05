import CoreGraphics

struct PointerWrap {
    private enum Edge { case left, right }

    private let left: CGRect
    private let right: CGRect
    private var edge: Edge?
    private var outwardDistance: CGFloat = 0
    private var lastPush: Double = 0

    init?(frames: [CGRect]) {
        guard let left = frames.min(by: { $0.minX < $1.minX }),
              let right = frames.max(by: { $0.maxX < $1.maxX }),
              left.maxX <= right.minX else { return nil }
        self.left = left
        self.right = right
    }

    mutating func reset() {
        edge = nil
        outwardDistance = 0
    }

    mutating func destination(at point: CGPoint, dx: CGFloat, dy: CGFloat, time: Double) -> CGPoint? {
        let pushing: Edge
        if abs(dx) < abs(dy) {
            reset()
            return nil
        } else if dx < 0, abs(point.x - left.minX) <= 1, point.y >= left.minY, point.y < left.maxY {
            pushing = .left
        } else if dx > 0, abs(point.x - right.maxX) <= 1, point.y >= right.minY, point.y < right.maxY {
            pushing = .right
        } else {
            reset()
            return nil
        }

        defer { lastPush = time }
        guard pushing == edge, time - lastPush <= 0.25 else {
            // Touching the edge only arms it. The next outward movement can wrap.
            edge = pushing
            outwardDistance = 0
            return nil
        }
        outwardDistance += abs(dx)
        guard outwardDistance >= 6 else { return nil }
        reset()

        let target = pushing == .left ? right : left
        let inset: CGFloat = 8
        let x = pushing == .left ? target.maxX - inset : target.minX + inset
        let y = max(target.minY + inset, min(point.y, target.maxY - inset))
        return CGPoint(x: x, y: y)
    }
}
