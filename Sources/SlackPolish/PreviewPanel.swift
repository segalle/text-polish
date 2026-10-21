import AppKit
import SwiftUI

@MainActor
final class PreviewModel: ObservableObject {
    @Published var original: String
    @Published var options: [String] = []
    @Published var selected = 0
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
                options = result
                selected = 0
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

    /// The chosen suggestion, including any edits the user made to it.
    var chosen: String {
        options.indices.contains(selected) ? options[selected] : ""
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
        let height: CGFloat = Settings.shared.suggestionCount > 1 ? 480 : 360
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

            Text(model.options.count > 1 ? "Suggestions: pick one, edit it if needed" : "Rewrite")
                .font(.caption)
                .foregroundStyle(.secondary)
            ZStack {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.options.indices, id: \.self) { index in
                            OptionCard(
                                text: $model.options[index],
                                isSelected: index == model.selected,
                                onSelect: { model.selected = index }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    NSPasteboard.general.setString(model.chosen, forType: .string)
                }
                .disabled(model.chosen.isEmpty || model.isLoading)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Replace draft") { onReplace(model.chosen) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.chosen.isEmpty || model.isLoading)
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

/// One suggestion. The selected card is editable; the others are a click away from being chosen.
private struct OptionCard: View {
    @Binding var text: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Group {
            if isSelected {
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 70, maxHeight: 160)
            } else {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onSelect)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
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
