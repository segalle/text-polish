import AppKit
import SwiftUI

@MainActor
final class PreviewModel: ObservableObject {
    @Published var original: String
    @Published var rewrite = ""
    @Published var tone: Tone
    @Published var isLoading = false
    @Published var error: String?

    private var task: Task<Void, Never>?

    init(original: String, tone: Tone) {
        self.original = original
        self.tone = tone
    }

    func run() {
        task?.cancel()
        isLoading = true
        error = nil
        let draft = original
        let tone = tone
        task = Task {
            do {
                let result = try await Polisher.polish(draft, tone: tone, settings: Settings.shared)
                guard !Task.isCancelled else { return }
                rewrite = result
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    func cancel() {
        task?.cancel()
    }
}

/// Shows the original draft and the rewrite. Nothing touches Slack until "Replace draft".
final class PreviewPanelController {
    private var panel: NonActivatingPanel?
    private var model: PreviewModel?

    @MainActor
    func show(draft: String, near composer: Composer, onReplace: @escaping (String) -> Void) {
        close()
        let model = PreviewModel(original: draft, tone: Settings.shared.defaultTone)
        self.model = model

        let width: CGFloat = 480
        let height: CGFloat = 360
        let panel = NonActivatingPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height), canBecomeKey: true)
        let view = PreviewView(
            model: model,
            onReplace: { [weak self] text in
                self?.close()
                onReplace(text)
            },
            onCancel: { [weak self] in self?.close() }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.setFrameOrigin(origin(for: composer.screenFrame, size: CGSize(width: width, height: height)))
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel

        model.run()
    }

    @MainActor
    func close() {
        model?.cancel()
        model = nil
        panel?.orderOut(nil)
        panel = nil
    }

    /// Above the composer, right-aligned with it, clamped to the visible screen.
    private func origin(for anchor: CGRect, size: CGSize) -> CGPoint {
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var x = anchor.maxX - size.width
        var y = anchor.maxY + 8
        if y + size.height > visible.maxY {
            y = anchor.minY - size.height - 8
        }
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        y = min(max(y, visible.minY + 8), visible.maxY - size.height - 8)
        return CGPoint(x: x, y: y)
    }
}

private struct PreviewView: View {
    @ObservedObject var model: PreviewModel
    let onReplace: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Polish draft", systemImage: "wand.and.stars")
                    .font(.headline)
                Spacer()
                Picker("Tone", selection: $model.tone) {
                    ForEach(Tone.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 140)
                .onChange(of: model.tone) { _ in model.run() }
            }

            Text("Original")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView {
                Text(model.original)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 70)

            Text("Rewrite")
                .font(.caption)
                .foregroundStyle(.secondary)
            ZStack {
                TextEditor(text: $model.rewrite)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    .opacity(model.isLoading ? 0.4 : 1)
                    .disabled(model.isLoading)
                if model.isLoading {
                    ProgressView("Polishing…")
                        .controlSize(.small)
                } else if let error = model.error {
                    VStack(spacing: 8) {
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.red)
                        Button("Retry") { model.run() }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .windowBackgroundColor)))
                }
            }

            HStack {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.rewrite, forType: .string)
                }
                .disabled(model.rewrite.isEmpty || model.isLoading)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Replace draft") { onReplace(model.rewrite) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.rewrite.isEmpty || model.isLoading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffect()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
    }
}

private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
