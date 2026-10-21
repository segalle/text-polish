import AppKit

/// A menu-bar app has no Edit menu, and the Edit menu is what normally turns ⌘V, ⌘C, ⌘X,
/// ⌘A and ⌘Z into actions. Our windows route those keys to the focused text field themselves.
enum EditShortcuts {
    static func handle(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        let action: Selector?
        switch (flags, key) {
        case (.command, "x"): action = #selector(NSText.cut(_:))
        case (.command, "c"): action = #selector(NSText.copy(_:))
        case (.command, "v"): action = #selector(NSText.paste(_:))
        case (.command, "a"): action = #selector(NSResponder.selectAll(_:))
        case (.command, "z"): action = Selector(("undo:"))
        case ([.command, .shift], "z"): action = Selector(("redo:"))
        default: action = nil
        }
        guard let action else { return false }
        return NSApp.sendAction(action, to: nil, from: nil)
    }
}

/// The settings window, with working edit shortcuts.
final class EditableWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        EditShortcuts.handle(event) || super.performKeyEquivalent(with: event)
    }
}
