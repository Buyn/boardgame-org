# boardgame.org — Emacs Lisp Package Implementation Plan

A modular, file-oriented Emacs Lisp package in `src/` providing an interactive text-based tabletop environment in Emacs, where Org-mode documents serve as editable, persistent representations of game objects, stacks, containers, and felt board state.

## User Review & Critical Decisions

> [!IMPORTANT]
> Based on your confirmed preferences from Phase 1:
> - **Package Modular Structure**: Configured as a multi-file modular package inside `src/` adhering strictly to Section 7 modularity guidelines (separate files for core data, objects, stacks, containers, boards, hands, rendering, and commands).
> - **Menu Interface**: Standard native Emacs keymap without external Hydra dependencies (`boardgame-org-mode-map` with intuitive single-key navigation, modal actions, and interactive completion menus).
> - **Documentation**: Complete, comprehensive `readme.org` in Russian with architecture explanations, installation instructions, keybindings table, and ERT testing guide.

---

## 1. Overview & Core Concept

`boardgame.org` implements an Emacs-native tabletop environment built around file-oriented persistence and Org-mode serialization:

- **An Object is a File**: Every independently existing game object (cards, dice, tokens, meeples) is backed by an individual `.org` file containing property drawers (`:PROPERTIES:` ... `:END:`), glyph, name, type, and optional action blocks.
- **Stacks vs Permanent Containers**:
  - **Stack (Section 3.1)**: Consolidates multiple object documents into a single Org document. When objects are stacked, their former standalone files are removed. Expanding a stack reconstructs the standalone files and deletes the stack file.
  - **Permanent Container (Section 3.2)**: Organizes independent objects using Org links without merging their files. Standalone files remain intact. Containers support shuffle and draw actions and persist even when empty.
- **Felt Tabletop Buffer (`*boardgame-org*`)**: An interactive grid display showing felt background characters, coordinate axes (columns A-Z, rows 1-N), and layered game objects.
- **Layering & Count Indicator (Section 5)**: When multiple objects occupy a coordinate, the top glyph is displayed alongside a count indicator immediately to its left (`1`-`9`, or `+` if greater than 9).
- **Felt Normalization (Section 4.6)**: Automatically normalizes raw felt ASCII blocks to declared width/height dimensions.
- **Git World Version Control (Section 6)**: Automatically creates Git commits representing world transitions for recoverable history.

---

## 2. User Experience & Visual Design (Emacs Buffer)

### Key User Flows

1. **Tabletop Launch**:
   - `M-x boardgame-org`: Initializes the world directory, ensures standard subfolders (`boards/`, `objects/`, `stacks/`, `containers/`, `hands/`), loads `boards/main.org`, and opens the `*boardgame-org*` buffer.
2. **Cursor Navigation**:
   - Navigate with arrow keys or Vi-style `h`, `j`, `k`, `l` (or Emacs `C-f`, `C-b`, `C-n`, `C-p`).
   - The header line updates dynamically showing current coordinates (e.g. `[Point: C4]`), object count, and top object details.
3. **Object Actions**:
   - `H`: Pick up top object into player hand (`hands/player1.org`).
   - `P`: Play object from hand to the board cursor coordinate.
   - `S`: Consolidate all objects at the cursor into a single stack document (removes individual files).
   - `U`: Expand stack into independent object files.
   - `d`: Draw card from container/deck at cursor into player hand.
   - `s`: Shuffle container at cursor.
   - `r`: Roll die (updates face value and glyph).
   - `F`: Flip card (toggles face-up / face-down `🂠`).
   - `o`: Open Org document of the object at point in another window.
   - `g`: Commit world state to Git with a custom message.

### Visual Modeline & Faces

```
[Point: D3 (3 items)] Top: 🂡 Ace of Spades (card) | Hand: 2 items | ?: Help
```

- Custom Emacs faces for:
  - `boardgame-org-felt-face`: Subdued background dot character (`.`)
  - `boardgame-org-object-face`: High-contrast object glyphs
  - `boardgame-org-count-face`: Accent color for count numbers (`2`, `3`, `+`)
  - `boardgame-org-cursor-face`: Subtle box cursor overlay
  - `boardgame-org-coord-face`: Modest coordinate column/row labels

---

## 3. Key Product Decisions & Trade-Offs

- **Multi-File Modularity in `src/`**:
  - *Decision*: Split implementation into focused modules (`boardgame-org-core.el`, `boardgame-org-object.el`, `boardgame-org-stack.el`, `boardgame-org-container.el`, `boardgame-org-hand.el`, `boardgame-org-board.el`, `boardgame-org-render.el`, `boardgame-org.el`, and `boardgame-org-test.el`) all located within `src/`.
  - *Why*: Satisfies Section 7 of `boardgame-org.md` (functions under 50 lines, single responsibility, high maintainability, unit testability).
