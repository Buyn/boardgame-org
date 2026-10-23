# boardgame.org — Interface & Full Specification Implementation Plan

Incorporating the full behavioral, frame, layout, command, drawing, navigation marker, and persistent logging requirements from `boardgame-org-interface.md` into the modular Emacs Lisp package in `src.el/` and updating the documentation in `readme.org` and the TypeScript reader.

## User Review & Critical Decisions

> [!IMPORTANT]
> Key decisions confirmed during Phase 1:
> - **Emacs Frame System Exclusively**: The dedicated game frame must be opened strictly via native Emacs frames (`make-frame`) without invoking external OS-level window manager tools or wrappers.
> - **Persistent World Log**: The side log is an ordinary, persistent Org file located at `<world-directory>/<world-name>-log.org`. Each log entry is structured as a level-1 Org heading (`* Entry title`) with nested subheadings (`** Details`), and the log is automatically saved on every board save.
> - **Precedence**: `boardgame-org-interface.md` takes precedence for user-visible interface behavior, command names, frame and window management, file creation workflows, drawing mode, and gameplay semantics, working in tandem with the core data architecture of `boardgame-org.md`.

---

## 1. Overview & Core Concept

1. **Emacs Dedicated Game Frame & Window Architecture**:
   - `boardgame-start` opens a dedicated Emacs frame (`make-frame`) preserving the user's existing editing frames.
   - **Board Window (~80% horizontal width)**: Non-wrapping, native text buffer scrolling for arbitrarily large felt boards with cursor tracking.
   - **Right Column (~20% horizontal width)** divided vertically into:
     - **Side Log Window (~80% vertical height)**: Displays the shared, editable, persistent `<world-name>-log.org` file. Lines wrap naturally; auto-scrolls on new log entries.
     - **Status Area Window (~20% vertical height)**: Separate buffer displaying active world, board, hand, cursor coordinates, selected object, and active drawing palette/mode.
2. **Canonical Command Names**:
   - World commands: `boardgame-start`, `boardgame-open-world`, `boardgame-create-world`, `boardgame-switch-world`, `boardgame-close-game`.
   - Board commands: `boardgame-open-board`, `boardgame-create-board`, `boardgame-open-board-other-frame`, `boardgame-switch-board`, `boardgame-save-board`, `boardgame-save-board-as`, `boardgame-close-board`, `boardgame-refresh-board`, `boardgame-execute-board-block`.
   - Object commands: `boardgame-open-object`, `boardgame-create-object`, `boardgame-add-object`, `boardgame-delete-object`, `boardgame-find-object`, `boardgame-describe-object`, `boardgame-describe-object-extended`, `boardgame-query-object-property`, `boardgame-execute-object-block`.
3. **ZZT-Style Drawing Mode**:
   - Minor mode `boardgame-drawing-mode` operating strictly on the felt layer.
   - Hides objects while painting to expose felt; restores objects when leaving drawing mode.
   - Color selection (foreground, background), recent symbols menu, point painting, continuous painting, pipette color/glyph sampling, and region filling.
   - **Text Mode (Overwrite Mode)**: Direct typing on the board replacing felt cells and advancing right one cell without shifting or inserting columns.
4. **General-Purpose Navigation & Navigation Markers**:
   - `boardgame-navigate-to-board-coord (board-filename x y)` moves the cursor to explicit coordinates on the target board (identified exclusively by filename).
   - `boardgame-create-marker`: Creates an object named `Marker (board filename) (x, y)` with glyph `^` (white on transparent felt background), storing `:DESTINATION_BOARD:`, `:DESTINATION_X:`, `:DESTINATION_Y:`, and an executable source block that reads these properties to teleport the cursor back!
5. **Hands as Org Stacks & Universal Transfer**:
   - `boardgame-place-heading-on-board`: Callable from any Org buffer to transfer the current heading subtree onto the active board at the cursor position (derives glyph from first letter if unset; fallback `*`).
   - `boardgame-take-object-to-hand`: Transfers the object under cursor into the active hand. If the cursor is over a container or stack, extracts the top contained item instead of taking the container itself.
6. **Global Active Board Tracking**:
   - `boardgame-current-board-buffer` variable reliably directs implicit board commands even across multiple frames.

---

