# `boardgame.org` Implementation Roadmap and Stage-by-Stage Verification Plan
> **Specification Relationship & Context:** This document serves as the normative engineering implementation plan for the `boardgame.org` tabletop game engine. It is an integral companion specification directly derived from and bound to two foundational architecture documents:
> 1. **`boardgame-org.md`** (*Architecture Clarifications and Implementation Principles*): Defines core data models, Org-mode file persistence invariants, stack consolidation versus container organization, modular code separation principles, and Git-based version control semantics.
> 2. **`boardgame-org-interface.md`** (*User Interface and Observable Behavior Specification*): Defines user-facing frame layouts, buffer behaviors, non-wrapping navigation, window splitting, interactive drawing modes, and log tracking.
> 
> In accordance with the project architecture, `boardgame-org-interface.md` takes precedence for user-visible command and window behaviors, while `boardgame-org.md` governs underlying file structures, module loading semantics, and persistence invariants.

---

## 1. Executive Implementation Strategy, Module Architecture & Verification Framework
### 1.1. Development Methodology: Stub-Driven Major Mode Construction
The development of `boardgame.org` is structured into eight sequential, modular stages. To maintain high code quality and prevent UI regressions in Emacs, the implementation follows a stub-driven major mode development methodology. 

Rather than attempting to build file parsing and rendering simultaneously, Stage 1 establishes a fully functional, dedicated Emacs frame with buffer stubs and window splitting. Subsequent stages replace these stubs with live data structures, parser logic, rendering engines, and interactive command sets.

### 1.2. Module Architecture & Single-Feature Loading Protocol
In compliance with `boardgame-org.md` §7 (*Implementation Quality Requirements*), the codebase is partitioned into distinct Emacs Lisp files corresponding to functional responsibilities (`boardgame-data.el`, `boardgame-serialize.el`, `boardgame-window.el`, `boardgame-draw.el`, etc.). 

However, to preserve idiomatic Emacs Lisp package encapsulation:
* **No Internal `provide` Calls:** Individual component files (e.g., `boardgame-window.el`, `boardgame-draw.el`) must **not** execute independent `(provide 'boardgame-window)` feature registrations. Internal files represent private module boundaries of a single package.
* **Root File Orchestration:** The root file `boardgame.el` acts as the single master entry point. It sequentially loads all internal module files using explicit `load` calls (or relative `require` statements within the package directory).
* **Single Public Feature:** The root file `boardgame.el` is the **only** file in the project that issues `(provide 'boardgame)`. External configuration and user init files load the entire engine cleanly via a single `(require 'boardgame)` declaration.

```elisp
;; --- Sample Structure of Main Entry Point: boardgame.el ---

(defgroup boardgame nil
  "Text-based tabletop game engine for Emacs using Org-mode."
  :group 'games)

;; Internal module loading (sequential loading of internal components)
(load (expand-file-name "boardgame-mode" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-window" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-data" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-serialize" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-world" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-log" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-status" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-board" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-render" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-object" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-draw" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-hand" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-stack" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-container" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-marker" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-commands" (file-name-directory load-file-name)) nil t)
(load (expand-file-name "boardgame-git" (file-name-directory load-file-name)) nil t)

;; Primary interactive entry point
(defun boardgame-start (&optional world-directory)
  "Start the boardgame.org engine in a dedicated frame."
  (interactive)
  (boardgame-window-initialize world-directory))

;; Sole public feature provision
(provide 'boardgame)
```

### 1.3. Verification Standard & ERT Test Execution Protocol
Every stage includes a mandatory **Definition of Done (DoD)** anchored in automated testing using the standard Emacs Lisp Regression Testing (**ERT**) framework (`ert.el`). 

Testing must cover both unit tests (verifying isolated functions, regex parsers, and data transformations) and integration tests (verifying frame, window, buffer, and file system interactions).

Test suites reside in a dedicated test file `test-boardgame-org.el` (and associated stage test suites). Developers and CI pipelines run and evaluate tests using standard Emacs ERT commands:

```elisp
;; --- ERT Test Suite Loading & Execution Protocol ---

;; 1. Load the test suite file into the running Emacs session
(load-file "~/Dev/emacs/boardgame-org/test-boardgame-org.el")

;; 2. Run all test cases matching the boardgame test selector prefix
(ert "^boardgame-test")
```

A stage is considered complete **only** when executing `(ert "^boardgame-test")` produces zero failures and zero unhandled errors.

---

