import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var floatingButton: FloatingButtonController!
    private let preview = PreviewPanelController()
    private var hotKey: HotKey!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()

        floatingButton = FloatingButtonController { [weak self] in
            Task { @MainActor in self?.polishCurrentDraft() }
        }
        hotKey = HotKey(keyCode: kVK_ANSI_P, modifiers: cmdKey | shiftKey) { [weak self] in
            Task { @MainActor in self?.polishCurrentDraft() }
        }

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(frontmostAppChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        frontmostAppChanged()

        if !SlackAccessibility.isTrusted {
            SlackAccessibility.requestTrust()
            showSettings()
        }
    }

    /// Track Slack only while it is in front: the button polls and the hotkey is live just then.
    @objc private func frontmostAppChanged() {
        if SlackAccessibility.frontmostSlack != nil {
            hotKey.register()
            floatingButton.start()
        } else {
            hotKey.unregister()
            floatingButton.stop()
        }
    }

    private func polishCurrentDraft() {
        guard SlackAccessibility.isTrusted else {
            SlackAccessibility.requestTrust()
            showSettings()
            return
        }
        guard let composer = SlackAccessibility.focusedComposer() else {
            NSSound.beep()
            return
        }
        let draft = SlackAccessibility.readText(of: composer).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else {
            NSSound.beep()
            return
        }
        preview.show(draft: draft, near: composer) { rewrite in
            SlackAccessibility.replaceText(in: composer, with: rewrite)
        }
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Slack Polish")

        let menu = NSMenu()
        let polish = NSMenuItem(title: "Polish Slack draft  ⌘⇧P", action: #selector(menuPolish), keyEquivalent: "")
        polish.target = self
        menu.addItem(polish)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(menuSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Slack Polish", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func menuPolish() {
        // The menu bar steals focus; hand it back to Slack before reading the draft.
        guard let slack = NSRunningApplication.runningApplications(withBundleIdentifier: SlackAccessibility.slackBundleID).first else {
            NSSound.beep()
            return
        }
        slack.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.polishCurrentDraft()
        }
    }

    @objc private func menuSettings() {
        showSettings()
    }

    private func showSettings() {
        if settingsWindow == nil {
            let window = EditableWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Slack Polish Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
