import AppKit
import SwiftUI

/// A panel that never takes focus, so clicking it leaves the cursor in Slack's composer.
final class NonActivatingPanel: NSPanel {
    init(contentRect: NSRect, canBecomeKey: Bool) {
        allowsKey = canBecomeKey
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    private let allowsKey: Bool
    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }
}

/// Watches Slack's focused composer and pins a small ✨ button to its right edge.
final class FloatingButtonController {
    private let size: CGFloat = 26
    private let panel: NonActivatingPanel
    private var timer: Timer?
    private let onClick: () -> Void

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        panel = NonActivatingPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size), canBecomeKey: false)
        let button = PolishButton(size: size) { [weak self] in self?.onClick() }
        panel.contentView = NSHostingView(rootView: button)
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        panel.orderOut(nil)
    }

    private func tick() {
        guard Settings.shared.showFloatingButton,
              let composer = SlackAccessibility.focusedComposer()
        else {
            panel.orderOut(nil)
            return
        }
        let frame = composer.screenFrame
        // Right edge of the text area, level with its first line.
        let firstLine = min(frame.height, 24)
        let origin = CGPoint(
            x: frame.maxX - size - 4,
            y: frame.maxY - firstLine / 2 - size / 2
        )
        if panel.frame.origin != origin {
            panel.setFrameOrigin(origin)
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }
}

private struct PolishButton: View {
    let size: CGFloat
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(Color.purple.opacity(hovering ? 1 : 0.85))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Polish this draft (⌘⇧P)")
    }
}