## 2. Stage-by-Stage Implementation Plan
### Stage 1: Core Package Infrastructure, Dedicated Frame, Window Layout, and Buffer Stubs
#### Strategic Objective
Establish the foundational Emacs Lisp package structure, major modes, dedicated game frame management, and initial 80/20 window layout using temporary buffer stubs.

#### Elisp Package Modules
* `boardgame.el`: Core package entry point, global custom variables, master module loading, and `(provide 'boardgame)`.
* `boardgame-mode.el`: Major mode definitions (`boardgame-board-mode`, `boardgame-log-mode`, `boardgame-status-mode`).
* `boardgame-window.el`: Dedicated frame creation, window splitting logic, and buffer layout management.

#### Technical Functionality & Invariants
* **Package Initialization:** Define customization group `defgroup boardgame` and global startup function `boardgame-start`.
* **Dedicated Frame Creation:** `boardgame-start` spawns a dedicated Emacs frame using `make-frame`, preserving the user's existing editing frames and workspaces.
* **Window Splitting & Proportions:** The dedicated frame is split into windows via `window-split`:
  * Board Window: Allocates 80% of horizontal frame width.
  * Side Area Window: Allocates 20% of horizontal frame width, further split vertically (80% for the log window, 20% for the status window).
* **Buffer Stubs:** Populate windows with temporary stub buffers (`*boardgame-board-stub*`, `*boardgame-log-stub*`, `*boardgame-status-stub*`).
* **Display Properties:** Enforce local line truncation (`truncate-lines` set to `t`) in the board buffer stub, while allowing natural text wrapping in the log buffer stub.

#### Definition of Done & ERT Verification Suite
* **Unit Test 1.1 (`boardgame-test-window-calculation`):** Verify that window width and height allocation formulas correctly compute 80/20 horizontal and 80/20 vertical ratios given arbitrary frame dimensions.
* **Unit Test 1.2 (`boardgame-test-buffer-modes`):** Verify that major mode hooks correctly set buffer-local variables (`truncate-lines` is `t` in board mode, `nil` in log mode).
* **Integration Test 1.3 (`boardgame-test-frame-initialization`):** Execute `boardgame-start` inside an ERT test harness, verifying that a new frame is created, three distinct windows are arranged according to the layout tree (`window-tree`), and stub buffers are assigned without modifying pre-existing frames.

---

### Stage 2: In-Memory Data Model, Parsing, and Org File Serialization
#### Strategic Objective
Implement the in-memory Lisp data structures representing the game board, parse Org-mode documents into active game states, and guarantee lossless round-trip serialization.

#### Elisp Package Modules
* `boardgame-data.el`: Struct definitions (`cl-defstruct`), hash-table storage for felt and objects, coordinate mapping.
* `boardgame-serialize.el`: Org-mode document parser and serializer.

#### Technical Functionality & Invariants
* **In-Memory Representation:** Define Lisp structures for board state, including board dimensions, felt matrix (character grid), and object registry mapped by coordinate keys `(x . y)`.
* **Org-Mode Parsing:** Parse Org-mode board headers, metadata drawers (`:PROPERTIES:`), felt blocks, and object reference headlines into the in-memory data model.
* **Felt Normalization:** Normalize raw character lines from Org documents. Short lines are padded with default felt symbols (`.`), and characters extending beyond declared board dimensions are clipped.
* **Lossless Serialization:** Convert modified in-memory board structures back into formatted Org-mode text documents. The serializer must guarantee mutual invertibility: `deserialize(serialize(state)) == state`.

#### Definition of Done & ERT Verification Suite
* **Unit Test 2.1 (`boardgame-test-felt-normalization`):** Pass ragged text strings of varying lengths to the normalization parser and verify that all rows match exact board width dimensions, filled with default characters.
* **Unit Test 2.2 (`boardgame-test-property-drawer-parsing`):** Parse an Org header with properties (`BOARD_WIDTH`, `BOARD_HEIGHT`, `FELT_DEFAULT`) and verify that in-memory struct fields match extracted values.
* **Integration Test 2.3 (`boardgame-test-roundtrip-serialization`):** Load a sample Org board file, deserialize it into memory, serialize it back to a temporary buffer, and assert that the resulting Org document text is identical to the source document.

---

### Stage 3: World Management, Session State, and Unified Logging
#### Strategic Objective
Manage world directory selection, implement world initialization, track active board buffers across frames, and link a single shared log buffer to the active world session.

