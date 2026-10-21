import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// The Slack message box the user is typing in.
struct Composer {
    let element: AXUIElement
    let app: NSRunningApplication
    /// Frame in Accessibility coordinates (origin at the top-left of the primary screen).
    let axFrame: CGRect

    /// Frame converted to AppKit screen coordinates (origin at the bottom-left of the primary screen).
    var screenFrame: CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(
            x: axFrame.minX,
            y: primaryHeight - axFrame.maxY,
            width: axFrame.width,
            height: axFrame.height
        )
    }
}

enum SlackAccessibility {
    static let slackBundleID = "com.tinyspeck.slackmacgap"

    private static var electronAXEnabledPIDs = Set<pid_t>()

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that sends the user to Privacy & Security → Accessibility.
    static func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static var frontmostSlack: NSRunningApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == slackBundleID
        else { return nil }
        return app
    }

    /// Returns Slack's focused text input, if Slack is frontmost and a text input has focus.
    static func focusedComposer() -> Composer? {
        guard isTrusted, let slack = frontmostSlack else { return nil }
        let appElement = AXUIElementCreateApplication(slack.processIdentifier)
        enableElectronAccessibility(appElement, pid: slack.processIdentifier)

        guard let focused: AXUIElement = attribute(appElement, kAXFocusedUIElementAttribute),
              isTextInput(focused),
              let frame = frame(of: focused),
              frame.width > 40, frame.height > 8
        else { return nil }

        return Composer(element: focused, app: slack, axFrame: frame)
    }

    /// Reads the draft through Accessibility, falling back to copy-all when Slack does not expose a value.
    static func readText(of composer: Composer) -> String {
        if let value: String = attribute(composer.element, kAXValueAttribute),
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        return copySelectAll(in: composer)
    }

    /// Replaces the whole draft by selecting all and pasting, which Slack's editor handles
    /// like a normal paste: formatting is parsed and ⌘Z undoes it.
    static func replaceText(in composer: Composer, with text: String) {
        refocus(composer)
        let saved = PasteboardSnapshot.take()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            postKey(kVK_ANSI_A, flags: .maskCommand)
            postKey(kVK_ANSI_V, flags: .maskCommand)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                saved.restore()
            }
        }
    }

    // MARK: - Private

    /// Chromium-based apps build their accessibility tree only when asked.
    private static func enableElectronAccessibility(_ appElement: AXUIElement, pid: pid_t) {
        guard !electronAXEnabledPIDs.contains(pid) else { return }
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        electronAXEnabledPIDs.insert(pid)
    }

    private static func isTextInput(_ element: AXUIElement) -> Bool {
        let role: String? = attribute(element, kAXRoleAttribute)
        if role == kAXTextAreaRole || role == kAXTextFieldRole || role == kAXComboBoxRole {
            return true
        }
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        return result == .success && settable.boolValue
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue: AXValue = attribute(element, kAXPositionAttribute),
              let sizeValue: AXValue = attribute(element, kAXSizeAttribute)
        else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value
        else { return nil }
        return value as? T
    }

    private static func refocus(_ composer: Composer) {
        composer.app.activate()
        AXUIElementSetAttributeValue(composer.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    private static func copySelectAll(in composer: Composer) -> String {
        refocus(composer)
        let saved = PasteboardSnapshot.take()
        let pasteboard = NSPasteboard.general
        let before = pasteboard.changeCount

        postKey(kVK_ANSI_A, flags: .maskCommand)
        postKey(kVK_ANSI_C, flags: .maskCommand)

        // Give Slack a moment to write to the clipboard.
        let deadline = Date().addingTimeInterval(0.5)
        while pasteboard.changeCount == before && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        let copied = pasteboard.changeCount == before ? "" : (pasteboard.string(forType: .string) ?? "")
        saved.restore()
        return copied
    }

    private static func postKey(_ keyCode: Int, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

/// Saves and restores the user's clipboard around our own copy/paste.
struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func take() -> PasteboardSnapshot {
        let items = NSPasteboard.general.pasteboardItems?.map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        } ?? []
        return PasteboardSnapshot(items: items)
    }

    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let restored = items.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restored.isEmpty {
            pasteboard.writeObjects(restored)
        }
    }
}
