# Slack Polish

A small macOS menu-bar app that rewrites your Slack draft with Claude, OpenAI or a local
Ollama model, then puts it back in the message box only after you approve it. It never sends
a message.

- **✨ button** pinned to the right edge of Slack's message box whenever it has focus.
- **⌘⇧P** while Slack is in front. The shortcut is only registered while Slack is the active
  app, so ⌘⇧P still works normally in VS Code and everywhere else.
- **Preview panel**: original draft, editable rewrite, tone picker (Professional, Friendly,
  Concise, Fix grammar), Copy / Cancel / Replace draft. `Esc` cancels, `Return` replaces.
- **Keys in the Keychain**: one generic-password item per provider, service
  `com.local.slackpolish`. Other settings are in `UserDefaults`.

No Slack app, OAuth or workspace admin approval is needed. It works on the Slack desktop app
through macOS Accessibility.

## Build and install

Requires macOS 13+ and the Swift toolchain (Xcode or just the Command Line Tools).

```bash
./scripts/build-app.sh          # -> build/SlackPolish.app
cp -R build/SlackPolish.app /Applications/
open /Applications/SlackPolish.app
```

## First run

1. **Accessibility.** On launch macOS asks for Accessibility access. Enable **Slack Polish** in
   System Settings → Privacy & Security → Accessibility. It is needed to find Slack's message
   box, read the draft and paste the rewrite.
2. **Settings** (menu bar ✨ → Settings…): pick a provider, paste your API key, Save.
   - Claude: create a key at console.anthropic.com. API usage is billed separately from
     Claude Pro/Max subscriptions.
   - OpenAI: create a key at platform.openai.com. Also billed separately from ChatGPT Plus.
   - Ollama: no key. Run `ollama pull llama3.2` and keep Ollama running. Drafts never leave
     your Mac.
3. Optional: set a default tone and your own style notes ("American English, no exclamation
   marks").

## Use

Type in Slack → click ✨ (or press ⌘⇧P) → check or edit the rewrite → **Replace draft**.
Undo in Slack with ⌘Z if you change your mind.

## Models

| Provider | Default model | Change it in Settings → Model |
|---|---|---|
| Claude | `claude-opus-5-5` (low effort) | `claude-haiku-5-5` is far cheaper and fine for short messages |
| OpenAI | `gpt-5-mini` | Any chat-completions model |
| Ollama | `llama3.2` | Any model you've pulled |

## How it works

| File | Role |
|---|---|
| `SlackAccessibility.swift` | Finds Slack's focused text input (`AXFocusedUIElement`), its frame, reads `AXValue`, and replaces it by select-all + paste. Switches on `AXManualAccessibility`, which Electron apps like Slack need before they expose their UI tree. |
| `FloatingButton.swift` | Non-activating panel that follows the message box (polls every 0.3s, only while Slack is in front), so clicking it never takes focus from Slack. |
| `PreviewPanel.swift` | The approve-before-replace panel. |
| `Polisher.swift` | Prompt and HTTP calls: Claude Messages API, OpenAI-compatible chat completions (OpenAI and Ollama). |
| `HotKey.swift` | Carbon global hotkey, registered only while Slack is frontmost. |
| `Keychain.swift`, `Settings.swift`, `SettingsView.swift` | Configuration. |

Replacement pastes instead of setting `AXValue` directly. Slack's rich-text editor tends to ignore
or desync on a direct value set, but it handles a paste like normal typing, including ⌘Z undo.
Your clipboard is saved and restored around the paste.

## Known limits

- **Mentions turn into plain text.** A linked `@Erez` in the draft is read back as the text
  `@Erez`. After pasting, Slack may not re-link it. Re-type the mention if needed.
- **Formatting**: rich formatting is read as plain text. Slack markdown in the rewrite
  (`*bold*`, `` `code` ``) gets converted again on paste.
- **Rebuilding resets Accessibility** with the default ad-hoc signature. Toggle Slack Polish off
  and on in the Accessibility list after each rebuild, or build with a stable identity:
  `SIGN_IDENTITY="Apple Development: …" ./scripts/build-app.sh`.
- **Button position** comes from Slack's accessibility frame. If a Slack update moves things,
  adjust the offset in `FloatingButtonController.tick()`.

## Troubleshooting

- **Beep, nothing happens**: either the cursor isn't in a Slack message box or the draft is empty.
  Click into the box first.
- **No ✨ button**: check Accessibility access (Settings shows a status line), and that "Show the
  ✨ button" is on. Quit and reopen Slack once after granting access.
- **"rejected the API key" / "doesn't know that model"**: fix the key or model name in Settings.
