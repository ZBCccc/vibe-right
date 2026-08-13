import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

private func alternateMenuEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<AlternateMenuTriggerController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.handleEventTap(type: type, event: event)
}

private struct CapturedMouseEvent {
    enum Kind {
        case modifierRightClick
        case middleClick
    }

    var kind: Kind
    var quartzLocation: CGPoint
    var menuLocation: NSPoint
    var flags: CGEventFlags
}

private enum FinderContextProviderError: LocalizedError {
    case scriptUnavailable
    case finderError(String)
    case invalidResult

    var errorDescription: String? {
        switch self {
        case .scriptUnavailable:
            return L10n.text("无法准备 Finder 位置读取器")
        case let .finderError(message):
            return L10n.format("读取 Finder 位置失败：%@", message)
        case .invalidResult:
            return L10n.text("Finder 未返回可用的文件位置")
        }
    }
}

private final class FinderContextProvider {
    private let script: NSAppleScript?

    init() {
        script = NSAppleScript(source: Self.scriptSource)
    }

    func snapshot() throws -> FinderContextSnapshot {
        guard let script else { throw FinderContextProviderError.scriptUnavailable }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = errorInfo["NSAppleScriptErrorMessage"] as? String
                ?? errorInfo.description
            throw FinderContextProviderError.finderError(message)
        }
        guard let value = result.stringValue,
              let snapshot = FinderContextSnapshot(serialized: value) else {
            throw FinderContextProviderError.invalidResult
        }
        return snapshot
    }

    private static let scriptSource = """
    tell application "Finder"
        set targetPath to ""
        if (count of Finder windows) > 0 then
            try
                set targetPath to POSIX path of (target of front Finder window as alias)
            end try
        end if

        set selectedPaths to {}
        repeat with selectedItem in selection
            try
                set end of selectedPaths to POSIX path of (selectedItem as alias)
            end try
        end repeat

        set previousDelimiters to AppleScript's text item delimiters
        set AppleScript's text item delimiters to ASCII character 30
        set selectedText to selectedPaths as text
        set AppleScript's text item delimiters to previousDelimiters
        return targetPath & (ASCII character 31) & selectedText
    end tell
    """
}

final class AlternateMenuTriggerController: NSObject {
    private static let syntheticEventMarker: Int64 = 0x5649_4245_5249_4748
    private static let finderBundleIdentifier = "com.apple.finder"

    private let store = ConfigStore.shared
    private let contextProvider = FinderContextProvider()
    private let menuController = FinderSync(standalone: true)
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var gestureMonitor: Any?
    private var pendingRightClick: CapturedMouseEvent?
    private var pendingMiddleClick: CapturedMouseEvent?
    private var isPresentingMenu = false
    private var lastTriggerTime: TimeInterval = 0
    private var lastErrorTime: TimeInterval = 0

    private struct TrackedTouch {
        var start: NSPoint
        var latest: NSPoint
    }

    private var trackedTouches: [ObjectIdentifier: TrackedTouch] = [:]
    private var threeFingerStartTime: TimeInterval?
    private var threeFingerCandidateCancelled = false
    private var threeFingerPressureTriggered = false

    override init() {
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(configChanged),
            name: Notification.Name("com.vibecoding.VibeRight.configChanged"),
            object: nil
        )
        rebuildMonitors()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        removeMonitors()
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func refreshPermissionState() {
        rebuildMonitors()
    }

    @objc private func configChanged() {
        store.reload()
        rebuildMonitors()
    }

    private func rebuildMonitors() {
        removeMonitors()
        let config = store.config
        if config.modifierRightClickEnabled || config.middleClickEnabled {
            installEventTap()
        }
        if config.threeFingerTapEnabled {
            installGestureMonitor()
        }
    }

    private func removeMonitors() {
        if let gestureMonitor {
            NSEvent.removeMonitor(gestureMonitor)
            self.gestureMonitor = nil
        }
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            self.eventTapSource = nil
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        pendingRightClick = nil
        pendingMiddleClick = nil
        resetThreeFingerCandidate()
    }