#### Elisp Package Modules
* `boardgame-world.el`: Directory resolution, world initialization, and switching routines.
* `boardgame-log.el`: Shared side-log management and message appending routines.
* `boardgame-status.el`: Status window updating and contextual state display.

#### Technical Functionality & Invariants
* **World Resolution:** Implement `boardgame-start` interactive directory prompting. Support customizable variable `boardgame-default-world-directory`. If an invalid path is provided, trigger recovery prompts.
* **Active Board Tracking:** Maintain the global variable `boardgame-current-board-buffer`. Ensure commands resolve their target buffer through a strict precedence hierarchy: explicit argument > frame-associated board buffer > `boardgame-current-board-buffer`.
* **Unified World Log:** Ensure all boards and frames belonging to the same active world share a single log buffer named `<world>-log.org`. Appending messages from any board appends to this unified log.
* **Status Updates:** Render current coordinate, active sub-mode (e.g., Drawing Mode), and selected object metadata in the status window.

#### Definition of Done & ERT Verification Suite
* **Unit Test 3.1 (`boardgame-test-log-filename-resolution`):** Verify that world directory paths resolve to the exact expected log file path `<world-path>/<world-name>-log.org`.
* **Unit Test 3.2 (`boardgame-test-active-board-precedence`):** Test command target resolution when passing explicit arguments versus relying on `boardgame-current-board-buffer`.
* **Integration Test 3.3 (`boardgame-test-multi-board-shared-log`):** Open two separate board buffers belonging to the same world in an ERT environment. Emit log entries from both buffers and verify that both write sequentially to the same shared log buffer without duplicating or destroying log state.

---

### Stage 4: Board Rendering, Object Stacking, and Non-Wrapping Navigation
#### Strategic Objective
Render in-memory game state into the board buffer, implement object visual layering with stack indicators, and enable smooth, non-wrapping cursor movement and scrolling.

#### Elisp Package Modules
* `boardgame-board.el`: Board buffer creation, buffer display settings, line truncation settings.
* `boardgame-render.el`: Buffer display redraw engine, character cell text properties.
* `boardgame-object.el`: Object layering calculation, visual glyph resolution, stack count indicators.

#### Technical Functionality & Invariants
* **Buffer Rendering:** Draw the combined grid of felt characters and game objects into the text buffer. Apply font-lock faces for felt colors and object glyphs.
* **Object Layering & Count Indicators:** When multiple objects occupy a single coordinate `(x, y)`:
  * Render the top-most object's visual glyph.
  * Render a stack quantity indicator directly to the left of the cell: digits `1` through `9` for counts 1–9, and `+` for 10 or more. Suppress indicators if the cell lies on the left boundary.
* **Non-Wrapping Navigation:** Enforce non-wrapping line behavior (`truncate-lines` set to `t`). Allow cursor navigation across boards larger than the window via standard Emacs horizontal (`scroll-left`, `scroll-right`) and vertical scrolling.

#### Definition of Done & ERT Verification Suite
* **Unit Test 4.1 (`boardgame-test-stack-indicator-calculation`):** Supply object lists of lengths 1, 5, 9, and 12 to the rendering engine and verify generated stack indicator character outputs (`1`, `5`, `9`, `+`).
* **Unit Test 4.2 (`boardgame-test-layering-visibility`):** Place three objects with different glyphs at coordinate `(10, 10)` and assert that the renderer selects the top object's glyph for display.
* **Integration Test 4.3 (`boardgame-test-cursor-scrolling-bounds`):** Move the point to coordinate `(120, 45)` on a large board in an active buffer and verify that line wrapping remains disabled, horizontal scrolling offset adjusts automatically, and text position maps cleanly to board coordinates.

---

### Stage 5: Drawing Mode (Felt Layer) and Text Overwrite Mode
#### Strategic Objective
Implement a ZZT-style interactive Drawing Mode for direct felt manipulation without disrupting object files, along with an Overwrite Text Mode.

#### Elisp Package Modules
* `boardgame-draw.el`: Drawing mode keymap, brush state, color/symbol selection, pipette tool, overwrite text engine.

#### Technical Functionality & Invariants
* **Drawing Mode Activation:** Toggling Drawing Mode temporarily hides the object layer, allowing direct visual editing of underlying felt characters. Object positions and Org files remain untouched.
* **Drawing Tools:** Support symbol brush selection, foreground/background color assignment, continuous stroke drawing, color/glyph pipette (sampling character and color under cursor), and a recent symbols menu.
* **Text Overwrite Mode:** Provide a text input sub-mode where typing replaces felt characters under the cursor and advances point to the right without inserting spaces, creating line breaks, or altering board dimensions.

