import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import OSLog

@MainActor
final class MacSpaces {
    private let log = Logger(subsystem: "io.github.desperadolky.qiping", category: "spaces")
    private typealias Connection = @convention(c) () -> UInt32
    private typealias CopySpaces = @convention(c) (UInt32) -> Unmanaged<CFArray>?

    // Read the current Space and order for each connected display.
    private let readManagedSpaces: (() -> [[String: Any]]?)? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let connectionSymbol = dlsym(handle, "CGSMainConnectionID"),
              let spacesSymbol = dlsym(handle, "CGSCopyManagedDisplaySpaces") else { return nil }
        let connect = unsafeBitCast(connectionSymbol, to: Connection.self)
        let copySpaces = unsafeBitCast(spacesSymbol, to: CopySpaces.self)
        return { copySpaces(connect())?.takeRetainedValue() as? [[String: Any]] }
    }()

    func displays() -> [DisplaySpaces]? {
        guard NSScreen.screensHaveSeparateSpaces, let rows = readManagedSpaces?() else { return nil }
        let screens = NSScreen.screens.sorted {
            if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
            return $0.frame.maxY > $1.frame.maxY
        }
        let displays: [DisplaySpaces] = screens.compactMap { screen in
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
            let displayKey = CFUUIDCreateString(nil, uuid) as String
            guard let row = rows.first(where: {
                guard let key = $0["Display Identifier"] as? String else { return false }
                return key.caseInsensitiveCompare(displayKey) == .orderedSame ||
                    (CGDisplayIsMain(id) != 0 && key == "Main")
            }), let entries = row["Spaces"] as? [[String: Any]],
                let active = (row["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? NSNumber else { return nil }
            let spaces = entries.compactMap { ($0["ManagedSpaceID"] as? NSNumber)?.uint64Value }
            guard spaces.count == entries.count,
                  spaces.contains(active.uint64Value),
                  Set(spaces).count == spaces.count else { return nil }
            return DisplaySpaces(id: id, name: screen.localizedName, spaces: spaces, active: active.uint64Value)
        }
        return displays.count == screens.count ? displays : nil
    }

    func waitForActive(_ target: SpacePosition, afterOverviewOn dock: AXUIElement? = nil,
                       timeout: Duration = .seconds(6)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        var matchingSince: ContinuousClock.Instant?
        repeat {
            if Task.isCancelled { return false }
            let overviewClosed = dock.map { overviewIsClosed($0) } ?? true
            let active = displays()?.first(where: { $0.id == target.display })?.active
            if overviewClosed, active == target.space {
                let now = ContinuousClock.now
                if let matchingSince {
                    if now - matchingSince >= .milliseconds(280) { return true }
                } else {
                    matchingSince = now
                }
            } else {
                matchingSince = nil
            }
            try? await Task.sleep(for: .milliseconds(90))
        } while ContinuousClock.now < deadline
        return false
    }

    private func overviewIsClosed(_ dock: AXUIElement) -> Bool {
        guard let items = attribute(dock, kAXChildrenAttribute) as? [AXUIElement] else { return false }
        return !items.contains { identifier($0) == "mc" }
    }

    private func selectWithSwipe(_ target: SpacePosition, whileCurrent: () -> Bool) async -> Bool {
        var visitedSpaces = Set<UInt64>()
        while !Task.isCancelled, whileCurrent() {
            guard let display = displays()?.first(where: { $0.id == target.display }),
                  let current = display.spaces.firstIndex(of: display.active),
                  let destination = display.spaces.firstIndex(of: target.space) else { return false }
            if current == destination { return true }
            guard visitedSpaces.insert(display.active).inserted else { return false }

            let forward = destination > current
            let next = SpacePosition(display: display.id, space: display.spaces[current + (forward ? 1 : -1)])
            guard postSwipe(on: display.id, forward: forward) else { return false }
            let reached = await waitForActive(next, timeout: .seconds(2))
            log.notice("direct swipe display=\(display.id) space=\(next.space) confirmed=\(reached)")
            if !reached { return false }
        }
        return false
    }

    private func postSwipe(on display: CGDirectDisplayID, forward: Bool) -> Bool {
        let bounds = CGDisplayBounds(display)
        guard !bounds.isEmpty, let event = CGEvent(source: nil) else { return false }
        let sign = forward ? 1.0 : -1.0
        // Gesture fields and phase sequence adapted from yabai (see THIRD_PARTY_NOTICES.md).
        // On macOS 26 the Dock routes this horizontal gesture by its event location.
        event.location = CGPoint(x: bounds.midX, y: bounds.midY)
        event.setIntegerValueField(CGEventField(rawValue: 55)!, value: 30) // DockControl
        event.setIntegerValueField(CGEventField(rawValue: 110)!, value: 23) // Dock swipe
        event.setIntegerValueField(CGEventField(rawValue: 123)!, value: 1) // Horizontal
        event.setDoubleValueField(CGEventField(rawValue: 124)!, value: sign) // Progress
        event.setDoubleValueField(CGEventField(rawValue: 129)!, value: sign * 9999) // Velocity X
        let phase = CGEventField(rawValue: 132)!
        event.setIntegerValueField(phase, value: 1) // Began
        event.post(tap: .cgSessionEventTap)
        event.setIntegerValueField(phase, value: 4) // Ended
        event.post(tap: .cgSessionEventTap)
        return true
    }

    func openMissionControl() async -> Bool {
        let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app", isDirectory: true)
        let config = NSWorkspace.OpenConfiguration()
        config.addsToRecentItems = false
        config.activates = true
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: config) { running, error in
                continuation.resume(returning: running != nil && error == nil)
            }
        }
    }

    func select(_ target: SpacePosition, whileCurrent: () -> Bool) async -> Bool {
        guard whileCurrent(), AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            log.notice("cross-display selection unavailable before opening Mission Control")
            return false
        }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.3)
        let alreadyOpen = missionGroup(app) != nil
        if !alreadyOpen, ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26 {
            return await selectWithSwipe(target, whileCurrent: whileCurrent)
        }
        if !alreadyOpen {
            guard await openMissionControl() else {
                log.notice("Mission Control launch request failed")
                return false
            }
        }

        // Dock may publish its AX tree before its Space buttons are ready.
        try? await Task.sleep(for: .milliseconds(350))
        let didPress = await pressTarget(target, in: app, whileCurrent: whileCurrent)
        if didPress {
            if await waitForActive(target, afterOverviewOn: app, timeout: .milliseconds(1400)) { return true }
            if !alreadyOpen, !Task.isCancelled, whileCurrent(), missionGroup(app) != nil {
                log.notice("Mission Control still open after Space press; retrying target once")
                _ = await pressTarget(target, in: app, whileCurrent: whileCurrent)
            }
            if await waitForActive(target, afterOverviewOn: app, timeout: .milliseconds(4600)) { return true }
            log.notice("Space button pressed but switch did not settle")
        }
        if !alreadyOpen, missionGroup(app) != nil {
            _ = await openMissionControl()
        }
        return false
    }

    private func pressTarget(_ target: SpacePosition, in dock: AXUIElement, whileCurrent: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(3)
        var detail = "no result"
        repeat {
            guard !Task.isCancelled, whileCurrent() else {
                log.notice("Space selection cancelled because pointer or cycle changed")
                return false
            }
            let lookup = targetButton(target, in: dock)
            detail = lookup.detail
            if let button = lookup.button, !Task.isCancelled, whileCurrent() {
                let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
                log.notice("Dock Space button action returned \(result.rawValue)")
                // The Dock can accept the action and invalidate the element while it responds.
                if result == .success || result == .cannotComplete { return true }
                detail = "Dock refused AXPress (\(result.rawValue))"
                break
            }
            try? await Task.sleep(for: .milliseconds(90))
        } while ContinuousClock.now < deadline
        log.notice("Dock Space lookup failed: \(detail, privacy: .public)")
        return false
    }

    private func targetButton(_ target: SpacePosition, in dock: AXUIElement) -> (button: AXUIElement?, detail: String) {
        // The Dock AX hierarchy was documented by Hammerspoon's hs.spaces module.
        guard let group = missionGroup(dock) else { return (nil, "no Mission Control group") }
        let screenGroups = children(of: group).filter { identifier($0) == "mc.display" }
        guard let display = screenGroups.first(where: { displayID(of: $0) == target.display }) else {
            let ids = screenGroups.compactMap { displayID(of: $0) }
            return (nil, "target display \(target.display) missing from Dock displays \(ids)")
        }
        guard let section = children(of: display).first(where: { identifier($0) == "mc.spaces" }),
              let list = children(of: section).first(where: { identifier($0) == "mc.spaces.list" }) else {
            return (nil, "no Spaces list on display \(target.display)")
        }
        guard let screen = displays()?.first(where: { $0.id == target.display }),
              let index = screen.spaces.firstIndex(of: target.space) else {
            return (nil, "target Space missing from current display catalog")
        }
        let buttons = children(of: list).filter { element in
            var actions: CFArray?
            guard AXUIElementCopyActionNames(element, &actions) == .success else { return false }
            return (actions as? [String])?.contains(kAXPressAction as String) == true
        }
        guard buttons.count == screen.spaces.count, buttons.indices.contains(index) else {
            return (nil, "Dock buttons \(buttons.count), catalog Spaces \(screen.spaces.count) on display \(target.display)")
        }
        return (buttons[index], "ready")
    }

    private func displayID(of element: AXUIElement) -> CGDirectDisplayID? {
        let value = attribute(element, "AXDisplayID")
        if let number = value as? NSNumber { return number.uint32Value }
        return (value as? String).flatMap { UInt32($0) }
    }

    private func missionGroup(_ dock: AXUIElement) -> AXUIElement? {
        children(of: dock).first { identifier($0) == "mc" }
    }

    private func children(of element: AXUIElement?) -> [AXUIElement] {
        guard let element else { return [] }
        return attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private func identifier(_ element: AXUIElement) -> String? {
        attribute(element, kAXIdentifierAttribute) as? String
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