    private func installEventTap() {
        let eventTypes: [CGEventType] = [
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp
        ]
        let mask = eventTypes.reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << CGEventMask($1.rawValue))
        }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: alternateMenuEventTapCallback,
            userInfo: userInfo
        ) else { return }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return
        }
        eventTap = tap
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func installGestureMonitor() {
        let mask: NSEvent.EventTypeMask = [
            .beginGesture,
            .endGesture,
            .gesture,
            .directTouch,
            .pressure
        ]
        gestureMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleGesture(event)
        }
    }

    fileprivate func handleEventTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.finderBundleIdentifier else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .rightMouseDown:
            guard store.config.modifierRightClickEnabled,
                  modifierMatches(event.flags, configured: store.config.modifierRightClickModifier),
                  canBeginTrigger() else {
                return Unmanaged.passUnretained(event)
            }
            pendingRightClick = CapturedMouseEvent(
                kind: .modifierRightClick,
                quartzLocation: event.location,
                menuLocation: NSEvent.mouseLocation,
                flags: event.flags
            )
            return nil
        case .rightMouseUp:
            guard let captured = pendingRightClick else {
                return Unmanaged.passUnretained(event)
            }
            pendingRightClick = nil
            DispatchQueue.main.async { [weak self] in self?.presentMenu(for: captured) }
            return nil
        case .otherMouseDown:
            guard event.getIntegerValueField(.mouseEventButtonNumber) == 2,
                  store.config.middleClickEnabled,
                  canBeginTrigger() else {
                return Unmanaged.passUnretained(event)
            }
            pendingMiddleClick = CapturedMouseEvent(
                kind: .middleClick,
                quartzLocation: event.location,
                menuLocation: NSEvent.mouseLocation,
                flags: event.flags
            )
            return nil
        case .otherMouseUp:
            guard event.getIntegerValueField(.mouseEventButtonNumber) == 2,
                  let captured = pendingMiddleClick else {
                return Unmanaged.passUnretained(event)
            }
            pendingMiddleClick = nil
            DispatchQueue.main.async { [weak self] in self?.presentMenu(for: captured) }
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func modifierMatches(_ flags: CGEventFlags, configured: AlternateMenuModifier) -> Bool {
        switch configured {
        case .shift: return flags.contains(.maskShift)
        case .control: return flags.contains(.maskControl)
        case .option: return flags.contains(.maskAlternate)
        case .command: return flags.contains(.maskCommand)
        }
    }

    private func canBeginTrigger() -> Bool {
        guard !isPresentingMenu else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTriggerTime > 0.25 else { return false }
        lastTriggerTime = now
        return true
    }

    private func presentMenu(for captured: CapturedMouseEvent) {
        do {
            let snapshot = try contextProvider.snapshot()
            guard snapshot.requiresAlternateMenu,
                  let menu = menuController.menu(for: snapshot) else {
                repost(captured)
                return
            }
            isPresentingMenu = true
            _ = menu.popUp(positioning: nil, at: captured.menuLocation, in: nil)
            isPresentingMenu = false
        } catch {
            repost(captured)
            showContextError(error)
        }
    }

    private func presentThreeFingerMenu(at location: NSPoint) {
        guard canBeginTrigger() else { return }
        do {
            let snapshot = try contextProvider.snapshot()
            guard snapshot.requiresAlternateMenu,
                  let menu = menuController.menu(for: snapshot) else { return }
            isPresentingMenu = true
            _ = menu.popUp(positioning: nil, at: location, in: nil)
            isPresentingMenu = false
        } catch {
            showContextError(error)
        }
    }

    private func repost(_ captured: CapturedMouseEvent) {
        let mouseButton: CGMouseButton = captured.kind == .middleClick ? .center : .right
        let downType: CGEventType = captured.kind == .middleClick ? .otherMouseDown : .rightMouseDown
        let upType: CGEventType = captured.kind == .middleClick ? .otherMouseUp : .rightMouseUp
        for type in [downType, upType] {
            guard let event = CGEvent(
                mouseEventSource: nil,
                mouseType: type,
                mouseCursorPosition: captured.quartzLocation,
                mouseButton: mouseButton
            ) else { continue }
            event.flags = captured.flags
            event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
            event.post(tap: .cghidEventTap)
        }
    }

    private func handleGesture(_ event: NSEvent) {
        guard store.config.threeFingerTapEnabled,
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.finderBundleIdentifier,
              !isPresentingMenu else {
            resetThreeFingerCandidate()
            return
        }

        let touching = event.touches(matching: .touching, in: nil)
        let allTouches = event.allTouches()
        if threeFingerStartTime == nil, touching.count == 3 {
            threeFingerStartTime = ProcessInfo.processInfo.systemUptime
            trackedTouches = Dictionary(uniqueKeysWithValues: touching.map {
                (ObjectIdentifier($0.identity as AnyObject), TrackedTouch(start: $0.normalizedPosition, latest: $0.normalizedPosition))
            })
            threeFingerCandidateCancelled = false
            threeFingerPressureTriggered = false
        }

        guard let startTime = threeFingerStartTime else { return }
        if touching.count > 3 || ProcessInfo.processInfo.systemUptime - startTime > 0.65 {
            threeFingerCandidateCancelled = true
        }
        for touch in allTouches {
            let identity = ObjectIdentifier(touch.identity as AnyObject)
            guard var tracked = trackedTouches[identity] else { continue }
            tracked.latest = touch.normalizedPosition
            trackedTouches[identity] = tracked
            let dx = tracked.latest.x - tracked.start.x
            let dy = tracked.latest.y - tracked.start.y
            if hypot(dx, dy) > 0.045 { threeFingerCandidateCancelled = true }
        }

        if event.type == .pressure,
           event.stage >= 1,
           touching.count == 3,
           !threeFingerCandidateCancelled,
           !threeFingerPressureTriggered {
            threeFingerPressureTriggered = true
            presentThreeFingerMenu(at: NSEvent.mouseLocation)
            resetThreeFingerCandidate()
            return
        }

        let ended: NSTouch.Phase = [.ended, .cancelled]
        let endingTouches = event.touches(matching: ended, in: nil)
        let gestureEnded = event.type == .endGesture || (!endingTouches.isEmpty && touching.isEmpty)
        if gestureEnded {
            let shouldTrigger = trackedTouches.count == 3 && !threeFingerCandidateCancelled && !threeFingerPressureTriggered
            resetThreeFingerCandidate()
            if shouldTrigger { presentThreeFingerMenu(at: NSEvent.mouseLocation) }
        }
    }

    private func resetThreeFingerCandidate() {
        trackedTouches.removeAll(keepingCapacity: true)
        threeFingerStartTime = nil
        threeFingerCandidateCancelled = false
        threeFingerPressureTriggered = false
    }

    private func showContextError(_ error: Error) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastErrorTime > 5 else { return }
        lastErrorTime = now
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L10n.text("无法打开备用右键菜单")
        alert.informativeText = error.localizedDescription + "\n\n" + L10n.text("首次使用需要允许灵犀右键访问 Finder。")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text("打开自动化权限设置"))
        alert.addButton(withTitle: L10n.text("取消"))
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
