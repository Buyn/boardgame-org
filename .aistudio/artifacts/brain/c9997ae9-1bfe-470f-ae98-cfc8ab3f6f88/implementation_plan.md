# boardgame.org — Revised Implementation Plan

A modular Emacs Lisp package in `src.el/` implementing the tabletop specification from `boardgame-org.md`, accompanied by a comprehensive `readme.org` and an Emacs Doom-One styled TypeScript documentation reader in `src/` displaying `readme.org` on port 3000.

## User Review & Critical Decisions

> [!IMPORTANT]
> Revised architectural requirements:
> - **Elisp Package Directory**: All Emacs Lisp files are housed strictly within `src.el/` (`boardgame-org.el`, `boardgame-org-core.el`, `boardgame-org-object.el`, `boardgame-org-stack.el`, `boardgame-org-container.el`, `boardgame-org-hand.el`, `boardgame-org-board.el`, `boardgame-org-render.el`, `boardgame-org-test.el`).
> - **TypeScript Application Scope**: Solely responsible for displaying and navigating `readme.org` instructions with authentic Emacs Doom-One dark styling, Table of Contents, and code copying.
> - **Dev Server Reliability**: Lightweight Vite configuration on port 3000 (`host: '0.0.0.0'`, `allowedHosts: true`) without heavy canvas or state overhead, ensuring instant 200 OK responses.

---

## 1. Overview & Core Concept

1. **Emacs Lisp Package (`src.el/`)**:
   - Implements the text-based tabletop environment in Emacs where Org-mode documents represent game objects, stacks, containers, and felt board state.
   - Preserves all architectural boundaries and invariants from `boardgame-org.md`:
     - *Object is a file*: an independently existing object has its own Org file.
     - *Stacks vs Containers*: Stacks consolidate documents into one and delete standalone files; Containers organize objects via Org links while keeping standalone files intact.
     - *Felt Normalization*: fills missing cells with default symbol, trims excess.
     - *Layering & Indicators*: displays top object glyph and numerical count indicator (`1`-`9`, `+`) immediately to its left.
     - *Git World History*: commits world states after operations for safe rollback.

2. **Documentation (`readme.org`)**:
   - Detailed user and developer guide in Russian covering installation (straight.el, use-package, load-path), core concepts, complete table of keybindings, command reference, and ERT regression test execution.

3. **TypeScript Interactive Reader (`src/`)**:
   - Renders `readme.org` in the browser with an authentic Emacs buffer feel:
     - Doom-One color palette (`#1bbc95` greens, `#51afef` blues, `#ecbe7b` yellows, `#ff6c6b` reds).
     - Collapsible Table of Contents with jump-to-section.
     - One-click copy for Elisp configuration and code blocks.
     - One-click download of all `src.el/*.el` files as an archive / raw files.

---

## 2. User Experience & Visual Design

### TypeScript Documentation Viewer Interface

- **Emacs Header & Modelines**:
  - Buffer title: `-U:---  readme.org   (Org View)----L1--All----------------`
  - Quick action toolbar: Search / filter sections, Toggle TOC, Copy Elisp config, Download package archive.
- **Org Document Renderer**:
  - Level 1 (`*`), Level 2 (`**`), Level 3 (`***`) Org headings with colored stars and fold/unfold toggles.
  - Property drawers (`:PROPERTIES:` ... `:END:`) rendered with authentic syntax coloring.
  - Org source blocks (`#+begin_src elisp ... #+end_src`) with line numbers and instant "Copy" button.
  - Org tables (`|---|---|`) with aligned monospace borders and column headers.
  - Org quote blocks (`#+BEGIN_QUOTE`) with left accent border.
- **Sidebar Table of Contents**:
  - Sticky sidebar navigation tracking the active reading section.

---

## 3. Technical Architecture & File Layout

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             Web Application                                 │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │      src/App.tsx (Emacs Doom-One Interactive readme.org Viewer)       │  │
│  │    [Table of Contents] [Syntax Highlighting] [Code Copy] [Download]   │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      │ reads & renders                      │
│                                      ▼                                      │
│                                 readme.org                                  │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ documents
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Emacs Lisp Package in src.el/                            │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                           boardgame-org.el                            │  │
│  │                 (Major Mode, Keymaps, Commands & Menu)                │  │
│  └───────┬───────────────────┬───────────────────┬───────────────────┬───┘  │
│          ▼                   ▼                   ▼                   ▼      │
│  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐   ┌───────────┐  │
│  │-render.el     │   │-board.el      │   │-stack.el      │   │-hand.el   │  │
│  │(Felt display, │   │(Grid models,  │   │(Consolidation,│   │(Player    │  │
│  │ Count badges) │   │ Normalization)│   │ File deletion)│   │ hand doc) │  │
│  └───────┬───────┘   └───────┬───────┘   └───────┬───────┘   └─────┬─────┘  │
│          ▼                   ▼                   ▼                 ▼        │
│  ┌───────────────────────────────────────────────┐   ┌───────────────────┐  │
│  │              boardgame-org-object.el          │   │-container.el      │  │
│  │        (Org Properties & File Invariants)     │   │(Links & Decks)    │  │
│  └───────────────────────┬───────────────────────┘   └─────────┬─────────┘  │
│                          ▼                                     ▼            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                        boardgame-org-core.el                          │  │
│  │               (cl-defstruct, Git VC Commit, Defcustom)                │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      ▼                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                       boardgame-org-test.el                           │  │
│  │                    (ERT Regression Test Suite)                        │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Planned Files

1. **`src.el/boardgame-org-core.el`**: Data structs, defcustom options, Git VC helpers.
2. **`src.el/boardgame-org-object.el`**: Object parsing/serialization, property drawers, file invariant (`save-file`, `delete-file`).
3. **`src.el/boardgame-org-stack.el`**: Stack consolidation into one document (removes individual files) and stack expansion.
4. **`src.el/boardgame-org-container.el`**: Permanent container (decks, boxes) organization via links, shuffle, draw without deleting files.
5. **`src.el/boardgame-org-hand.el`**: Player hand persistence (`hands/<player>.org`).
6. **`src.el/boardgame-org-board.el`**: Felt grid representation, normalization (Section 4.6), board load/save.
7. **`src.el/boardgame-org-render.el`**: Felt rendering, multi-object count indicators (`1`-`9`, `+`), custom faces.
8. **`src.el/boardgame-org.el`**: Package entry point, `boardgame-org-mode`, keymap, and interactive commands.
9. **`src.el/boardgame-org-test.el`**: ERT regression test suite verifying felt normalization, invariants, stacks, and containers.
10. **`readme.org`**: Full guide in Russian with architecture, installation, keybindings, and ERT testing.
11. **`src/App.tsx` & `src/main.tsx`**: Lightweight, responsive Doom-One styled interactive Org reader rendering `readme.org`.
