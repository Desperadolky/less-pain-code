import AppKit
import ApplicationServices
import Carbon
import CoreGraphics
import OSLog
import QuartzCore

private let log = Logger(subsystem: "io.github.desperadolky.qiping", category: "interaction")
private let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Less Pain Code"

private enum RailColors {
    static let surface = color(0x202630)
    static let rim = color(0x9FB4D4).withAlphaComponent(0.35)
    static let foreground = color(0xEFF3F9)
    static let secondary = color(0xBFC9D9)
    static let tertiary = color(0xA1ACBE)
    static let divider = color(0xB8C5D8).withAlphaComponent(0.16)

    private static func color(_ rgb: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

private final class PassivePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        animationBehavior = .none
        title = appName
    }
}

private final class RailButton: NSButton {
    private var hovered = false
    private var hoverTracking: NSTrackingArea?
    private let glyph: NSImage?
    private let label: NSAttributedString

    init(symbol: String, title: String = "", hint: String) {
        let ink = RailColors.foreground
        let symbolStyle = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            .applying(.init(paletteColors: [ink]))
        glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolStyle)
        label = NSAttributedString(string: title, attributes: [
            .foregroundColor: ink,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium)
        ])
        super.init(frame: .zero)
        self.title = title
        isBordered = false
        setButtonType(.momentaryChange)
        toolTip = hint
        setAccessibilityLabel(hint)
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        hoverTracking = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        needsDisplay = true
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if hovered || isHighlighted {
            let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 3), xRadius: 9, yRadius: 9)
            RailColors.foreground.withAlphaComponent(isHighlighted ? 0.16 : 0.08).setFill()
            background.fill()
        }
        if let glyph {
            let centerX = title.isEmpty ? bounds.midX : 16
            glyph.draw(in: NSRect(x: centerX - glyph.size.width / 2, y: bounds.midY - glyph.size.height / 2,
                                 width: glyph.size.width, height: glyph.size.height),
                       from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        label.draw(at: NSPoint(x: 29, y: bounds.midY - label.size().height / 2))
    }
}

private final class RailHandle: NSView {
    private let artwork: NSImage?
    private let isButton: Bool
    private var start: (pointer: NSPoint, frame: NSRect)?
    private var didDrag = false
    var isDragging: Bool { start != nil }
    var constrain: ((NSRect) -> NSRect)?
    var didMove: ((NSRect) -> Void)?
    var didPress: (() -> Void)?

    init(artwork: NSImage? = nil, actionLabel: String? = nil) {
        self.artwork = artwork
        isButton = actionLabel != nil
        super.init(frame: .zero)
        setAccessibilityElement(isButton)
        if let actionLabel {
            toolTip = "点击\(actionLabel) · 拖动移动"
            setAccessibilityRole(.button)
            setAccessibilityLabel("小白猫，\(actionLabel)")
        } else {
            toolTip = "按住拖动导航栏"
        }
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: isButton ? .pointingHand : .openHand)
    }

    override func accessibilityPerformPress() -> Bool {
        guard let didPress else { return false }
        didPress()
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        if let artwork {
            let area = bounds.height <= 40 ? bounds.insetBy(dx: 7, dy: 6) : bounds.insetBy(dx: 4, dy: 2)
            let scale = min(area.width / artwork.size.width, area.height / artwork.size.height)
            let size = NSSize(width: artwork.size.width * scale, height: artwork.size.height * scale)
            artwork.draw(in: NSRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2,
                                    width: size.width, height: size.height))
            return
        }
        RailColors.tertiary.setFill()
        let centerX = isButton ? bounds.midX : 7
        for x in [-2.0, 2.0] {
            for y in [-4.0, 0.0, 4.0] {
                NSBezierPath(ovalIn: NSRect(x: centerX + x - 1, y: bounds.midY + y - 1,
                                           width: 2, height: 2)).fill()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        start = (pointerLocation(event, in: window), window.frame)
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let start else { return }
        let pointer = pointerLocation(event, in: window)
        let dx = pointer.x - start.pointer.x
        let dy = pointer.y - start.pointer.y
        if !didDrag {
            guard hypot(dx, dy) >= 4 else { return }
            didDrag = true
            NSCursor.closedHand.push()
        }
        let moved = start.frame.offsetBy(dx: dx, dy: dy)
        window.setFrameOrigin((constrain?(moved) ?? moved).origin)
    }

    override func mouseUp(with event: NSEvent) {
        guard let start else { return }
        self.start = nil
        if didDrag {
            didDrag = false
            NSCursor.pop()
            if let frame = window?.frame, frame.origin != start.frame.origin { didMove?(frame) }
        } else if bounds.contains(convert(event.locationInWindow, from: nil)) {
            didPress?()
        }
    }

    private func pointerLocation(_ event: NSEvent, in window: NSWindow) -> NSPoint {
        event.cgEvent?.unflippedLocation ?? window.convertPoint(toScreen: event.locationInWindow)
    }
}

