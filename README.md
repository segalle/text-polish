# Text Polish

A small macOS menu-bar app that rewrites what you're typing with Claude, OpenAI or a local
Ollama model, and puts the rewrite back only after you approve it. It never sends anything.

**Supported apps today: the Slack desktop app.** More apps are planned. The approach (macOS
Accessibility) works for any app with a standard text box.

- **✨ button** pinned to the right edge of the message box whenever it has focus.
- **⌘⇧P** while Slack is in front. The shortcut is only active while Slack is the frontmost
  app, so ⌘⇧P keeps working normally in VS Code and everywhere else.
- **Preview panel**: your original text, 1–3 suggestions as separate cards (click one to pick
  it, edit it in place), a tone picker (Professional, Friendly, Concise, Fix grammar), and
  Copy / Cancel / Replace draft. Only the picked suggestion goes back into the app.
- **Your own keys, kept in the macOS Keychain.** Nothing goes anywhere except the model provider
  you choose, and nothing leaves your Mac at all with Ollama.

No Slack app, OAuth or workspace-admin approval is needed.

## Install

Requirements: macOS 13 or later, and Apple's Swift toolchain. Xcode works; the free Command Line
Tools are enough:

```bash
xcode-select --install   # skip if you already have Xcode or the Command Line Tools
```

Then build and install:

```bash
git clone https://github.com/segalle/text-polish.git
cd text-polish
./scripts/install.sh
```

`install.sh` builds the app, copies it to `/Applications/TextPolish.app` and opens it. Run it
again whenever you pull new changes.

### First run

1. **Allow Accessibility.** macOS asks the first time. Turn on **Text Polish** in System Settings
   → Privacy & Security → Accessibility. It's how the app finds the message box, reads your
   draft and pastes the rewrite. If no prompt appears, add `/Applications/TextPolish.app` there
   with **+**.
2. **Add a model.** Click the ✨ icon in the menu bar → **Settings…**, choose a provider, paste
   your API key and click **Save**, then pick a model from the dropdown.
   - **Claude**: get a key at [console.anthropic.com](https://console.anthropic.com). API usage
     is billed separately from Claude Pro/Max subscriptions.
   - **OpenAI**: get a key at [platform.openai.com](https://platform.openai.com). Also billed
     separately from ChatGPT Plus.
   - **Ollama**: no key and no cost. Install [Ollama](https://ollama.com), run
     `ollama pull llama3.2`, and keep it running.
3. **Optional:** set a default tone, how many suggestions you want, and your own style notes
   (for example "American English. No exclamation marks.").
4. Quit and reopen Slack once, so it exposes its message box to Accessibility.

## Use

Type in Slack → click ✨ (or press ⌘⇧P) → pick a suggestion and edit it if you like →
**Replace draft** (or press Return). `Esc` cancels. Undo in Slack with ⌘Z.

## Models

The Model dropdown lists the models your key (or your local Ollama) can use, fetched live. ↻
refreshes the list, and **Custom…** takes any model ID.

| Provider | Default model | Notes |
|---|---|---|
| Claude | `claude-opus-5-5` (low effort) | `claude-haiku-5-5` is far cheaper and plenty for short messages |
| OpenAI | `gpt-5-mini` | Any chat-completions model |
| Ollama | `llama3.2` | Any model you've pulled |

## Troubleshooting

- **No menu-bar icon.** macOS hides menu-bar icons behind the camera notch when the bar is full,
  and macOS 26 can turn icons off in System Settings → Menu Bar. Opening Text Polish again from
  Spotlight shows Settings either way.
- **No ✨ button in Slack.** Check that Settings shows "Accessibility access is on" and that "Show
  the ✨ button" is on, then quit and reopen Slack once.
- **Worked before, stopped after a rebuild.** See "Rebuilding" below. Run `./scripts/install.sh`
  rather than copying the app by hand.
- **A beep and nothing happens.** The cursor isn't in a message box, or the box is empty.
- **"rejected the API key" / "doesn't know that model".** Fix the key or the model in Settings.

## Known limits

- **Mentions come back as plain text.** A linked `@name` is read as the text `@name`, and Slack
  may not re-link it after the paste. Re-type the mention if needed.
- **Rich formatting is read as plain text.** Slack markdown in the rewrite (`*bold*`,
  `` `code` ``) is converted again when pasted.
- **Rebuilding needs a new Accessibility grant.** The build is signed ad hoc, so macOS treats each
  build as a new app, and switching the old entry off and on does *not* move the permission over.
  `install.sh` clears the old entry so macOS asks again. With an Apple Development certificate
  the permission survives rebuilds:
  `SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./scripts/install.sh`.
- **Button position** comes from Slack's accessibility frame. If a Slack update moves things,
  adjust the offset in `FloatingButtonController.tick()`.

## How it works

| File | Role |
|---|---|
| `SlackAccessibility.swift` | Finds Slack's focused text box (`AXFocusedUIElement`) and its frame, reads `AXValue`, and replaces the text by select-all + paste. Turns on `AXManualAccessibility`, which Electron apps like Slack need before they expose their UI. |
| `FloatingButton.swift` | A panel that never takes focus and follows the message box (checks every 0.3 s, only while Slack is in front). |
| `PreviewPanel.swift` | The approve-before-replace panel with suggestion cards. |
| `Polisher.swift` | The prompt and HTTP calls: the Claude Messages API, and OpenAI-compatible chat completions for OpenAI and Ollama. |
| `ModelCatalog.swift` | Fills the model dropdown from each provider's models endpoint. |
| `HotKey.swift` | The ⌘⇧P global hotkey, registered only while Slack is in front. |
| `EditShortcuts.swift` | ⌘X/C/V/A/Z in the app's windows. A menu-bar app has no Edit menu, which normally handles them. |
| `Keychain.swift`, `Settings.swift`, `SettingsView.swift` | Configuration. API keys are Keychain items under service `com.local.textpolish`; everything else is in `UserDefaults`. |

The rewrite is pasted rather than written into the text box directly. Slack's rich-text editor
tends to ignore or desync on a direct write, but handles a paste like normal typing, including
⌘Z undo. Your clipboard is saved and restored around the paste.
