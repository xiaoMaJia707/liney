# Design: Dynamic Island Notifications

**Status**: Proposal  
**Priority**: P1  

## Problem

Liney currently uses macOS system notifications (`UNUserNotificationCenter`) for events like worktree/terminal task completion. This has two limitations:

1. **No workspace navigation on click** — clicking a system notification does not jump to the relevant workspace, worktree, or terminal pane. Users must manually locate the finished task in the sidebar.
2. **Limited richness** — system notifications are plain text with no interactive elements. They cannot show workspace status, quick actions, or sidebar-like context.

## Proposal

Introduce a **Dynamic Island–style notification panel** anchored to the macOS notch area (top-center of screen). This replaces system notifications with a richer, app-owned notification surface when enabled.

### Design Principles

- **Off by default** — new setting `dynamicIslandNotificationsEnabled` in AppSettings, default `false`. When disabled, existing system notification behavior is unchanged.
- **When enabled, replaces system notifications** — `WorkspaceNotificationCenter` routes to the Dynamic Island panel instead of `UNUserNotificationCenter`.
- **Click-to-navigate** — every notification item is tappable and navigates to the corresponding workspace + worktree + pane.
- **Graceful degradation** — on Macs without a notch (external displays, older models), the panel still anchors to top-center as a floating HUD.

## UI Design

### Collapsed State (Idle Bar)

When there are pending notifications but the panel is not expanded:

```
┌─────────────────────────────────────────┐
│  🤖 fix auth bug                    [3] │
└─────────────────────────────────────────┘
```

- Shows the most recent notification title with the workspace/agent icon
- Badge `[3]` shows total pending notification count
- Click to expand; auto-collapses after configurable timeout

### Expanded State (Notification List)

Click or hover to expand into a panel showing all active items:

```
┌─────────────────────────────────────────────────────┐
│  🤖 fix auth bug              Claude  iTerm    28m  │
│     You: fix the auth bug in middleware              │
│     Done — click to jump                            │
│                                                     │
│  ● backend server             Codex   Terminal  1h  │
│  ● optimize queries           Gemini  Ghostty   5h  │
└─────────────────────────────────────────────────────┘
```

Each row shows:
- **Agent/workspace icon** — from sidebar icon settings
- **Task name** — workspace name or worktree display name
- **Tags** — agent type (Claude, Codex, Gemini) + terminal app (iTerm, Terminal, Ghostty)
- **Elapsed time** — since task started
- **Status indicator** — running (colored dot) / done (highlighted card)
- **Click action** — navigates to that workspace + worktree, brings window to front

### Interactive Prompt State

When an agent asks a question that requires user input:

```
┌─────────────────────────────────────────────────────┐
│  📁 Claude asks                                     │
│                                                     │
│  Which deployment target?                           │
│                                                     │
│  [⌘1] Production                                    │
│  [⌘2] Staging                                       │
│  [⌘3] Local only                                    │
└─────────────────────────────────────────────────────┘
```

- Quick-select via keyboard shortcuts (⌘1, ⌘2, ⌘3)
- Clicking an option sends the response and navigates to the workspace
- Falls back to "click to jump" if the prompt is too complex for inline display

## Architecture

### New Components

```
Liney/
├── UI/
│   └── DynamicIsland/
│       ├── DynamicIslandWindowController.swift   — NSPanel/NSWindow management
│       ├── DynamicIslandContentView.swift         — SwiftUI root view
│       ├── DynamicIslandCollapsedView.swift        — Collapsed bar UI
│       ├── DynamicIslandExpandedView.swift         — Expanded notification list
│       └── DynamicIslandPromptView.swift           — Interactive prompt UI
├── Domain/
│   └── DynamicIslandState.swift                    — Observable state model
└── Support/
    └── NotchGeometry.swift                         — Screen notch detection & positioning
```

### Key Design Decisions

#### 1. Window Management

Use a borderless, floating `NSPanel` (`.nonactivatingPanel` style) positioned at the top-center of the main screen. Key properties:

- `level: .statusBar` — floats above app windows but below system UI
- `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]` — visible across spaces
- `isMovableByWindowBackground: false` — locked to notch position
- `hasShadow: true` with custom shadow for the dark floating appearance
- `backgroundColor: .clear` with a custom `NSVisualEffectView` for the dark translucent material

The panel uses `NSHostingView` to embed SwiftUI content.

#### 2. State Model

```swift
@MainActor
final class DynamicIslandState: ObservableObject {
    @Published var items: [DynamicIslandItem] = []
    @Published var isExpanded: Bool = false
    @Published var activePrompt: DynamicIslandPrompt? = nil
}

struct DynamicIslandItem: Identifiable {
    let id: UUID
    let workspaceID: UUID
    let worktreeID: UUID?
    let paneID: UUID?
    let title: String
    let subtitle: String?
    let agentTag: String?       // "Claude", "Codex", "Gemini"
    let terminalTag: String?    // "iTerm", "Terminal", "Ghostty"
    let startTime: Date
    let tone: WorkspaceStatusMessage.Tone  // neutral, success, warning
    let isDone: Bool
}

struct DynamicIslandPrompt: Identifiable {
    let id: UUID
    let workspaceID: UUID
    let question: String
    let options: [String]
}
```