## 2. Technical Architecture & File Layout in `src.el/`

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          boardgame-start [world]                            │
│                  (make-frame with dedicated game layout)                     │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         ▼                             ▼                             ▼
┌───────────────────┐        ┌───────────────────┐         ┌──────────────────┐
│   Board Window    │        │  Side Log Window  │         │  Status Window   │
│   (~80% width)    │        │(~20% w / ~80% h)  │         │(~20% w / ~20% h) │
│                   │        │                   │         │                  │
│ boardgame-mode    │        │ <world>-log.org   │         │ *boardgame-      │
│ Non-wrapping      │        │ Shared Org buffer │         │   status*        │
│ Native scrolling  │        │ Word-wrapping     │         │ Real-time stats  │
└───────────────────┘        └───────────────────┘         └──────────────────┘
```

### Module Responsibilities

1. **`src.el/boardgame-org-core.el`**:
   - User options (`defcustom`): `boardgame-default-world-directory`, `boardgame-board-window-width-percent`, `boardgame-log-window-height-percent`, `boardgame-default-felt-symbol`, `boardgame-auto-commit`.
   - Global active tracking: `boardgame-current-board-buffer`, `boardgame-active-world-directory`.
   - Core structs and Git versioning helpers.
2. **`src.el/boardgame-org-log.el`**:
   - Shared persistent log `<world-name>-log.org`.
   - Logging API: `boardgame-log (title &optional subtitle-alist body)`. Formats with `* ` headings and `** ` details.
   - Shared across all frames and boards of the active world; saved whenever any board is saved.
3. **`src.el/boardgame-org-frame.el`**:
   - `boardgame-setup-game-frame`: Uses `make-frame` to open a dedicated Emacs frame, splits windows into 80/20 board/side layout, splits side column vertically (80% log, 20% status).
   - Frame and window tracking so multiple boards/frames work cleanly.
4. **`src.el/boardgame-org-status.el`**:
   - Status buffer renderer: active world, active board file, active hand, cursor coordinates, top object glyph/name/properties, drawing mode state and palette.
5. **`src.el/boardgame-org-drawing.el`**:
   - `boardgame-drawing-mode`: Minor mode hiding objects to paint felt.
   - Pipette (`boardgame-pipette`): samples felt character, foreground, background.
   - Point painting, continuous painting, recent-symbols menu.
   - `boardgame-text-mode`: Overwrite typing on the felt without expanding dimensions.
6. **`src.el/boardgame-org-marker.el`**:
   - `boardgame-navigate-to-board-coord (board-filename x y)`: General cursor navigation.
   - `boardgame-create-marker`: Generates `Marker <board> (x, y)` object with glyph `^`, properties, and parameterized source block.
7. **`src.el/boardgame-org-board.el`**:
   - Felt normalization (4.6), board load/save/save-as, cell coordinate lookup, count indicators (`1`-`9`, `+`).
8. **`src.el/boardgame-org-object.el`**:
   - Org document parsing, property drawers, source-block execution (`boardgame-execute-object-block`, `boardgame-execute-board-block`), descriptions.
9. **`src.el/boardgame-org-stack.el` & `src.el/boardgame-org-container.el`**:
   - Stack consolidation (deletes individual files) and container references (preserves files), shuffle, draw, layout.
10. **`src.el/boardgame-org-hand.el`**:
    - Hand as Org file; `boardgame-place-heading-on-board` (usable in any Org buffer); `boardgame-take-object-to-hand` (taking from container/stack extracts top item).
11. **`src.el/boardgame-org.el`**:
    - Main entry point with all canonical interactive commands matching Section 2 of `boardgame-org-interface.md`.
12. **`src.el/boardgame-org-test.el`**:
    - ERT regression test suite covering all Section 15 acceptance criteria.
13. **`readme.org` & `src/readmeContent.ts`**:
    - Fully updated documentation explaining all new interface features, frame layout, drawing mode, navigation markers, and command list.

---

## 3. Plan Execution Sequence

1. Update `src.el/boardgame-org-core.el` with canonical variables and options.
2. Create `src.el/boardgame-org-log.el` for persistent Org logging.
3. Create `src.el/boardgame-org-status.el` for real-time status window display.
4. Create `src.el/boardgame-org-frame.el` for native Emacs frame setup and window proportions.
5. Create `src.el/boardgame-org-drawing.el` for ZZT felt painting, pipette, and text mode.
6. Create `src.el/boardgame-org-marker.el` for cursor navigation and navigation markers.
7. Update `src.el/boardgame-org-board.el`, `src.el/boardgame-org-hand.el`, `src.el/boardgame-org-object.el`, and `src.el/boardgame-org-container.el`.
8. Update `src.el/boardgame-org.el` with all canonical commands and keymap.
9. Update `src.el/boardgame-org-test.el` with comprehensive ERT tests.
10. Update `readme.org` and sync `src/readmeContent.ts`.
11. Run `compile_applet` and verify server health on port 3000.