#### Definition of Done & ERT Verification Suite
* **Unit Test 5.1 (`boardgame-test-pipette-sampling`):** Position cursor over a felt cell with character `#` and face attribute `:foreground "red"`, trigger the pipette command, and verify that active brush variables update to match.
* **Unit Test 5.2 (`boardgame-test-recent-symbol-history`):** Draw with five distinct symbols and verify that the recent symbol queue maintains the correct order without duplicate entries for the active symbol.
* **Integration Test 5.3 (`boardgame-test-drawing-mode-object-isolation`):** Place an object over coordinate `(5, 5)`, activate Drawing Mode, edit the felt character at `(5, 5)`, exit Drawing Mode, and verify that the object's Org file, coordinates, and layer placement are fully preserved.

---

### Stage 6: Hands, Stacks, and Permanent Containers
#### Strategic Objective
Implement distinct file persistence and organizational semantics for player Hands, consolidated Stacks, and permanent Containers.

#### Elisp Package Modules
* `boardgame-hand.el`: Hand Org file management, `place-on-board` and `take` operations.
* `boardgame-stack.el`: Multi-object Org document consolidation engine.
* `boardgame-container.el`: Permanent container Org document manager.

#### Technical Functionality & Invariants
* **Hand Operations:** Manage hand Org files containing object subtrees. `place-on-board` extracts a subtree, creates a standalone object Org file, resolves visual glyph (first heading letter or fallback `*`), and places it on the board. `take` transfers the object back into the hand subtree and deletes the standalone file.
* **Stack Consolidation:** Combining objects into a Stack merges their Org contents into a single consolidated Org document (represented on board with glyph `$`). Standalone Org files of incorporated objects are physically deleted from disk.
* **Permanent Containers:** Containers organize references to independent objects within a persistent Org document without consolidating or deleting the objects' individual Org files. Support container draw (top/bottom/random), shuffle, and layout operations.

#### Definition of Done & ERT Verification Suite
* **Unit Test 6.1 (`boardgame-test-glyph-extraction-fallback`):** Extract visual glyphs from Org headings ("Card Dragon" -> `C`, "***" -> `*`, empty heading -> `*`) and verify fallback rules.
* **Unit Test 6.2 (`boardgame-test-stack-file-consolidation`):** Execute stack consolidation on three standalone object Org files. Assert that a single stack Org file is written and the three original files no longer exist on the file system.
* **Integration Test 6.3 (`boardgame-test-container-draw-file-preservation`):** Add two standalone objects into a permanent container, draw one object out onto the board, and verify that both standalone object Org files remain intact on disk throughout the operation.

---

### Stage 7: Navigation Markers, Code Execution, and Interactive Commands
#### Strategic Objective
Implement cross-board navigation markers, absolute movement commands, and interactive Org-Babel code block execution.

#### Elisp Package Modules
* `boardgame-marker.el`: Marker object creation, metadata parsing, and cross-board jump routines.
* `boardgame-commands.el`: Interactive game commands, Org-Babel code block execution wrappers, keybinding maps.

#### Technical Functionality & Invariants
* **Universal Board Navigation:** Implement `(board x y)` navigation function allowing point movement across any board in the active world directory.
* **Navigation Markers:** Create specialized marker objects (visual glyph `^`) storing `DESTINATION_BOARD`, `DESTINATION_X`, and `DESTINATION_Y` properties in their Org drawers. Triggering a marker executes its navigation block, jumping point to the target board and coordinate.
* **Org-Babel Code Execution:** Provide commands (`boardgame-execute-object-block`, `boardgame-execute-board-block`) to execute embedded Elisp code blocks in object and board Org documents.
* **Keybindings:** Bind core actions to function keys (F1–F12) and key chords (up to 3 key presses).

#### Definition of Done & ERT Verification Suite
* **Unit Test 7.1 (`boardgame-test-marker-heading-generation`):** Pass target board name "dungeon.org" and coordinates `(15, 20)` to marker generator and verify generated heading string `Marker (dungeon.org) (15, 20)` and property drawer fields.
* **Integration Test 7.2 (`boardgame-test-cross-board-marker-jump`):** Trigger a navigation marker on `board-a.org` targeting `board-b.org` at `(10, 5)`. Verify that the current buffer switches to `board-b.org` and point lands precisely at coordinate `(10, 5)`.