- **Native Keymap over External Hydra**:
  - *Decision*: Built directly using `boardgame-org-mode-map` and standard Emacs transient prompt (`read-char-choice` / `completing-read`), removing hard external dependency on Hydra while keeping instant one-key actions.
- **Strict Invariant Enforcement**:
  - *Decision*: Stack consolidation physically calls `delete-file` on consolidated items and writes a consolidated stack file. Stack expansion writes standalone files and deletes the stack file.
  - *Why*: Conforms strictly to the normative architectural boundary in Section 2.1 and 3.1.

---

## 4. Technical Architecture & Component Structure

### Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                        boardgame-org.el                                │
│          (Interactive Commands, Major Mode, Menu & Keymap)             │
└───────┬───────────────────────────────┬────────────────────────┬───────┘
        │                               │                        │
        ▼                               ▼                        ▼
┌──────────────────┐            ┌───────────────┐        ┌───────────────┐
│ boardgame-org-   │            │boardgame-org- │        │boardgame-org- │
│    render.el     │            │   board.el    │        │    hand.el    │
│(Buffer Drawing,  │            │(Felt Grid,    │        │(Player Hands, │
│ Glyphs & Counts) │            │ Normalization,│        │ Play / Pickup)│
└──────────────────┘            │ Serialization)│        └───────────────┘
        │                               │                        │
        ▼                               ▼                        ▼
┌──────────────────┐            ┌───────────────┐        ┌───────────────┐
│ boardgame-org-   │            │boardgame-org- │        │boardgame-org- │
│    stack.el      │            │ container.el  │        │   object.el   │
│(Consolidation,   │            │(Decks, Shuffle│        │(Org Properties│
│ Standalone File  │            │ Draw, Preserve│        │ File Lifecycle│
│ Deletion/Expand) │            │ Standalone)   │        │ Invariants)   │
└───────┬──────────┘            └───────┬───────┘        └───────┬───────┘
        │                               │                        │
        └───────────────────────┬───────┴────────────────────────┘
                                ▼
                ┌───────────────────────────────┐
                │     boardgame-org-core.el     │
                │(cl-defstruct, Git VC, Config) │
                └───────────────┬───────────────┘
                                ▼
                ┌───────────────────────────────┐
                │   Org World File Repository   │
                │(boards/, objects/, stacks/,   │
                │ containers/, hands/, docs/)   │
                └───────────────────────────────┘
```

### Module Responsibilities inside `src/`

1. **`src/boardgame-org-core.el`**:
   - Custom variables: `boardgame-org-world-directory`, `boardgame-org-default-felt-symbol`, `boardgame-org-auto-commit`.
   - Struct definitions (`cl-defstruct`): `boardgame-org-object`, `boardgame-org-board`, `boardgame-org-placed`, `boardgame-org-hand`.
   - File path and Git commit helpers.
2. **`src/boardgame-org-object.el`**:
   - Org document parsing: properties drawer, heading, and body description.
   - Serialization to standard Org document.
   - File invariant operations: `save-file` and `delete-file`.
3. **`src/boardgame-org-stack.el`**:
   - `boardgame-org-stack-consolidate`: merges multiple object documents into a single stack Org document and removes former standalone files.
   - `boardgame-org-stack-expand`: reconstructs standalone Org files and removes the stack document.
4. **`src/boardgame-org-container.el`**:
   - Permanent container parsing and serialization using link format `[[file:objects/...][...]]`.
   - `shuffle`: in-place member randomization.
   - `draw`: pop top member without deleting file.
5. **`src/boardgame-org-hand.el`**:
   - Hand file serialization and in-memory management.
6. **`src/boardgame-org-board.el`**:
   - Felt normalization (Section 4.6): fills missing cells with default symbol, discards excess.
   - Board Org document parsing and serialization.
   - Object coordinate tracking and movement.
7. **`src/boardgame-org-render.el`**:
   - Tabletop buffer rendering.
   - Multi-object count indicator calculation (`1`-`9`, `+`).
8. **`src/boardgame-org.el`**:
   - Main package entry point, `boardgame-org-mode`, keymap, and interactive commands.
9. **`src/boardgame-org-test.el`**:
   - ERT regression test suite verifying felt normalization, object file invariants, stack consolidation/expansion, container preservation, and round-trip serialization.
10. **`readme.org`**:
    - Comprehensive guide in Russian detailing architecture, installation, keybindings, and testing.