#### 3. Integration with WorkspaceNotificationCenter

Modify `WorkspaceNotificationCenter.deliver(...)` to check `appSettings.dynamicIslandNotificationsEnabled`:

- **If enabled**: route to `DynamicIslandState.shared` to add/update items
- **If disabled**: use current `UNUserNotificationCenter` path (unchanged)

Add a new method for richer notifications:

```swift
func deliver(
    title: String,
    body: String?,
    workspaceID: UUID,
    worktreeID: UUID? = nil,
    paneID: UUID? = nil,
    agentTag: String? = nil,
    terminalTag: String? = nil,
    tone: WorkspaceStatusMessage.Tone = .neutral,
    isDone: Bool = false
)
```

#### 4. Navigation on Click

When a notification item is clicked:

1. Find the `LineyDesktopApplication` window containing the target workspace
2. Call `workspaceStore.dispatch(.selectWorkspace(id:))` to switch sidebar selection
3. If `worktreeID` is provided, switch to that worktree tab
4. If `paneID` is provided, focus that pane
5. Bring the window to front with `window.makeKeyAndOrderFront(nil)`
6. Collapse the Dynamic Island panel

This also fixes the existing system notification click-to-navigate gap — implement `UNUserNotificationCenterDelegate.didReceive` to perform the same navigation when system notifications are used.

#### 5. Notch Geometry

```swift
struct NotchGeometry {
    /// Returns the notch rect on the main screen, or a fallback center-top rect
    static func notchFrame(for screen: NSScreen) -> NSRect {
        // On notched displays: use screen.auxiliaryTopLeftArea / auxiliaryTopRightArea
        // to infer notch bounds
        // On non-notch displays: return a centered rect at top of screen
    }
}
```

Use `NSScreen.main?.auxiliaryTopLeftArea` and `auxiliaryTopRightArea` (macOS 12+) to detect notch presence and compute panel position.

#### 6. Sidebar Mirror Mode

An optional expansion mode that mirrors the full sidebar content in the Dynamic Island panel:

- Triggered by long-press or a dedicated keyboard shortcut
- Shows all workspace groups, workspaces, and worktrees with status indicators
- Each item clickable to navigate
- Useful for quick workspace switching without the main window

This is a stretch goal and can be implemented after the core notification flow.

### Settings Addition

Add to `AppSettings`:

```swift
/// When enabled, uses Dynamic Island–style notifications instead of system notifications.
/// Default: false
var dynamicIslandNotificationsEnabled: Bool = false
```

Add a new row in Settings → General section, below the existing "System Notifications" toggle:

```
[Toggle] Dynamic Island Notifications
         Use notch-area notifications with click-to-navigate.
         (Replaces system notifications when enabled)
```

### Fix: System Notification Click-to-Navigate

Regardless of the Dynamic Island feature, fix the existing system notification behavior:

1. Implement `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)` in `WorkspaceNotificationCenter`
2. Encode `workspaceID` (and optionally `worktreeID`, `paneID`) in the notification's `userInfo` dictionary when creating `UNNotificationContent`
3. On notification click, extract these IDs and perform workspace navigation (same logic as Dynamic Island click)

This fix ships independently and benefits all users, not just those who enable Dynamic Island.

## Implementation Phases

### Phase 1: System Notification Click-to-Navigate
- Add `userInfo` with workspace/worktree IDs to `UNNotificationContent`
- Implement `didReceive` delegate to navigate on click
- No UI changes, no new settings

### Phase 2: Core Dynamic Island Panel
- `DynamicIslandWindowController` with notch-aware positioning
- Collapsed bar showing latest notification
- Expanded list showing all pending items
- Click-to-navigate for each item
- Settings toggle (default off)

### Phase 3: Rich Notifications
- Agent/terminal tags
- Elapsed time display
- Status indicators (running/done)
- Auto-collapse timer

### Phase 4: Interactive Prompts
- Inline prompt display for agent questions
- Quick-select keyboard shortcuts
- Prompt forwarding to workspace

### Phase 5: Sidebar Mirror (Stretch)
- Full sidebar content in expanded panel
- Workspace group rendering
- Drag/drop support (future)

## References

- [NotchNotification](https://github.com/Lakr233/NotchNotification) — SwiftUI-based notch notification framework (MIT)
- [NotchDrop](https://github.com/Lakr233/NotchDrop) — Notch-area file management app
- `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` — macOS 12+ notch detection
- Current notification code: `Liney/Support/WorkspaceNotificationCenter.swift`
- Current settings: `Liney/Domain/AppSettings.swift`
