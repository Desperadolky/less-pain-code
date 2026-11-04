import CoreGraphics
import Foundation

struct DisplaySpaces {
    let id: CGDirectDisplayID
    let name: String
    let spaces: [UInt64]
    let active: UInt64
}

struct SpacePosition: Hashable {
    let display: CGDirectDisplayID
    let space: UInt64
}

struct SpaceCycle {
    let origin: CGDirectDisplayID
    let route: [SpacePosition]
    var current: SpacePosition
    private var lastDirection: Bool?

    init?(displays: [DisplaySpaces], origin: CGDirectDisplayID) {
        guard let screen = displays.first(where: { $0.id == origin }) else { return nil }
        self.origin = origin
        route = Self.route(for: displays)
        current = SpacePosition(display: origin, space: screen.active)
        guard route.contains(current) else { return nil }
    }

    func canContinue(with displays: [DisplaySpaces], origin: CGDirectDisplayID) -> Bool {
        self.origin == origin &&
        Set(route) == Set(Self.route(for: displays)) &&
        displays.first(where: { $0.id == current.display })?.active == current.space
    }

    func step(forward: Bool) -> SpacePosition {
        adjacent(to: current, forward: forward)
    }

    func target(forward: Bool, displays: [DisplaySpaces]) -> SpacePosition {
        let next = step(forward: forward)
        guard lastDirection == !forward,
              current.display != origin,
              next.display == origin,
              displays.first(where: { $0.id == origin })?.active == next.space else { return next }

        // When reversing back home, skip the desktop that is still on screen.
        let following = adjacent(to: next, forward: forward)
        return following.display == origin ? following : next
    }

    mutating func confirm(_ target: SpacePosition, forward: Bool) {
        current = target
        lastDirection = forward
    }

    private func adjacent(to position: SpacePosition, forward: Bool) -> SpacePosition {
        guard let index = route.firstIndex(of: position) else { return position }
        let offset = forward ? 1 : -1
        return route[(index + offset + route.count) % route.count]
    }

    func caption(in displays: [DisplaySpaces]) -> String? {
        guard let screenIndex = displays.firstIndex(where: { $0.id == current.display }) else { return nil }
        let screenRoute = route.filter { $0.display == current.display }
        guard let spaceIndex = screenRoute.firstIndex(of: current) else { return nil }
        let screen = screenIndex < 26 ? String(UnicodeScalar(65 + screenIndex)!) + " 屏" : "屏 \(screenIndex + 1)"
        return "\(screen) · \(spaceIndex + 1)/\(screenRoute.count)"
    }

    private static func route(for displays: [DisplaySpaces]) -> [SpacePosition] {
        displays.flatMap { screen in screen.spaces.map { SpacePosition(display: screen.id, space: $0) } }
    }
}