private struct Rail {
    let panel: PassivePanel
    let titleGrip: RailHandle
    let expandedCat: RailHandle
    let cat: RailHandle
    let expanded: NSStackView
    let layout: NSStackView
    let expandedSize: NSSize

    var isDragging: Bool { titleGrip.isDragging || expandedCat.isDragging || cat.isDragging }
}

private enum Action: Int {
    case previousDesktop, nextDesktop, overview, apps, voice, returnKey, deleteKey, options
}

private enum Shortcuts {
    static var permitted: Bool { CGPreflightPostEventAccess() }

    static func desktop(next: Bool) -> Bool {
        // Mission Control expects a hardware-style arrow event, including the function-key flag.
        let key = CGKeyCode(next ? kVK_RightArrow : kVK_LeftArrow)
        return press(key, flags: [.maskControl, .maskSecondaryFn])
    }

    static func press(_ key: CGKeyCode, flags: CGEventFlags = []) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        else { return false }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    static func rightCommand() -> Bool {
        let key = CGKeyCode(kVK_RightCommand)
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
        else { return false }
        // macOS reports physical modifier presses as flagsChanged. The device bit is right Command.
        let rightCommandBit = UInt64(0x10)
        down.type = .flagsChanged
        up.type = .flagsChanged
        down.flags = .init(rawValue: CGEventFlags.maskCommand.rawValue | rightCommandBit)
        up.flags = []
        down.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(75)) {
            up.post(tap: .cghidEventTap)
        }
        return true
    }

    static func currentInputSourceUsesRightCommandForVoice() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let value = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return false }
        let identifier = Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
        let doubao = "com.bytedance.inputmethod.doubaoime"
        return identifier == doubao || identifier.hasPrefix(doubao + ".")
    }
}