---

### Stage 8: Version Control (Git), Error Recovery, and End-to-End Integration
#### Strategic Objective
Integrate automated Git version control for world history, implement resilient error handling, and execute the complete ERT test suite.

#### Elisp Package Modules
* `boardgame-git.el`: Git repository initialization, automated stage and commit routines.
* `boardgame-tests.el`: Master test suite aggregator and end-to-end integration workflows.

#### Technical Functionality & Invariants
* **Automated Git Commits:** Automatically create a Git commit in the world directory following successful board or state save operations. Commit messages record the modified board and timestamp.
* **Error Recovery:** Catch file access errors, missing object references, or corrupted Org syntax gracefully, presenting actionable error notifications in the log window without crashing the game frame or discarding unsaved buffer states.
* **End-to-End Integration:** Aggregate all ERT test modules into a single executable test suite.

#### Definition of Done & ERT Verification Suite
* **Unit Test 8.1 (`boardgame-test-git-commit-trigger`):** Save a board buffer in a Git-tracked test world and verify that `git log` reflects a new commit containing the modified board file.
* **Integration Test 8.2 (`boardgame-test-corrupted-org-recovery`):** Attempt to load an intentionally malformed Org board file. Verify that the engine catches the error, logs a message to the status window, and keeps the dedicated game frame stable.
* **Master Integration Test 8.3 (`boardgame-test-full-suite-pass`):** Execute `ert` against all test selectors matching `"^boardgame-test"` and verify a 100% pass rate across all unit and integration tests.

---

## 3. Architecture Traceability & Specification Alignment Matrix
To ensure complete alignment with `boardgame-org.md` and `boardgame-org-interface.md`, the following matrix maps architectural specifications to their corresponding implementation stages and verification modules.

| Specification Invariant | Source Specification | Implementation Stage | Primary Elisp Module | ERT Verification Test |
| :--- | :--- | :--- | :--- | :--- |
| Single Public Feature (`provide 'boardgame`) | `boardgame-org.md` §7 | Stage 1 | `boardgame.el` | `boardgame-test-buffer-modes` |
| Dedicated Game Frame & 80/20 Layout | `boardgame-org-interface.md` §4.1–4.2 | Stage 1 | `boardgame-window.el` | `boardgame-test-frame-initialization` |
| Org-Mode Document Serialization | `boardgame-org.md` §4.1–4.2 | Stage 2 | `boardgame-serialize.el` | `boardgame-test-roundtrip-serialization` |
| Shared World Log (`<world>-log.org`) | `boardgame-org-interface.md` §4.5 | Stage 3 | `boardgame-log.el` | `boardgame-test-multi-board-shared-log` |
| Active Board Tracking (`boardgame-current-board-buffer`) | `boardgame-org-interface.md` §4.6 | Stage 3 | `boardgame-world.el` | `boardgame-test-active-board-precedence` |
| Object Layering & Stack Indicators (`1`–`9`, `+`) | `boardgame-org-interface.md` §4.4 | Stage 4 | `boardgame-object.el` | `boardgame-test-stack-indicator-calculation` |
| Non-Wrapping Buffer & Native Scrolling | `boardgame-org-interface.md` §5.1–5.2 | Stage 4 | `boardgame-board.el` | `boardgame-test-cursor-scrolling-bounds` |
| Drawing Mode & Text Overwrite Mode | `boardgame-org-interface.md` §5.4 | Stage 5 | `boardgame-draw.el` | `boardgame-test-drawing-mode-object-isolation` |
| Hand Subtree Operations (`place-on-board`, `take`) | `boardgame-org.md` §2.3 | Stage 6 | `boardgame-hand.el` | `boardgame-test-glyph-extraction-fallback` |
| Stack Document Consolidation & File Removal | `boardgame-org.md` §3.1 | Stage 6 | `boardgame-stack.el` | `boardgame-test-stack-file-consolidation` |
| Container File Preservation & Organization | `boardgame-org.md` §3.2 | Stage 6 | `boardgame-container.el` | `boardgame-test-container-draw-file-preservation` |
| Navigation Markers (`^`) & `(board x y)` | `boardgame-org-interface.md` §7.1 | Stage 7 | `boardgame-marker.el` | `boardgame-test-cross-board-marker-jump` |
| Automated Git Version Control & Recovery | `boardgame-org.md` §5.1 | Stage 8 | `boardgame-git.el` | `boardgame-test-git-commit-trigger` |
