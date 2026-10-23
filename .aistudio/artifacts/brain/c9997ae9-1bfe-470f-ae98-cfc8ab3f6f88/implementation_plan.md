# boardgame.org — Full MELPA/ELPA Compliant Package & Interface Plan

Implementation of the complete, modular Emacs Lisp package in `src.el/` with MELPA/ELPA standard packaging headers, autoload cookies, project-local `./world/` default storage, and strict adherence to both `boardgame-org.md` and `boardgame-org-interface.md`, accompanied by `readme.org` and the TypeScript interactive documentation reader.

## User Review & Critical Decisions

> [!IMPORTANT]
> Decisions confirmed in Phase 1:
> - **Default World Location**: Configured to project-local `./world/` directory out of the box (`boardgame-default-world-directory` defaults to `(expand-file-name "world" (file-name-directory (or load-file-name buffer-file-name default-directory)))`), allowing instant zero-setup play and testing.
> - **Packaging Standards**: Full MELPA/ELPA compliant package headers across all `src.el/*.el` files (`;;; Package-Requires: ((emacs "27.1") (org "9.3"))`, `;;; Commentary:`, `;;; Code:`, `;;;###autoload` cookies on all canonical commands, and proper `provide` statements).
> - **Interface & Behavior**: Native dedicated Emacs frame (`make-frame`) with 3-window layout (80% board / 20% right side with 80% log & 20% status), persistent world log `<world-name>-log.org`, ZZT felt drawing mode & text overwrite mode, navigation markers (`^`), stacks (`$` black on white) vs permanent containers, and universal Org heading placement.
> - **TypeScript Application**: Dedicated purely to displaying the `readme.org` documentation in an Emacs Doom-One aesthetic.

---

## 1. Overview & Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Dedicated Emacs Game Frame                            │
│ ┌───────────────────────────────────────┬─────────────────────────────────┐ │
│ │             Board Window              │        Right Column (20%)       │ │
│ │                 (80%)                 ├─────────────────────────────────┤ │
│ │                                       │      Side Log Window (80%)      │ │
│ │ - Ordinary Emacs text buffer          │ - <world-name>-log.org          │ │
│ │ - Non-wrapping lines                  │ - Editable Org document         │ │
│ │ - Native horizontal/vertical scroll   │ - Level-1 * Entry headings      │ │
│ │ - Felt normalization (Section 4.6)    │ - Auto-saved on board save      │ │
│ │ - Multi-object count badges (1-9, +)  ├─────────────────────────────────┤ │
│ │ - ZZT drawing & text overwrite modes  │       Status Window (20%)       │ │
│ │                                       │ - *boardgame-status* buffer     │ │
│ │                                       │ - World, Board, Hand, Coords    │ │
│ └───────────────────────────────────────┴─────────────────────────────────┘ │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ persists to
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Active World Directory                             │
│                              (./world/)                                     │
│  ├── <world-name>-log.org   (Shared persistent world event log)             │
│  ├── boards/                (Board Org files with #+begin_src felt)         │
│  ├── objects/               (Standalone Org object files)                   │
│  ├── stacks/                (Consolidated stack Org documents: '$')         │
│  ├── containers/            (Permanent containers with file references)     │
│  └── hands/                 (Player hand Org documents: hands/<player>.org) │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Modular File Structure in `src.el/`

1. **`src.el/boardgame-org-core.el`**:
   - Defcustoms: `boardgame-default-world-directory` (defaults to `./world/`), `boardgame-default-felt-symbol`, `boardgame-board-window-width-percent`, `boardgame-log-window-height-percent`, `boardgame-auto-commit`.
   - Global active tracking: `boardgame-current-board-buffer`, `boardgame-active-world-directory`.
   - Struct definitions (`cl-defstruct`) for `boardgame-board`, `boardgame-object`, `boardgame-placed`, `boardgame-hand`.
   - Git commit helpers.
2. **`src.el/boardgame-org-log.el`**:
   - Shared persistent log `<world-name>-log.org`.
   - `boardgame-log (title &optional subtitle-alist body)` inserting `* Entry` and `** Details`.
   - Auto-scroll to newest entry; saved on every board save.
3. **`src.el/boardgame-org-status.el`**:
   - Status buffer `*boardgame-status*` showing current world, board, coordinates, object, and drawing tool.
4. **`src.el/boardgame-org-frame.el`**:
   - `boardgame-setup-game-frame`: Opens dedicated Emacs frame with 3-window layout.
   - Frame-local board association and switching.
5. **`src.el/boardgame-org-drawing.el`**:
   - `boardgame-drawing-mode`: Minor mode hiding objects to expose and paint felt directly.
   - Pipette tool (`boardgame-pipette`), color selection, point/continuous painting, recent symbols menu.
   - `boardgame-text-mode`: Text overwrite mode on the felt.
6. **`src.el/boardgame-org-marker.el`**:
   - `boardgame-navigate-to-board-coord`: General-purpose cursor navigation by board filename and coordinates.
   - `boardgame-create-marker`: Generates `Marker <board> (x, y)` object with glyph `^` and parameterized executable source block.
7. **`src.el/boardgame-org-board.el`**:
   - Felt normalization (4.6), board load/save/save-as, cell coordinate lookup, count indicators (`1`-`9`, `+`).
8. **`src.el/boardgame-org-object.el`**:
   - Org document parsing, property drawers, source block execution (`boardgame-execute-object-block`, `boardgame-execute-board-block`), extended descriptions.
9. **`src.el/boardgame-org-stack.el`**:
   - Consolidation into single Org doc with glyph `$` (black on white) and deletion of standalone files.
   - Expansion back to standalone files and deletion of stack file.
10. **`src.el/boardgame-org-container.el`**:
    - Permanent containers preserving standalone files; draw top/bottom/random, shuffle, layout.
11. **`src.el/boardgame-org-hand.el`**:
    - Hand as Org file; `boardgame-place-heading-on-board` (usable in any Org buffer); `boardgame-take-object-to-hand` (taking from container/stack extracts top item).
12. **`src.el/boardgame-org.el`**:
    - Package entry point with all canonical interactive commands matching Section 2 of `boardgame-org-interface.md`.
    - Autoload cookies `;;;###autoload` on all public commands.
13. **`src.el/boardgame-org-test.el`**:
    - ERT regression test suite covering all Section 15 acceptance criteria.
14. **`readme.org` & `src/readmeContent.ts`**:
    - Full documentation in Russian with instructions for installation, layout, drawing mode, navigation markers, and canonical commands.

---

## 3. Plan Execution Sequence

1. Update `src.el/boardgame-org-core.el` to use `./world/` default directory and standard ELPA/MELPA headers.
2. Verify all `src.el/*.el` files have ELPA/MELPA headers, autoload cookies, and proper `provide` forms.
3. Update `readme.org` and sync `src/readmeContent.ts`.
4. Run `compile_applet` and verify server health on port 3000.
