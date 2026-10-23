# boardgame.org
Elisp tabletop game engine using Org-mode for persistence.
## Architecture

- **boardgame-org.el** - Main module with all functionality
- **boardgame-org.md** - Architecture and implementation principles
- **boardgame-org-interface.md** - User-facing interface specification

## Core Concepts

- **World** - Directory containing boards, objects, hands, containers
- **Board** - Character-based game space with felt layer and objects
- **Object** - Game entity represented by an Org document
- **Hand** - Ordered collection of cards/objects as an Org file
- **Container** - Permanent object organizing references to others
- **Stack** - Explicit consolidation of objects into one Org document

## Usage

```elisp
M-x boardgame-start          ; Start game with world selection
M-x boardgame-create-board   ; Create a new board
M-x boardgame-open-board     ; Open an existing board
M-x boardgame-save-board     ; Save current board
M-x boardgame-close-board    ; Close current board
M-x boardgame-create-object  ; Create a new object
M-x boardgame-add-object     ; Add object to board
M-x boardgame-delete-object  ; Remove object from board
M-x boardgame-drawing-mode   ; Toggle drawing mode
M-x boardgame-create-marker  ; Create navigation marker
M-x boardgame-navigate       ; Navigate to board coordinates
```

## Files

Each object, hand, container, and board is an Org file. This enables:
- Human-readable persistence
- Manual editing
- Git version control
- Diff/merge capabilities

## Development

Run tests:
```bash
make test
```

Build:
```bash
make compile
```

## License

GPLv3+ - See boardgame-org.el for details.