@MainActor
private final class Navigator: NSObject, NSApplicationDelegate {
    private let workspace = NSWorkspace.shared
    private let catArtwork = Bundle.main.url(forResource: "WhiteCat", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) } ?? NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: nil)
    private var rails: [CGDirectDisplayID: Rail] = [:]
    private var desktopLabels: [CGDirectDisplayID: NSTextField] = [:]
    private var compact = UserDefaults.standard.bool(forKey: "railCompact")
    private let spaces = MacSpaces()
    private var cycle: SpaceCycle?
    private var cycleTask: Task<Void, Never>?
    private var pending: [(origin: CGDirectDisplayID, forward: Bool, button: RailButton)] = []
    private var cycleEnabled = UserDefaults.standard.object(forKey: "cycleAcrossDisplays") as? Bool ?? true
    private var displayFrames: [(id: CGDirectDisplayID, frame: NSRect)] = []
    private var shownDisplay: CGDirectDisplayID?
    private var pointerTimer: Timer?
    private var pointerWrap: PointerWrap?
    private var globalPointerMonitor: Any?
    private var localPointerMonitor: Any?
    private var railRecoveryTask: Task<Void, Never>?
    private var recent: [pid_t] = []
    private var observers: [NSObjectProtocol] = []
    private var statusItem: NSStatusItem?
    private var visible = true
    private var feedback: PassivePanel?
    private var feedbackGeneration = 0
    private var voicePending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let active = workspace.frontmostApplication { remember(active) }
        observers.append(workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.remember(app)
                }
            }
        })
        observers.append(workspace.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.recoverRailAfterSpaceChange()
                if self.cycleTask == nil { self.updateCycleCaption() }
            }
        })
        installMenuBarItem()
        refreshScreens()
        startFollowingPointer()
        if UserDefaults.standard.bool(forKey: "pointerWrapEnabled") { startPointerWrap() }
        log.notice("launch displays=\(self.rails.count) postEvents=\(Shortcuts.permitted) axTrusted=\(AXIsProcessTrusted()) spacesRead=\(self.spaces.displays() != nil)")
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) { refreshScreens() }

    func applicationWillTerminate(_ notification: Notification) {
        pointerTimer?.invalidate()
        stopPointerWrap()
        railRecoveryTask?.cancel()
        cancelCycle()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        visible = true
        refreshScreens()
        return false
    }

    private func remember(_ app: NSRunningApplication) {
        guard app.activationPolicy == .regular else { return }
        recent.removeAll { $0 == app.processIdentifier }
        recent.insert(app.processIdentifier, at: 0)
        if recent.count > 48 { recent.removeLast() }
    }

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: appName)
        item.button?.toolTip = appName
        item.menu = optionsMenu()
        item.menu?.delegate = self
        statusItem = item
    }

    private func refreshScreens() {
        let screens = NSScreen.screens
        displayFrames = screens.compactMap { screen in
            screen.displayID.map { ($0, screen.frame) }
        }
        pointerWrap = PointerWrap(frames: displayFrames.map { CGDisplayBounds($0.id) })
        let online = Set(displayFrames.map(\.id))
        for id in Set(rails.keys).subtracting(online) {
            rails.removeValue(forKey: id)?.panel.close()
            desktopLabels.removeValue(forKey: id)
        }
        for screen in screens {
            guard let id = screen.displayID else { continue }
            let rail = rails[id] ?? makeRail(screen: screen)
            rails[id] = rail
            rail.panel.title = "\(appName) · \(screen.localizedName)"
            position(rail, on: screen)
        }
        updateRailVisibility(force: true)
        log.info("layout displays=\(online.count) visible=\(self.visible)")
    }

    private func startFollowingPointer() {
        let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateRailVisibility() }
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        pointerTimer = timer
    }

    private func startPointerWrap() {
        globalPointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            MainActor.assumeIsolated { self?.wrapPointer(for: event) }
        }
        guard globalPointerMonitor != nil else {
            log.error("pointer wrap could not start monitoring mouse movement")
            return
        }
        localPointerMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.wrapPointer(for: event)
            return event
        }
        log.notice("pointer wrap enabled")
    }

    private func stopPointerWrap() {
        if let globalPointerMonitor { NSEvent.removeMonitor(globalPointerMonitor) }
        if let localPointerMonitor { NSEvent.removeMonitor(localPointerMonitor) }
        globalPointerMonitor = nil
        localPointerMonitor = nil
        pointerWrap?.reset()
    }

    private func wrapPointer(for event: NSEvent) {
        guard NSEvent.pressedMouseButtons == 0 else {
            pointerWrap?.reset()
            return
        }
        guard let point = event.cgEvent?.location,
              let destination = pointerWrap?.destination(
                at: point, dx: event.deltaX, dy: event.deltaY, time: event.timestamp
              ),
              let cursor = CGEvent(source: nil)?.location, abs(cursor.x - point.x) <= 1,
              CGWarpMouseCursorPosition(destination) == .success else { return }
        updateRailVisibility()
        log.info("pointer wrapped left=\(destination.x < point.x)")
    }

    private func updateRailVisibility(force: Bool = false) {
        if let shownDisplay, rails[shownDisplay]?.isDragging == true { return }
        let display = visible ? pointerDisplay() : nil
        guard force || display != shownDisplay else { return }

        if shownDisplay != display {
            railRecoveryTask?.cancel()
            if let shownDisplay { rails[shownDisplay]?.panel.orderOut(nil) }
            cancelCycle()
        }
        shownDisplay = display
        if let display { rails[display]?.panel.orderFrontRegardless() }
        updateCycleCaption()
    }

    private func recoverRailAfterSpaceChange() {
        railRecoveryTask?.cancel()
        guard visible, let display = shownDisplay else { return }
        railRecoveryTask = Task { [weak self] in
            // The Space notification can arrive before the transition has finished.
            for delay in [500, 500] {
                try? await Task.sleep(for: .milliseconds(delay))
                guard !Task.isCancelled, let self, self.visible,
                      self.shownDisplay == display, self.pointerDisplay() == display,
                      let rail = self.rails[display] else { return }
                guard !rail.isDragging else { continue }

                let panel = rail.panel
                if panel.isVisible, panel.isOnActiveSpace, panel.occlusionState.contains(.visible) {
                    continue
                }
                // Reattach the panel if macOS left it offscreen during the transition.
                panel.orderOut(nil)
                panel.orderFrontRegardless()
                log.info("rail reordered after Space change display=\(display)")
            }
        }
    }

    private func pointerDisplay() -> CGDirectDisplayID? {
        let pointer = NSEvent.mouseLocation
        return displayFrames.first { $0.frame.contains(pointer) }?.id
    }

    private func cancelCycle() {
        cycleTask?.cancel()
        pending.removeAll()
        cycle = nil
    }

    private func updateCycleCaption() {
        guard let shownDisplay, let label = desktopLabels[shownDisplay] else { return }
        guard cycleEnabled,
              let displays = spaces.displays(), displays.count > 1 else {
            label.stringValue = "桌面"
            label.toolTip = "当前屏幕的桌面"
            return
        }
        if cycle?.canContinue(with: displays, origin: shownDisplay) == false { cycle = nil }
        let displayedCycle = cycle ?? SpaceCycle(displays: displays, origin: shownDisplay)
        label.stringValue = displayedCycle?.caption(in: displays) ?? "桌面"
        if let target = displayedCycle?.current, let screen = displays.first(where: { $0.id == target.display }) {
            label.toolTip = "目标屏幕：\(screen.name)"
        }
    }

    private func placementKey(for display: CGDirectDisplayID) -> String {
        let uuid = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue()
        let identity = uuid.map { CFUUIDCreateString(nil, $0) as String } ?? String(display)
        return "railPlacement.\(identity)"
    }

    private func constrained(_ frame: NSRect, in area: NSRect) -> NSRect {
        let margin: CGFloat = 6
        return NSRect(
            x: max(area.minX + margin, min(frame.minX, area.maxX - frame.width - margin)),
            y: max(area.minY + margin, min(frame.minY, area.maxY - frame.height - margin)),
            width: frame.width, height: frame.height
        )
    }

    private func position(_ rail: Rail, on screen: NSScreen) {
        guard let display = screen.displayID else { return }
        let area = screen.visibleFrame
        let saved = UserDefaults.standard.dictionary(forKey: placementKey(for: display))
        let right = saved?["right"] as? CGFloat ?? 116
        let top = saved?["top"] as? CGFloat ?? (area.height - rail.expandedSize.height) / 2
        let size = rail.panel.frame.size
        let frame = NSRect(x: floor(area.maxX - right - size.width), y: floor(area.maxY - top - size.height),
                           width: size.width, height: size.height)
        rail.panel.setFrameOrigin(constrained(frame, in: area).origin)
    }

    private func updatePresentation(_ rail: Rail) {
        rail.panel.contentView?.layer?.backgroundColor = compact ? NSColor.clear.cgColor : RailColors.surface.cgColor
        rail.panel.contentView?.layer?.borderWidth = compact ? 0 : 0.5
        rail.expanded.isHidden = compact
        rail.cat.isHidden = !compact
        rail.layout.layoutSubtreeIfNeeded()
        rail.panel.setContentSize(rail.layout.fittingSize)
        rail.panel.invalidateShadow()
    }

    private func toggleCompact() {
        compact.toggle()
        UserDefaults.standard.set(compact, forKey: "railCompact")
        for screen in NSScreen.screens {
            guard let id = screen.displayID, let rail = rails[id] else { continue }
            updatePresentation(rail)
            position(rail, on: screen)
            if compact, rail.panel.isVisible, !workspace.accessibilityDisplayShouldReduceMotion {
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 0.45
                fade.toValue = 1
                fade.duration = 0.13
                rail.cat.layer?.add(fade, forKey: "showCat")
            }
        }
        log.info("rail compact=\(self.compact)")
    }

    private func surface(radius: CGFloat) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.masksToBounds = true
        return view
    }

    private func makeRail(screen: NSScreen) -> Rail {
        let panel = PassivePanel()
        panel.collectionBehavior.formUnion([.stationary, .canJoinAllApplications])
        let base = NSView()
        base.wantsLayer = true
        base.layer?.cornerRadius = 14
        base.layer?.backgroundColor = RailColors.surface.cgColor
        base.layer?.borderColor = RailColors.rim.cgColor
        base.layer?.borderWidth = 0.5
        base.setAccessibilityElement(false)

        let buttonWidth: CGFloat = 120
        let buttonHeight: CGFloat = 40
        func button(_ action: Action, _ icon: String, title: String = "", hint: String,
                    width: CGFloat? = nil) -> RailButton {
            let button = RailButton(symbol: icon, title: title, hint: hint)
            button.tag = action.rawValue
            button.target = self
            button.action = #selector(didClick(_:))
            button.widthAnchor.constraint(equalToConstant: width ?? buttonWidth).isActive = true
            button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
            return button
        }

        func column(_ views: [NSView], spacing: CGFloat = 0) -> NSStackView {
            let stack = NSStackView(views: views)
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.spacing = spacing
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }

        func row(_ views: [NSView]) -> NSStackView {
            let stack = NSStackView(views: views)
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = 0
            return stack
        }

        func divider() -> NSView {
            let view = NSView()
            view.wantsLayer = true
            view.layer?.backgroundColor = RailColors.divider.cgColor
            view.widthAnchor.constraint(equalToConstant: buttonWidth - 12).isActive = true
            view.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
            return view
        }

        func catButton(_ label: String, width: CGFloat, height: CGFloat) -> RailHandle {
            let cat = RailHandle(artwork: catArtwork, actionLabel: label)
            cat.wantsLayer = true
            cat.widthAnchor.constraint(equalToConstant: width).isActive = true
            cat.heightAnchor.constraint(equalToConstant: height).isActive = true
            cat.didPress = { [weak self] in self?.toggleCompact() }
            return cat
        }

        let desktop = NSTextField(labelWithString: "桌面")
        desktop.alignment = .left
        desktop.textColor = RailColors.secondary
        desktop.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        desktop.lineBreakMode = .byTruncatingTail
        if let display = screen.displayID { desktopLabels[display] = desktop }
        desktop.toolTip = NSScreen.screensHaveSeparateSpaces
            ? "当前屏幕 · \(screen.localizedName)"
            : "显示器共用桌面空间"

        let caption = RailHandle()
        desktop.translatesAutoresizingMaskIntoConstraints = false
        caption.addSubview(desktop)
        NSLayoutConstraint.activate([
            caption.widthAnchor.constraint(equalToConstant: buttonWidth - buttonHeight),
            caption.heightAnchor.constraint(equalToConstant: buttonHeight),
            desktop.leadingAnchor.constraint(equalTo: caption.leadingAnchor, constant: 16),
            desktop.trailingAnchor.constraint(equalTo: caption.trailingAnchor, constant: -3),
            desktop.centerYAnchor.constraint(equalTo: caption.centerYAnchor)
        ])

        let expandedCat = catButton("收起导航栏", width: buttonHeight, height: buttonHeight)
        let header = row([caption, expandedCat])
        let arrowWidth = buttonWidth / 3
        let previous = button(.previousDesktop, "arrow.left", hint: "上一个桌面", width: arrowWidth)
        let overview = button(.overview, "arrow.up", hint: "打开调度中心", width: arrowWidth)
        let next = button(.nextDesktop, "arrow.right", hint: "下一个桌面", width: arrowWidth)
        let switchers = row([previous, overview, next])
        let apps = button(.apps, "square.grid.2x2", title: "App", hint: "切换 App")
        let voice = button(.voice, "mic", title: "语音输入", hint: "启动当前输入法的语音输入")
        let enter = button(.returnKey, "return", title: "回车", hint: "向当前应用发送回车")
        let delete = button(.deleteKey, "delete.left", title: "删除", hint: "向当前应用发送退格，删除光标前一个字符")
        let options = button(.options, "ellipsis", title: "更多", hint: "导航栏选项")

        let operations = column([voice, enter, delete, apps, options])
        let expanded = column([header, switchers, divider(), operations], spacing: 4)
        expanded.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 6, right: 8)
        let cat = catButton("展开导航栏", width: 56, height: 54)
        cat.isHidden = true
        let layout = column([expanded, cat])
        layout.detachesHiddenViews = true
        base.addSubview(layout)
        NSLayoutConstraint.activate([
            layout.leadingAnchor.constraint(equalTo: base.leadingAnchor),
            layout.trailingAnchor.constraint(equalTo: base.trailingAnchor),
            layout.topAnchor.constraint(equalTo: base.topAnchor),
            layout.bottomAnchor.constraint(equalTo: base.bottomAnchor)
        ])
        panel.contentView = base
        if let display = screen.displayID {
            let constrain: (NSRect) -> NSRect = { [weak self] frame in
                guard let self, let area = NSScreen.screens.first(where: { $0.displayID == display })?.visibleFrame
                else { return frame }
                return self.constrained(frame, in: area)
            }
            let didMove: (NSRect) -> Void = { [weak self] frame in
                guard let self, let area = NSScreen.screens.first(where: { $0.displayID == display })?.visibleFrame
                else { return }
                UserDefaults.standard.set(["right": Double(area.maxX - frame.maxX),
                                           "top": Double(area.maxY - frame.maxY)],
                                          forKey: self.placementKey(for: display))
                log.info("rail position saved display=\(display)")
            }
            for handle in [caption, expandedCat, cat] {
                handle.constrain = constrain
                handle.didMove = didMove
            }
        }
        let rail = Rail(panel: panel, titleGrip: caption, expandedCat: expandedCat, cat: cat,
                        expanded: expanded, layout: layout, expandedSize: expanded.fittingSize)
        updatePresentation(rail)
        return rail
    }

    @objc private func didClick(_ button: RailButton) {
        guard let action = Action(rawValue: button.tag) else { return }
        switch action {
        case .previousDesktop, .nextDesktop:
            changeDesktop(forward: action == .nextDesktop, near: button)
        case .overview:
            showMissionControl(near: button)
        case .apps:
            showApps(near: button)
        case .voice:
            triggerVoice(near: button)
        case .returnKey, .deleteKey:
            guard checkPermission(near: button) else { return }
            let isReturn = action == .returnKey
            let key = CGKeyCode(isReturn ? kVK_Return : kVK_Delete)
            if Shortcuts.press(key) {
                log.notice("editing key posted return=\(isReturn)")
            } else {
                showFeedback("无法发送按键", near: button)
            }
        case .options:
            show(optionsMenu(), near: button)
        }
    }

    private func changeDesktop(forward: Bool, near button: RailButton) {
        let acrossDisplays = cycleEnabled && NSScreen.screensHaveSeparateSpaces && displayFrames.count > 1
        guard checkPermission(near: button, needsAX: acrossDisplays) else { return }
        guard acrossDisplays, let origin = pointerDisplay() else {
            if !Shortcuts.desktop(next: forward) { showFeedback("无法切换桌面", near: button) }
            return
        }
        guard pending.count < 32 else {
            showFeedback("切换正在排队，请稍候", near: button)
            return
        }
        pending.append((origin, forward, button))
        log.info("cycle queued origin=\(origin) forward=\(forward) pending=\(self.pending.count)")
        runPendingSteps()
    }

    private func runPendingSteps() {
        guard cycleTask == nil, !pending.isEmpty else { return }
        cycleTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.cycleTask = nil
                self.runPendingSteps()
            }
            while !Task.isCancelled, !self.pending.isEmpty {
                let request = self.pending.removeFirst()
                guard request.origin == self.pointerDisplay() else { continue }
                let succeeded = await self.stepCycle(origin: request.origin, forward: request.forward)
                if !succeeded, !Task.isCancelled {
                    self.pending.removeAll()
                    self.cycle = nil
                    self.updateCycleCaption()
                    self.showFeedback("未切到目标桌面，可在菜单关闭跨屏循环", near: request.button)
                }
            }
        }
    }

    private func stepCycle(origin: CGDirectDisplayID, forward: Bool) async -> Bool {
        guard let displays = spaces.displays() else {
            log.notice("cycle could not read managed spaces")
            return false
        }
        let startingCycle: SpaceCycle?
        if let cycle, cycle.canContinue(with: displays, origin: origin) {
            startingCycle = cycle
        } else {
            startingCycle = SpaceCycle(displays: displays, origin: origin)
        }
        guard var nextCycle = startingCycle else { return false }

        let target = nextCycle.target(forward: forward, displays: displays)
        guard let destination = displays.first(where: { $0.id == target.display }) else { return false }
        if destination.active != target.space {
            let neighbor = destination.spaces.firstIndex(of: destination.active).map { $0 + (forward ? 1 : -1) }
            let useShortcut = target.display == origin && neighbor.map {
                destination.spaces.indices.contains($0) && destination.spaces[$0] == target.space
            } == true
            var switched = false
            if useShortcut, Shortcuts.desktop(next: forward) {
                switched = await spaces.waitForActive(target)
            }
            if !switched, !Task.isCancelled, pointerDisplay() == origin, cycleEnabled {
                switched = await spaces.select(target) { self.pointerDisplay() == origin && self.cycleEnabled }
            }
            log.notice("cycle target display=\(target.display) space=\(target.space) native=\(useShortcut) confirmed=\(switched)")
            guard switched else { return false }
        } else {
            log.notice("cycle target display=\(target.display) space=\(target.space) already visible")
        }
        guard !Task.isCancelled, pointerDisplay() == origin else { return false }
        nextCycle.confirm(target, forward: forward)
        cycle = nextCycle
        updateCycleCaption()
        return true
    }

    private func showMissionControl(near button: RailButton) {
        guard cycleTask == nil else { return }
        Task { [weak self, weak button] in
            guard let self else { return }
            let opened = await self.spaces.openMissionControl()
            log.notice("mission control launch requested accepted=\(opened)")
            if !opened, let button { self.showFeedback("无法打开调度中心", near: button) }
        }
    }

    private func checkPermission(near button: RailButton, needsAX: Bool = false) -> Bool {
        guard !Shortcuts.permitted || (needsAX && !AXIsProcessTrusted()) else { return true }
        log.notice("post event permission unavailable")
        let menu = NSMenu()
        let title = NSMenuItem(title: needsAX ? "跨屏切换需要辅助功能权限" : "发送按键需要辅助功能权限",
                               action: nil, keyEquivalent: "")
        menu.addItem(title)
        menu.addItem(item("打开辅助功能设置…", #selector(requestPermission)))
        show(menu, near: button)
        return false
    }

    private func triggerVoice(near button: RailButton) {
        guard !voicePending else { return }
        guard Shortcuts.currentInputSourceUsesRightCommandForVoice() else {
            showFeedback("当前输入法不支持语音输入", near: button)
            log.notice("voice unavailable for current input source")
            return
        }
        guard checkPermission(near: button) else { return }
        guard Shortcuts.rightCommand() else {
            showFeedback("无法发送语音快捷键", near: button)
            return
        }
        log.notice("right Command shortcut posted")
        voicePending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(160)) { [weak self] in
            self?.voicePending = false
        }
    }

    private func showApps(near button: RailButton) {
        let menu = NSMenu(title: "切换 App")
        menu.minimumWidth = 188
        let active = workspace.frontmostApplication?.processIdentifier
        let rank = Dictionary(uniqueKeysWithValues: recent.enumerated().map { ($0.element, $0.offset) })
        let running = workspace.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated && $0.bundleURL != nil }
            .sorted { a, b in
                let first = rank[a.processIdentifier] ?? Int.max
                let second = rank[b.processIdentifier] ?? Int.max
                if first != second { return first < second }
                return (a.localizedName ?? "").localizedStandardCompare(b.localizedName ?? "") == .orderedAscending
            }
        if running.isEmpty {
            menu.addItem(NSMenuItem(title: "没有打开的 App", action: nil, keyEquivalent: ""))
        }
        for app in running {
            let entry = item(app.localizedName ?? "App", #selector(activateApp(_:)))
            entry.representedObject = app
            if let icon = app.icon?.copy() as? NSImage {
                icon.size = NSSize(width: 18, height: 18)
                entry.image = icon
            }
            entry.state = app.processIdentifier == active ? .on : .off
            menu.addItem(entry)
        }
        log.notice("app menu entries=\(running.count)")
        show(menu, near: button)
    }

    @objc private func activateApp(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? NSRunningApplication,
              !target.isTerminated, let url = target.bundleURL else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.createsNewApplicationInstance = false
        workspace.openApplication(at: url, configuration: config) { running, error in
            log.notice("app selection requested pid=\(target.processIdentifier) opened=\(running?.processIdentifier ?? -1) error=\(error != nil)")
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(450)) {
                log.notice("app selection frontmost=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier)")
            }
        }
    }

    private func show(_ menu: NSMenu, near button: RailButton) {
        menu.update()
        menu.popUp(positioning: nil, at: NSPoint(x: -menu.size.width - 8, y: button.bounds.maxY), in: button)
    }

    private func showFeedback(_ text: String, near button: RailButton) {
        guard let anchor = button.window, let screen = anchor.screen else { return }
        feedback?.close()
        feedbackGeneration += 1
        let generation = feedbackGeneration
        let toast = PassivePanel()
        let base = surface(radius: 10)
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.sizeToFit()
        label.frame.origin = NSPoint(x: 12, y: 10)
        base.addSubview(label)
        let width = label.frame.width + 24
        let area = screen.visibleFrame
        toast.contentView = base
        toast.setContentSize(NSSize(width: width, height: label.frame.height + 20))
        toast.setFrameOrigin(NSPoint(x: min(anchor.frame.maxX - width, area.maxX - width - 10),
                                     y: min(anchor.frame.maxY + 8, area.maxY - toast.frame.height - 10)))
        toast.ignoresMouseEvents = true
        feedback = toast
        toast.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard let self, self.feedbackGeneration == generation else { return }
            self.feedback?.close()
            self.feedback = nil
        }
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func optionsMenu() -> NSMenu {
        let menu = NSMenu(title: appName)
        menu.addItem(item(visible ? "隐藏导航栏" : "显示导航栏", #selector(toggleVisibility)))
        let cycleItem = item("跨屏循环", #selector(toggleCycle))
        cycleItem.state = cycleEnabled ? .on : .off
        menu.addItem(cycleItem)
        let wrapItem = item("鼠标跨屏绕回", #selector(togglePointerWrap))
        wrapItem.state = globalPointerMonitor == nil ? .off : .on
        menu.addItem(wrapItem)
        menu.addItem(.separator())
        menu.addItem(item("辅助功能设置…", #selector(requestPermission)))
        menu.addItem(item("桌面快捷键设置…", #selector(openKeyboardSettings)))
        menu.addItem(.separator())
        menu.addItem(item("退出 \(appName)", #selector(quit)))
        return menu
    }

    @objc private func toggleCycle() {
        cycleEnabled.toggle()
        UserDefaults.standard.set(cycleEnabled, forKey: "cycleAcrossDisplays")
        cancelCycle()
        updateCycleCaption()
        statusItem?.menu?.items.first(where: { $0.action == #selector(toggleCycle) })?.state = cycleEnabled ? .on : .off
    }

    @objc private func togglePointerWrap() {
        if globalPointerMonitor == nil {
            startPointerWrap()
        } else {
            stopPointerWrap()
        }
        UserDefaults.standard.set(globalPointerMonitor != nil, forKey: "pointerWrapEnabled")
    }

    @objc private func toggleVisibility() {
        visible.toggle()
        feedback?.close()
        feedback = nil
        refreshScreens()
    }

    @objc private func requestPermission() {
        if !Shortcuts.permitted {
            _ = CGRequestPostEventAccess()
        } else if !AXIsProcessTrusted() {
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @objc private func openKeyboardSettings() {
        openSettings("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    private func openSettings(_ path: String) {
        if let url = URL(string: path) { workspace.open(url) }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

extension Navigator: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.first?.title = visible ? "隐藏导航栏" : "显示导航栏"
        menu.items.first(where: { $0.action == #selector(togglePointerWrap) })?.state =
            globalPointerMonitor == nil ? .off : .on
    }
}

@main
private struct LessPainCode {
    @MainActor static func main() {
        let app = NSApplication.shared
        let navigator = Navigator()
        app.setActivationPolicy(.accessory)
        app.delegate = navigator
        withExtendedLifetime(navigator) { app.run() }
    }
}
