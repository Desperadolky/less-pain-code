import CoreGraphics

@main
struct SpaceCycleCheck {
    static func main() {
        let screens: [DisplaySpaces] = [
            .init(id: 10, name: "A", spaces: [101, 102, 103], active: 101),
            .init(id: 20, name: "B", spaces: [201, 202], active: 202),
            .init(id: 30, name: "C", spaces: [301, 302], active: 301)
        ]
        func steps(start: CGDirectDisplayID, forward: Bool, count: Int, in screens: [DisplaySpaces]) -> [UInt64] {
            var cycle = SpaceCycle(displays: screens, origin: start)!
            return (0..<count).map { _ in
                cycle.current = cycle.step(forward: forward)
                return cycle.current.space
            }
        }

        precondition(steps(start: 10, forward: true, count: 7, in: screens) == [102, 103, 201, 202, 301, 302, 101])
        precondition(steps(start: 10, forward: false, count: 7, in: screens) == [302, 301, 202, 201, 103, 102, 101])
        precondition(steps(start: 20, forward: true, count: 7, in: screens) == [301, 302, 101, 102, 103, 201, 202])
        var cycle = SpaceCycle(displays: screens, origin: 10)!
        cycle.current = SpacePosition(display: 20, space: 202)
        precondition(cycle.caption(in: screens) == "B 屏 · 2/2")
        precondition(cycle.canContinue(with: screens, origin: 10))
        precondition(!cycle.canContinue(with: screens, origin: 20))
        precondition(!cycle.canContinue(with: Array(screens.dropLast()), origin: 10))
        var reordered = screens
        reordered[1] = .init(id: 20, name: "B", spaces: [202, 201], active: 202)
        precondition(cycle.canContinue(with: reordered, origin: 10))
        precondition(cycle.step(forward: true).space == 301)
        reordered[1] = .init(id: 20, name: "B", spaces: [202, 201], active: 201)
        precondition(!cycle.canContinue(with: reordered, origin: 10))

        var atBoundary = screens
        atBoundary[2] = .init(id: 30, name: "C", spaces: [301, 302], active: 302)
        var fromC = SpaceCycle(displays: atBoundary, origin: 30)!
        let aFirst = SpacePosition(display: 10, space: 101)
        let cPrevious = SpacePosition(display: 30, space: 301)
        precondition(fromC.target(forward: true, displays: atBoundary) == aFirst)
        fromC.confirm(aFirst, forward: true)
        precondition(fromC.target(forward: false, displays: atBoundary) == cPrevious)
        precondition(fromC.target(forward: true, displays: atBoundary).space == 102)
        precondition(fromC.target(forward: false, displays: screens).space == 302)

        atBoundary[2] = .init(id: 30, name: "C", spaces: [302], active: 302)
        var oneSpace = SpaceCycle(displays: atBoundary, origin: 30)!
        oneSpace.confirm(aFirst, forward: true)
        precondition(oneSpace.target(forward: false, displays: atBoundary).space == 302)
        print("PASS: forward/reverse wrap, B origin, caption, topology, reorder and C boundary reversal")
        checkPointerWrap()
    }

    private static func checkPointerWrap() {
        let a = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let b = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        let c = CGRect(x: 3432, y: 0, width: 1920, height: 1080)
        var wrap = PointerWrap(frames: [b, c, a])!
        let aLeft = CGPoint(x: 0, y: 400)
        let cRight = CGPoint(x: 5351.5, y: 1050)
        precondition(wrap.destination(at: aLeft, dx: -12, dy: 0, time: 1) == nil)
        precondition(wrap.destination(at: aLeft, dx: -3, dy: 0, time: 1.01) == nil)
        precondition(wrap.destination(at: aLeft, dx: -3, dy: 0, time: 1.02) == CGPoint(x: 5344, y: 400))
        precondition(wrap.destination(at: cRight, dx: 9, dy: 0, time: 2) == nil)
        precondition(wrap.destination(at: cRight, dx: 9, dy: 0, time: 2.01) == CGPoint(x: 8, y: 974))
        precondition(wrap.destination(at: aLeft, dx: -9, dy: 0, time: 3) == nil)
        precondition(wrap.destination(at: aLeft, dx: -9, dy: 0, time: 3.5) == nil)
        precondition(wrap.destination(at: aLeft, dx: 9, dy: 0, time: 3.51) == nil)
        precondition(wrap.destination(at: aLeft, dx: -9, dy: 0, time: 3.52) == nil)
        for time in [4.0, 4.01] {
            precondition(wrap.destination(at: CGPoint(x: 1511, y: 400), dx: 9, dy: 0, time: time) == nil)
        }
        precondition(PointerWrap(frames: [a]) == nil)
        precondition(PointerWrap(frames: [a, a.offsetBy(dx: 0, dy: 982)]) == nil)
        print("PASS: pointer wrapping in both directions, edge intent, middle boundary and single/vertical layouts")
    }
}
