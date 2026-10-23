# boardgame-org-interface.md
## 1. Purpose and Relationship to `boardgame-org.md`
This document defines the user-facing interface and observable behavior of `boardgame.org`, an Emacs Lisp tabletop game engine inspired by ZZT and character-based board games.
It is an **integral part of `boardgame-org.md`**, not an independent or optional specification.
The two documents have the following responsibilities:
- `boardgame-org.md` defines the project architecture, data model, Org document conventions, implementation principles, dependencies, and testing requirements.
- `boardgame-org-interface.md` defines how users start and interact with the game, how frames and buffers behave, how boards and objects are managed, and how commands and gameplay features must work.
If these documents contradict one another or allow conflicting interpretations, **`boardgame-org-interface.md` takes precedence for interface behavior, command behavior, frame and buffer management, file-selection workflows, and user-visible gameplay semantics**. Architectural requirements that do not conflict with these clarifications remain in force.
This document specifies observable behavior rather than mandatory internal data structures. The implementation may choose the most suitable internal representation as long as the behavior defined here is preserved.

## 2. Core Concepts
- **World:** a directory containing boards, object Org files, hands, containers, stacks, and other world-specific resources.
- **Board:** a rectangular character-based game space with a felt layer and game objects.
- **Felt:** the underlying character map, including spaces, arbitrary characters, and supported cell colors.
- **Object:** a game entity represented by an independent Org document or, after stack consolidation, a section of a combined Org document.
- **Hand:** an ordered collection of cards or objects represented by an Org file.
- **Container:** a persistent object that organizes references to other objects without merging their independent Org files.
- **Stack:** an explicitly created consolidation of selected objects into a combined Org document.
- **Game frame:** an Emacs frame containing a board and the associated game interface.
- **Side log:** a shared game-log buffer for the active world, displaying messages explicitly sent through the game's logging interface.
- **Active board:** the board currently targeted by implicit board commands, represented by a globally accessible variable.

## 3. Starting the Game and Selecting a World
### 3.1. Starting with an explicit world
The main startup command must accept an optional world directory argument.
Conceptually:
`boardgame-start [WORLD-DIRECTORY]`
When a directory is provided, the game must use that directory as the requested world.
If the directory exists and is valid, the package activates it.
If the directory does not exist, the package must offer to create and initialize it. It must not silently substitute another world.
If the requested location exists but is not a valid world directory, the package must report the problem and offer an appropriate recovery path.

### 3.2. Default world directory
The package must provide a user-customizable variable for the default world directory, for example:
`boardgame-default-world-directory`
Its default value may be `nil`, meaning that the user has not configured a default world.
When `boardgame-start` is called without an explicit directory:
1. If `boardgame-default-world-directory` identifies an existing valid world, activate it.
2. If it identifies a missing directory, offer to create the world there.
3. If it is unset, invalid, or cannot be used, offer a world-selection workflow.
The exact variable name may be refined during implementation, but the configurable default-world behavior is mandatory.

### 3.3. Selecting or creating a world
The world-selection workflow must allow the user to select an existing world directory or specify a new directory.
The package must distinguish between opening an existing world and creating a new one.
Creating a world must initialize the directory structure required by the package. It must not overwrite an existing world's contents.

### 3.4. Switching worlds
Only one world may be active at a time.
Switching worlds must not silently discard unsaved changes in boards belonging to the previous world.
The package must resolve open-board state and unsaved changes before switching the active world. It must not leave buffers associated with the old world accidentally operating on files in the new world.

## 4. Game Frames, Boards, and Shared State
### 4.1. Dedicated game frame
Starting the game must open a dedicated Emacs frame for the game interface. The user's existing editing frame must remain available and must not be repurposed as the game frame.
The game frame must display a board and the shared side log.

### 4.2. Board layout
The default layout must allocate approximately:
- 80% of the frame width to the board window.
- 20% of the frame width to the side-log area window.
The side-log area may be split horizontally. When the optional status area is enabled, approximately 20% of the side-log region may be reserved for persistent contextual information, leaving the remaining area for log messages.
These proportions must be user-configurable.

### 4.3. Multiple boards in one frame
The user must be able to open and switch between multiple boards within the same game frame.

Switching boards must change the board displayed in the relevant board window without unintentionally replacing the shared log or losing another board's state.

The exact navigation mechanism may use commands, completion, a board list, or another suitable interface.

### 4.4. Multiple game frames
The user must also be able to display different boards in different game frames.

For example, the user may open Board A in one game frame and Board B in another. Both boards may belong to the same active world.

Each frame must retain its own association with the board displayed in that frame. Switching the board in one frame must not silently change the board displayed in another frame.

However, boards displayed in different frames that belong to the same active world must use the same shared world log buffer.

The package must support both workflows:

- Open or switch to another board in the current game frame.
- Open or display another board in a separate game frame.

The implementation may provide a frame-selection argument or separate interactive commands for these operations.

### 4.5. One world, one shared log
All game frames associated with the same active world must share one game-log buffer.

A message sent to the game log from any board or game frame must appear in that shared log.

Opening another board from the same world must not create an unrelated log buffer by default.

Switching worlds must associate the game interface with the appropriate log for the newly active world. The implementation must not mix messages from different worlds into one log unless explicitly configured to do so.

The log may be temporary by default. Optional persistent per-board logging may be supported separately, but it must not replace the requirement for a shared world-level session log.

### 4.6. Active board tracking
The package must provide a globally accessible variable representing the currently active board, for example:
`boardgame-current-board-buffer`

This variable must identify the board buffer that implicit board commands should operate on.
The variable is required even if the implementation also maintains frame-local board associations.
Its purpose is to remove ambiguity when multiple boards or game frames are open.

The active-board value must be updated when:
- A board is opened and becomes the current target.
- The user switches to another board.
- A command explicitly selects or operates on another board.
- A command opens a board and makes it the current target.
- A command is executed under the cursor on board.

Commands that explicitly receive a board argument must operate on that board. Otherwise, they must resolve their target through the active-board mechanism.

The implementation must document the precise precedence between an explicit board argument, the board associated with the selected game frame, and `boardgame-current-board-buffer`. These rules must be consistent across all commands.

The active-board variable must not be treated as a replacement for maintaining the board associated with each frame. It is a global indication of the current command target, not a claim that only one board may be open.

### 4.7. Unsaved boards
Each board must maintain its own change state.

Switching boards, opening another frame, or changing the active-board variable must not discard another board's unsaved changes.

Closing a board, closing a game frame, or switching worlds must trigger the appropriate save, discard, or cancel workflow whenever unsaved changes could be lost.

### 4.8. Board and Log Window Architecture
The game interface must use standard Emacs windows and buffers. The board and the session log are separate buffers displayed in separate windows within the same game frame.

- **Board window:** displays the active board buffer. Each board is a regular Emacs text buffer backed by its own Org file.
- **Log window:** displays the world-level session log buffer. All game frames displaying boards from the same world share this log buffer.
- **Window layout:** the board window occupies approximately 80% of the available horizontal space, and the log window occupies approximately 20%. These proportions must be configurable.
- **Independent navigation:** scrolling the board must not scroll the log, and scrolling the log must not scroll the board. Each window retains its own normal Emacs navigation and scrolling behavior.
- **Native window management:** use Emacs window-management facilities to create, arrange, resize, and manage these windows. Do not render the board and log as artificial regions within a single buffer, and do not implement a custom graphical surface for their layout.
- **Multiple game frames:** each game frame has its own window layout and board-window association. Different frames may display different boards belonging to the same world while sharing the same session log buffer.
- **Buffer identity:** the board buffer and log buffer remain independent buffers with their own buffer-local state, modes, and lifecycle. Closing or switching a board must not accidentally kill the shared session log while another game frame still uses it.

The implementation may use additional windows for optional panels, such as the status area or hand display, but these must not compromise the separation between the board buffer and the session log buffer.

## 5. Board Buffer and Cursor Behavior
### 5.1. Ordinary Emacs text buffer
The board must be rendered in an ordinary Emacs text buffer using characters and appropriate text properties.

It must not be implemented as a separate graphical surface that bypasses normal Emacs text-buffer behavior.

The board buffer must use non-wrapping lines. Each character cell must correspond to a stable board coordinate, with the renderer preserving the mapping between text positions and board positions.

The board may be larger than the visible window in both dimensions.

### 5.2. Horizontal and vertical scrolling
The board must not be scaled down merely to fit inside the frame.

When the board exceeds the visible window, the user must navigate it using normal Emacs cursor movement and scrolling behavior.
The cursor must remain visible while navigating. As it approaches the edges of the visible area, Emacs must scroll or recenter the view horizontally or vertically as appropriate, including moving the visible region left, right, up, or down.

The implementation should use native Emacs buffer and window mechanisms, with appropriate settings where needed to support horizontal scrolling in a non-wrapping buffer.

The exact recentering distance may depend on ordinary Emacs scrolling settings. The essential requirement is that the cursor can travel across the entire board without wrapping lines, becoming inaccessible, or requiring the whole board to fit in the window.

The game must not replace native navigation with a custom camera or graphical panning system unless such a system is explicitly introduced as an optional feature.

### 5.3. Board and log text behavior
The board and the log have different display requirements:
- **Board:** lines must not wrap. A long row extends horizontally and may require horizontal scrolling.
- **Side log:** messages must wrap naturally onto additional lines to remain readable within the narrower log window.

Scrolling the board must not scroll the log, and scrolling the log must not move the board cursor.

New log messages should cause the log to follow the latest entry, while users remain able to scroll manually through older messages.

### 5.4. Rendering updates
The renderer should update only changed cells whenever practical.

Moving an object should normally update its former position and its destination, not redraw the entire board.

Drawing operations should likewise update affected cells instead of rebuilding the complete buffer after every stroke.

The renderer must keep the displayed text and colors consistent with the in-memory board state.

## 6. Board Files and Board Operations
### 6.1. Opening and creating boards
The package must provide commands for:
- Opening an existing board.
- Creating a new board.
- Opening or creating a board in the current game frame.
- Opening or displaying a board in another game frame.
- Switching the active board.
- Saving a board.
- Saving a board under another file name.
- Closing a board.

The proposed public command names are:

| Command | Behavior |
|---|---|
| `boardgame-open-board` | Select an existing board or offer to create one. |
| `boardgame-create-board` | Create a board after requesting its name and initial settings. |
| `boardgame-open-board-other-frame` | Open or display a board in another game frame. |
| `boardgame-switch-board` | Switch the current game frame to another board. |
| `boardgame-save-board` | Save the current in-memory state to its associated Org file. |
| `boardgame-save-board-as` | Save the board to a newly selected file. |
| `boardgame-close-board` | Close a board after handling unsaved changes. |
| `boardgame-refresh-board` | Refresh the board's rendered representation from its current state. |

The exact public command names may be refined during implementation, but the operations must be available and documented.

### 6.2. File selection and creation
Commands that require an Org file must provide a file-selection workflow.

Opening another board must offer the user a choice of existing board Org files and a way to enter the name of a new board.
If a requested board file does not exist, the package must offer to create it.
The same principle applies to objects, hands, and other resources when creation is valid for the requested operation.
The package must not silently overwrite an existing board or create arbitrary files outside the intended world directory.

### 6.3. Board serialization
The board Org file is the persistent serialization format, not necessarily the live game model.

When loading, the Org file is the source of truth for reconstructing the board's initial in-memory state.
When saving, the current in-memory model is the source of truth for writing the board file.

The file must preserve the information needed to reconstruct equivalent game semantics, including dimensions, felt contents, object placements, relevant object ordering or layering, and supported cell appearance.
The board Org file must remain manually editable.

### 6.4. Board dimensions and felt initialization
A board must have explicit dimensions and a `felt` section containing a source block with the character map.

When loading a board:
- If declared dimensions exceed the stored map, pad missing cells with the configured default felt character, initially `.`.
- If stored content exceeds declared dimensions, ignore characters outside those dimensions.
- The resulting board must conform to its declared dimensions.

A newly created board must contain valid metadata, dimensions, and an initialized felt map.

### 6.5. Adding and removing objects
The board must provide explicit commands for adding and removing objects.

Adding an object must allow the user to select from matching object Org documents in the active world. Fuzzy completion may be used when available.

If the requested object document does not exist, the package should offer to create it.

Removing an object from the board must not automatically delete its independent Org file.

If multiple objects occupy the same cell, a command targeting one object must make the target unambiguous. Separate commands may intentionally affect all objects at that location.

### 6.6. Objects occupying the same cell
Multiple objects may occupy one coordinate.

The implementation may choose the internal representation and rendering order, provided that the behavior is consistent and serialized sufficiently to reconstruct the intended game state.

Only the topmost visible glyph should be rendered.

Where possible, a count marker should appear immediately to the left of the cell:
- `1` through `9` for counts in that range.
- `+` for counts greater than 9.

Omit the marker if it would collide with another object, cross the board boundary, or otherwise render incorrectly.

The marker must not constrain the internal representation of object collections.

When an object moves or is removed, the previous cell must reveal the underlying felt and any remaining objects.

## 7. Object Documents and Object Commands
### 7.1. Object representation
Each independent object is represented by an Org document containing a heading named after the object.

The document may contain:
- Required object properties.
- Object type and deck/container membership.
- Visual glyph.
- Foreground and background colors.
- A description block.
- Executable source blocks.
- Additional properties and descriptive content.

An object file is created on demand. The package must not create a separate object document automatically for every character in the felt.

If a character is associated with an object that has no Org document, the package should offer to create the document when the user requests to open or define it.

Each object must have a properties drawer containing at least the required type and deck/container membership information. An unspecified value must be represented explicitly, using a documented default such as `unspecified`.

Objects consolidated into a stack may be represented as sections of a combined Org document rather than retaining their former standalone files.

### 7.2. Object commands
The package must provide commands for:
| Command | Behavior |
|---|---|
| `boardgame-open-object` | Open the Org document associated with the object under the cursor. |
| `boardgame-create-object` | Create a new object document with its initial heading and required properties. |
| `boardgame-add-object` | Select an object and place it on the board. |
| `boardgame-delete-object` | Remove an object from the board. |
| `boardgame-find-object` | Find an object by property or other supported criteria. |
| `boardgame-describe-object` | Display object and felt information for the current coordinates. |
| `boardgame-describe-object-extended` | Display object information and attempt to execute its description block. |
| `boardgame-query-object-property` | Query a standard or custom property. |
| `boardgame-execute-object-block` | Execute a source block belonging to the selected object. |
| `boardgame-execute-board-block` | Execute a source block associated with the active board. |

Missing properties and optional source blocks must produce clear messages rather than unhandled errors.

### 7.3. Object inspection
The standard description command must display:
- The name and symbol of every object at the cursor coordinates.
- The relevant container's name and symbol, if present.
- The underlying felt symbol.

If multiple objects occupy the cell, the command must describe each of them.

The extended description command must also attempt to execute the object's description block. If the block is missing, the log must report a clear message such as `Description not found`.

### 7.4. Source-block execution
Objects and boards may contain executable source blocks.

The user must be able to execute the appropriate block explicitly. The command must identify its target and report missing blocks or execution failures without leaving the board interface in an inconsistent state.

## 8. Drawing Mode
Drawing is a dedicated feature. It must not be reduced to object-placement commands or described merely as a choice of drawing character.

It must provide ZZT-style character editing of the felt, including character selection, foreground and background colors, pipette sampling, continuous strokes, point-by-point painting, recent-symbol selection, and region-based operations.

### 8.1. Activating drawing mode
Drawing mode must be a separate minor mode or equivalent clearly scoped mode that the user can enable and disable explicitly.

Drawing mode operates on the felt layer, not the object layer.

When drawing mode is enabled, objects must be temporarily hidden as needed to expose the felt. Hiding them must not delete, move, or otherwise alter their state.

When drawing mode is disabled, the objects must be rendered again over the edited felt.

Drawing must not inadvertently modify object positions or object documents.

### 8.2. Movement and Evil integration
The package must not require Evil.

When Evil is available:
- Normal-state cursor movement must remain ordinary navigation.
- Insert-state movement may paint continuously when drawing mode is enabled.
- Normal-state movement must not automatically become painting merely because drawing mode is enabled.
- Explicit drawing commands may be bound in normal state without changing the semantics of ordinary navigation.
- Disabling drawing mode must restore the expected editing behavior.

The package must not force the user into insert state simply because drawing mode is enabled.

When Evil is unavailable, the package must provide usable Emacs-native drawing commands and bindings.

### 8.3. Character selection
The user must be able to select the character used to paint the felt, including spaces.

The drawing interface must provide a recent-symbol menu.

Recent symbols must be ordered by recency, with the most recently used symbol first, except that the currently active symbol should not appear redundantly as another recent choice.

Choosing a recent symbol must change the active drawing character without modifying the board.

### 8.4. Foreground and background colors
The user must be able to select foreground and background colors independently.

Changing a color must not require changing the active character.

The current drawing character and colors should be visible in the status area or another suitable interface element.

Color selection applies to subsequent painting. It must not recolor unrelated cells unless a bulk operation explicitly requests that behavior.

The implementation may choose its color representation, provided that supported colors can be preserved in the board's serialized data.

### 8.5. Continuous painting
Drawing mode must support painting continuously as the cursor moves through cells in the applicable drawing interaction.

When continuous painting is enabled, traversed cells must receive the active character and colors.

Continuous painting must be restricted to the intended drawing interaction. Ordinary navigation outside drawing mode must remain unaffected.

### 8.6. Point-by-point painting
The user must also be able to paint an individual cell explicitly.

Point painting must not require the cursor to travel through intermediate cells.

Both continuous and point-by-point operations must replace the existing felt character at the target cell, including when the selected character is a space.

Painting changes the felt; it does not create a game object.

### 8.7. Pipette
The pipette must sample the underlying felt cell at the selected coordinates.

It must retrieve the existing character and, where available, its foreground and background colors.

The sampled values become the active drawing settings. Sampling must not modify the sampled cell.

### 8.8. Painting a selected region
The user must be able to select a region and apply drawing operations to its cells.

Supported operations must include replacing felt characters and applying the active drawing character and colors.

If objects occupy cells in the selected region, region-based drawing must affect the felt layer only. It must not delete, move, or edit those objects.

The package should support ordinary Emacs region selection and Evil visual selection where practical. It must not globally replace the selection behavior provided by Emacs or Evil.

### 8.9. Text Mode (Overwrite Mode)
Text Mode is a drawing submode that provides standard text-editor-style character replacement directly on the board's felt.
#### Activation and Lifecycle
- Text Mode can be activated while Drawing Mode is enabled.
- It remains active until the user switches to another drawing submode or disables Drawing Mode.
- Switching to another drawing submode must not modify the board beyond the changes already made.
- Disabling Drawing Mode restores the normal board interaction and object rendering.

#### Cursor Movement and Character Input
Text Mode must behave consistently in both vanilla Emacs and Evil.
- Cursor movement follows the active editing environment's normal navigation behavior.
- In vanilla Emacs, normal cursor movement keys move the cursor, while printable character input replaces the character under the cursor.
- In Evil, Normal state retains its standard navigation behavior. In Insert state, printable character input replaces the character under the cursor.
- Text Mode must not globally override Emacs or Evil key bindings, force Evil state transitions, or require Evil to be installed.
- The mode must use the appropriate input mechanism for the active editing environment so that the same character-replacement behavior is available in both vanilla Emacs and Evil.

#### Overwrite Semantics
- Each printable character entered replaces the felt character at the current cursor position.
- After a character is entered, the cursor advances one cell to the right, as in standard overwrite mode.
- Character input must never insert new board columns or shift existing characters to the right.
- The board dimensions remain unchanged.
- Line breaks are not inserted into the board as ordinary text. Any vertical movement or line-boundary behavior must respect the fixed board dimensions.
- Input at the rightmost board cell must follow a documented boundary policy and must never cause the board to expand accidentally.

#### Drawing Colors
- Each entered character is written to the felt using the currently selected drawing foreground and background colors.
- The colors apply to each newly replaced cell independently of the previous character's colors.
- Text Mode modifies the felt layer only. It must not replace, move, or delete objects occupying the same cell.
- If objects are temporarily hidden while Drawing Mode is active, their underlying placements remain unchanged. When Drawing Mode is disabled, objects are rendered over the edited felt as usual.

#### Rendering and Persistence
- Each character replacement updates the underlying felt model and the displayed board.
- Only the affected cell should be redrawn where practical.
- Changes must participate in the board's normal save and unsaved-change tracking.
- Text Mode must preserve the board's fixed-width, non-wrapping layout and normal Emacs scrolling behavior.

### 8.10. Drawing and rendering
Drawing must update the affected board cells promptly.

The renderer should not rebuild the entire board after every painted character.

Leaving drawing mode must restore object visibility without losing changes to the felt.

The current drawing character, colors, and mode status should be available in the status display or another configurable indicator.

## 9. Hands: Org-Based Stacks
### 9.1. Core Concept
A hand is a regular Org file. It has no dedicated graphical representation in the game frame.

Each top-level heading in the hand file represents one item held in the hand. The heading and its entire subtree constitute that item, including its properties, nested headings, source blocks, and other Org content.

A hand is conceptually a stack with the following characteristics:
- Items are ordered by their heading order in the Org file.
- The first top-level heading is the top item.
- Items are moved into and out of the hand as complete Org subtrees.
- The hand does not interpret or execute an item's internal content merely because the item is added to the hand.
- The hand does not have its own rendered board representation.
- The hand is manipulated through commands and can be inspected by opening its Org file.

There may be multiple hand files, but only one hand is active for a game session. The active hand is configurable and can be changed explicitly.

### 9.2. Opening and Inspecting a Hand
Provide a command to open the active hand's Org file in a regular Emacs buffer.

The user can inspect and edit the file using normal Org-mode functionality. There is no separate hand viewer, card renderer, or mandatory hand window.

The package must not require the hand file to remain open while the game is running. Commands that manipulate the active hand must work whether its buffer is already open or needs to be opened.

The package must preserve the order of items and the complete content of each item when saving and loading the hand.

### 9.3. Commands Available in Org Buffers
Commands for transferring items must be available in ordinary Org buffers, not only in the game frame or active hand.

When a command operates on an Org heading, the current Org heading identifies the item to operate on. The command must determine the relevant subtree and preserve it as a complete unit.

For example, the command to place an item on the board can be invoked:
- From the active hand's Org buffer.
- From any other Org file containing the heading to be transferred.
- From a game command menu or key binding when an appropriate source item is identified.

The command's behavior must be consistent regardless of the source buffer.

Commands that require an active board must use the package's documented active-board resolution mechanism. If no valid target board exists, the command must report the problem and ask the user to select or open a board rather than silently choosing an unrelated board.

### 9.4. Placing an Org Heading on the Board
The command to place an item on the board transfers the current Org heading and its complete subtree into a new object Org file.

The operation must:
1. Identify the current heading and its complete subtree.
2. Preserve the subtree's content and hierarchy.
3. Create a standalone Org file containing that heading and subtree.
4. Ensure that the resulting object has a usable display symbol.
5. Register the new object in the active board's object layer at the cursor position.
6. Remove the transferred subtree from the source Org file only after the destination object has been created and the transfer can be completed safely.
7. Update the source and destination buffers and their unsaved-change state.

The command must not leave two independently active copies of the same transferred item when the intended operation is a move.

If the operation fails, the source content must not be silently lost. The implementation must report the failure and preserve enough state to recover the item.

#### 4.1. Display Symbol
An Org heading may not define a display symbol in its properties.

When the transferred heading has no usable symbol, derive the symbol from the first character of the heading title, excluding the Org heading markers and heading-level whitespace.

For example, a heading named `Dragon` can use `D` as its display symbol.

If the heading title is empty or its first character cannot provide a usable display symbol, use a fallback symbol `*` and report or otherwise expose that fallback to the user.

An explicitly configured valid symbol takes precedence over the derived symbol.

The derived symbol is the object's display glyph; it does not replace or rename the original heading.

### 9.5. Taking an Ordinary Object from the Board
Taking an ordinary object from the board transfers it into the active hand.

The operation must:
1. Identify the selected object at the cursor position.
2. Read the object's Org file and identify its root heading and complete subtree.
3. Insert that heading and subtree into the active hand as one top-level item.
4. Remove the object's placement from the board.
5. Remove the standalone object file only after its content has been transferred successfully and no remaining references or placements require that file.
6. Preserve the relative order of existing hand items and place the newly acquired item at the top of the hand.

The operation must preserve the object's complete Org content, including properties, nested headings, source blocks, and descriptions.

If multiple ordinary objects occupy the same board cell, the command must identify which object is being taken according to the package's documented object-selection behavior. It must not accidentally take every object at that position.

### 9.6. The Hand as a Simple Stack
The hand does not automatically unpack, interpret, merge, or transform an item's internal content.

Each heading is one item, regardless of whether its subtree contains a simple object description, many nested headings, executable source blocks, or other structured Org data.

The default operations are:
- **Take:** transfer an item into the active hand.
- **Place on board:** transfer the current heading from an Org file to the board as a standalone object.
- **Open active hand:** open the active hand's Org file.
- **Select active hand:** choose which hand file receives and supplies items.

The package may provide additional commands, but they must not undermine the rule that a hand item is represented by one complete Org subtree.

### 9.7. Containers and Stacks
Containers and stacks are special board objects. They cannot be transferred into a hand as containers or stacks.

The command to take an item while the cursor is over a container or stack has different semantics from taking an ordinary object.

Instead of transferring the container or stack itself, the command takes the top item contained within it.

The operation must:
1. Identify the container or stack at the cursor position.
2. Select its top item according to the ordering rules defined for that container or stack.
3. Transfer that item's complete Org content into the active hand as a top-level heading.
4. Remove the item from the container or stack's contents.
5. Leave the container or stack itself on the board.

For this purpose, specialized function of the containerrs themselves are used. The hand does not perform operations on containers, but requests objects from the container, using their standard commands.

For a permanent container, this removes the item reference from the container without deleting the item's standalone Org file unless the container's storage model explicitly requires a safe transfer of the item's content.

For a stack, this extracts the top item from the stack's combined Org representation. The implementation must preserve the extracted item's complete content and correctly update the remaining stack.

If the container or stack is empty, the command must report that there is no item to take. It must not remove the container or stack.

The container/stack command must never transfer the container or stack itself into the hand.

### 9.8. Command Availability and Context
The same transfer operations must be accessible from the game interface and relevant Org buffers.

The package must distinguish between:
- The current Org heading, which identifies a source item.
- The active hand, which is the destination for a take operation.
- The active board, which is the destination for a place-on-board operation.
- The container or stack under the board cursor, which supplies its top item when taking from a container or stack.

A command must not assume that the current Org buffer is the active hand. An arbitrary Org heading can be transferred to the board without first copying it into the hand.

Likewise, a command to take an item from the board always targets the active hand, regardless of which Org buffer happens to be visible.

### 9.9. Consistency and Error Handling
All transfers must preserve the complete item subtree and prevent silent data loss.

The implementation must account for:
- Missing or invalid active-hand files.
- Missing or invalid target boards.
- Headings with no usable display symbol.
- Empty containers and stacks.
- Missing object files.
- File creation or write failures.
- Existing object references or placements.
- Attempts to transfer a container or stack itself into the hand.
- Attempts to transfer an item when its source cannot be identified unambiguously.

The source item must not be deleted before its destination has been successfully established. Where a transfer spans multiple files, the implementation must define a safe write and cleanup order and report partial failures clearly.

### 9.10. Acceptance Criteria
1. The active hand is an ordinary Org file and has no mandatory graphical representation.
2. Opening the active hand displays its actual Org content in a normal Emacs buffer.
3. Each top-level heading in the hand represents one item.
4. The user can invoke the place-on-board command from the active hand or any other Org buffer.
5. Placing a heading creates a standalone object Org file containing the complete heading subtree.
6. A missing display symbol is derived from the heading's first character, subject to a documented fallback.
7. A successful placement removes the transferred subtree from the source Org file.
8. Taking an ordinary board object transfers its complete Org content into the active hand and removes its board placement.
9. A successful take removes the standalone object file only when doing so is safe and appropriate.
10. Taking from a container or stack extracts its top item rather than transferring the container or stack.
11. Containers and stacks cannot themselves be placed in the hand.
12. Empty containers remain intact when a take operation is attempted.
13. Failed transfers do not silently discard source content.
14. Item ordering is preserved and updated consistently during transfers.
15. The behavior is independent of whether the active hand's buffer is currently visible.
## 10. Stacks and Containers
### 10.1. Explicit stack creation
A stack is an explicit consolidation operation. It must not be created automatically because several objects occupy the same cell.

The stack command must accept a list of object coordinates, defaulting to the objects under the cursor when no explicit list is supplied.

Stack creation must:
1. Identify the selected objects and their Org content.
2. Consolidate their content into a combined Org document.
3. Successfully write the consolidated representation.
4. Remove the former standalone object files after successful consolidation.
5. Remove the selected individual placements from the board.
6. Place one stack object at the designated stack location.

The combined document must preserve the information needed to represent the consolidated objects and their relevant content and properties.

The resulting object gets the `$` character as the default character to display, on a white background in black font color.

The implementation must not delete original object documents before the consolidated document has been successfully created.

The lifecycle of a stack when its contents are later extracted, including whether a one-member stack dissolves automatically, must be explicitly documented by the implementation.

### 10.2. Permanent containers
A permanent container is a persistent object represented by its own Org file.

It organizes references to other objects without merging their Org documents or deleting their independent files.

Placing an object on top of a permanent container must remove its visible board placement and add a reference to the container's contents.

The object's independent Org file remains intact.

Containers may hold individual objects, stacks, or other containers.

An empty container remains on the board unless explicitly deleted.

### 10.3. Container commands
The package must provide commands to:
- Create a permanent container.
- Open or inspect a container.
- Add an object to a container.
- Add a card from the active hand to a container.
- Draw an object from a container into the active hand.
- Draw the top item.
- Draw the bottom item.
- Draw a random item.
- Open or reveal a card beside or above its deck.
- Shuffle a deck or container.
- List contents in random order unless another order is requested.
- Lay out all contents on the board.
- Execute supported container source blocks.
- Refresh object properties from Org files when cached or displayed properties are stale.
- Explicitly delete a container.

Deleting a container must not silently delete the independent files of its contents.

### 10.4. Revealing and laying out contents
A command to reveal or list container contents must use randomized order by default unless another order is requested.

Operations that explicitly request top-to-bottom, bottom-to-top, or another supported ordering must respect that order.

Laying out a container's contents must place each item into a previously free cell around the source container.

The operation must not overwrite unrelated objects or silently lose items when there is insufficient space. It must report the limitation and leave any unplaced items available in the container.

A container may hold a stack as a single item. Adding a stack to a container must not automatically unpack or reconsolidate it.

### 10.5. Container source blocks
A container may define executable source blocks for operations such as drawing or shuffling.

The package must provide a documented way to execute the relevant block. Missing optional blocks must be handled gracefully.

## 11. Cursor Navigation and Navigation Markers
### 11.1. General-Purpose Cursor Navigation
The package must provide a general-purpose command that moves the cursor to specified coordinates on a specified board.

The command accepts three parameters:
- `BOARD`: the target board's filename, including its extension.
- `X`: the target horizontal coordinate.
- `Y`: the target vertical coordinate.

The board filename is the sole identifier used to resolve a board within the active world. No separate board ID, UUID, or alternative identity mechanism is required.

When `BOARD` is omitted, the command targets the active board according to the package's active-board resolution rules.

The command must:
1. Resolve the target board by its filename within the active world's board directory.
2. Verify that the board exists and can be opened.
3. Validate the requested coordinates against the board dimensions.
4. Display or activate the target board as necessary.
5. Move the cursor to the specified cell.

If the target board is already displayed in another game frame, the command must follow the package's documented board-navigation policy without unexpectedly replacing the board in an unrelated frame.

Missing boards, invalid filenames, and out-of-range coordinates must produce clear errors. The command must never silently substitute a different board or move the cursor to an unintended location.

This command is independent of navigation markers. It can be invoked by any object source block or other package code that needs to navigate to a board position.

### 11.2. Object Identity and Naming
A navigation marker is an ordinary object and follows the general object-document rules.

Each object is represented by an Org file. Three distinct concepts must be kept separate:
- **Object filename:** the name of the Org file on disk.
- **Object name:** the title of the object's first top-level Org heading.
- **Display glyph:** the character used to render the object on the board.

Unless explicitly stated otherwise, references to an object's name throughout this specification mean the title of its first top-level Org heading, not the filename.

The first top-level heading is the object's root heading. Its entire subtree constitutes the object's document content.

For example, an object file may contain:

```org
* Marker Dungeon.org (12, 8)
:PROPERTIES:
:OBJECT_TYPE: "marker"
:GLYPH: "^"
:FOREGROUND: white
:DESTINATION_BOARD: "Dungeon.org"
:DESTINATION_X: 12
:DESTINATION_Y: 8
:END:
```

In this example:

- The object name is `Marker Dungeon.org (12, 8)`.
- The object filename is the actual filename of the Org file, which may be derived from the object name using filesystem-safe naming rules.
- The display glyph is `^`.

The root heading title is the authoritative object name. Changing that title renames the object; renaming the file is a separate operation and must not be implied by changing the heading.

### 11.3. Navigation Markers as Ordinary Objects
A navigation marker is an ordinary object whose source block invokes the general-purpose cursor-navigation command.

It does not require a dedicated object type in the engine, a special navigation data structure, or a separate teleportation subsystem.

Its behavior is determined by its Org properties and source block. Executing the source block navigates to the destination stored in those properties.

The marker's current position on the board and its stored destination are independent:
- The current position determines where the marker is displayed.
- The stored destination determines where the cursor moves when the marker's source block is executed.

Moving the marker must not automatically change its destination properties.

### 11.4. Create Navigation Marker Command
The package must provide a dedicated command that creates a navigation marker at the current board cursor position.
#### 4.1. Generated Object Name
The command generates the marker's root heading title using this format:
`Marker (board filename) (x, y)`

For example, creating a marker at coordinates `(12, 8)` on `Dungeon.org` produces the object name:
`Marker Dungeon.org (12, 8)`

The board filename, including its extension, is used in the object name. The coordinates identify the cell where the marker was created.

The generated title becomes the title of the first top-level Org heading in the new object file. It is not merely a filename or a separate metadata field.

The object filename must be derived from the generated object name using filesystem-safe naming rules. If the resulting filename already exists, the command must not overwrite it. It must generate a unique alternative or ask the user how to proceed without changing the intended object name unnecessarily.

#### 4.2. Display Properties
The generated object must have these display properties:
- **Glyph:** `^`
- **Foreground color:** white.
- **Background color:** unspecified.

An unspecified background allows the underlying felt background to remain visible.

The marker is an ordinary board object and can be moved, taken, placed in a hand, or transferred to another board using the same operations available to other objects.

#### 4.3. Destination Properties
The generated Org file must store the original destination in explicit Org properties:
- `DESTINATION_BOARD`: the destination board's filename, including its extension.
- `DESTINATION_X`: the horizontal coordinate at creation time.
- `DESTINATION_Y`: the vertical coordinate at creation time.

The destination board filename is resolved relative to the active world's board directory. No separate board identifier or absolute path is required.

These properties describe the marker's destination, not its current position. They must remain unchanged when the marker is moved to another cell or another board.

#### 4.4. Source Block
The generated object must contain a source block that reads the destination properties and invokes the general-purpose cursor-navigation command.

The source block must not hardcode the destination filename or coordinates in its executable body. It must retrieve the values from the object's Org properties and pass them to the navigation command.

Its behavior is conceptually:
1. Read `DESTINATION_BOARD` from the marker's Org properties.
2. Read `DESTINATION_X` and `DESTINATION_Y` from the same properties.
3. Invoke the general-purpose cursor-navigation command with these values.
4. Let the navigation command resolve the board by filename, validate the coordinates, and move the cursor.

This demonstrates that object behavior can be parameterized through Org properties rather than embedding configuration directly in source code.

The source block must use the package's standard object-source execution mechanism. The package must not introduce a separate execution mechanism specifically for navigation markers.

#### 4.5. Creation Behavior
When the user invokes the create-marker command, the package must:
1. Identify the current board and obtain its filename.
2. Capture the current cursor coordinates.
3. Generate the marker's object name according to the naming rule above.
4. Create a new Org file with the generated root heading, display properties, destination properties, and source block.
5. Register the new object on the current board at the cursor position.
6. Refresh the affected board cell and saved-change board's state.

The command must not silently overwrite an existing object file. If file creation or board registration fails, it must report the failure and avoid silently leaving an orphaned object.

### 11.5. Expected Behavior
The intended workflow is:
1. The user positions the cursor at a desired cell on a board.
2. The user invokes the create-marker command.
3. The package creates a standalone Org file whose first top-level heading identifies the marker.
4. A `^` glyph appears at the creation position, with a white foreground and unspecified background.
5. The marker's properties record the original board filename and coordinates.
6. The user moves the marker to another position, including a different board in the same world.
7. The user executes the marker's source block using the standard object-source execution mechanism.
8. The cursor returns to the board identified by `DESTINATION_BOARD` and to the coordinates stored in `DESTINATION_X` and `DESTINATION_Y`.

The marker does not need to remain at its original location to work. Its source block always uses the stored destination properties.

### 11.6. Error Handling
The navigation command and marker source block must handle these conditions:
- `DESTINATION_BOARD` is missing or invalid.
- The destination board file no longer exists.
- The destination coordinates are missing, invalid, or outside the board dimensions.
- The destination board cannot be opened.
- Required marker properties or the source block are missing.
- The marker cannot be created because of a file conflict or write failure.
- The marker file is created but registration on the board fails.

Errors must be reported clearly. Navigation must never silently substitute another board. Failed creation or registration must not silently discard the marker's content.

### 11.7. Acceptance Criteria
1. The package provides a general-purpose command for moving the cursor to coordinates on a specified board.
2. The command identifies boards exclusively by filename within the active world.
3. A navigation marker is an ordinary object, not a dedicated engine entity.
4. The marker's object name is the title of its first top-level Org heading.
5. The generated object name contains the original board filename and creation coordinates.
6. The marker uses the `^` glyph, a white foreground, and an unspecified background.
7. The destination board filename and coordinates are stored in Org properties.
8. The source block reads those properties instead of hardcoding the destination values.
9. Executing the source block invokes the same general-purpose cursor-navigation command available to other objects.
10. Moving the marker does not alter its destination properties.
11. The marker can navigate to its original location from another board in the same world.
12. Missing boards and invalid coordinates produce clear errors.
13. Creating a marker never silently overwrites an existing object file.
14. File creation and board registration failures are reported without

## 12. Side Log and Status Area
### 12.1. General Concept
Each world has one persistent log stored as a regular Org file.
The log is an ordinary Org document, not a temporary message buffer or a custom-rendered interface. It must remain editable using standard Org-mode and Emacs functionality.

The log serves as the world's shared record of events, messages, descriptions, and other information explicitly written to it by game commands and object source blocks.

All game frames displaying boards from the same world share the same log file and log buffer.

### 12.2. Log Filename and Location
The log file is stored in the world's directory and named according to this convention:
`(world name)-log.org`

For example, a world named `Dungeon` uses:
`Dungeon-log.org`

The exact filename must be derived consistently from the world's configured name. Filesystem-safe naming rules must be applied where necessary.

The log belongs to the world, not to an individual board or game frame. Switching between boards in the same world must not switch to a different log.

### 12.3. Automatic Creation
When a game frame is opened for a world, the package must check whether that world's log file exists.
- If the log file exists, open and display it.
- If the log file does not exist, create a new Org file at the expected location and display it.
- If the file cannot be created or opened, report the error clearly rather than silently substituting a temporary log.

All game frames for the same world must use the same log file and, where possible, the same Emacs buffer visiting that file.

Creating an additional game frame must not create a duplicate log for the same world.

### 12.4. Org Structure of Log Entries
Each new top-level log entry must begin with a level-one Org heading:
`* Entry title`

The heading represents one log entry. Its title should be a concise description of the event or message.

Additional information belonging to that entry must be stored under nested headings:
- `**` for direct subsections.
- `***` for subsections of those subsections.
- Further heading levels as required.

This structure allows a log entry to contain multiple related messages, parameters, descriptions, or other structured content without mixing them with unrelated entries.

For example:
```org
* Marker activated
** Destination
- Board: Dungeon.org
- X: 12
- Y: 8
** Result
The cursor moved to the destination.

* Container opened
** Contents
- Key
- Map
```

The example illustrates the structure; actual entry titles and content depend on the command or source block writing the entry.

The package must not flatten nested information into a single unstructured message when the caller supplies structured content.

### 12.5. Log Writing Interface
The package must provide a common logging interface for game commands and object source blocks.

The interface must support:
- Creating a new top-level log entry.
- Appending content to an existing entry when explicitly requested.
- Adding nested sections to an entry.
- Recording plain text and structured Org content.
- Including Org-compatible links, images, and other supported Org elements when supplied by the caller.

Unless an existing entry is explicitly targeted, a new logging operation creates a new top-level entry.

All package-generated log content must be inserted using valid Org syntax and must preserve the existing document's structure.

Normal Emacs messages, warnings, and errors must not automatically be copied into the world log. Only information explicitly sent through the package's logging interface belongs there.

### 12.6. Standard Org Editing and Rendering
The log buffer must behave like a regular Org buffer.

The user must be able to:
- Edit and delete log entries using standard Emacs commands.
- Change headings and rearrange sections.
- Fold and unfold headings.
- Use standard Org navigation and editing functionality.
- Insert and view supported images and links.
- Use ordinary Org formatting and other standard document features.

The package must not impose a read-only mode on the log or replace standard Org editing behavior with a custom message viewer.

Images and other Org elements must be handled through normal Org-mode functionality rather than a separate log-rendering system.

The package must preserve user edits when new entries are appended. It must not rebuild the entire log from an internal message history or overwrite manual changes.

### 12.7. Shared Log Across Game Frames
Every game frame associated with the same world must display the same persistent log.

Consequently:
- A new entry written from one game frame must appear in the shared log buffer used by the other frames.
- Manual edits to the log must remain visible wherever that buffer is displayed.
- Board switching must not reset or replace the log.
- Opening another board in the same world must not create a new log.
- Different worlds must use different log files and buffers.

The log window's navigation and scrolling remain independent of the board window's navigation and scrolling.

New entries should normally be visible by moving the log window to the newest entry after a package-generated write. This behavior must not interfere with the user's ability to navigate and edit older entries.

### 12.8. Persistence and Saving
The world log is a persistent file belonging to the world.
The world log will be saved every time any board is saved.

Changes made by game commands, object source blocks, and manual editing must be tracked as ordinary buffer modifications. The package must not silently discard unsaved log changes.

The implementation must define when package-generated entries are written to disk and ensure that the policy is consistent with normal Emacs buffer-saving behavior. If the log is saved automatically, that policy must not overwrite concurrent unsaved user edits.

The log and each board are separate Org files with independent modification states.

### 12.9. Error Handling
The package must handle:
- A missing log file.
- Failure to create or open the log file.
- A log buffer that cannot be written to disk.
- Invalid Org content supplied to the logging interface.
- Attempts to append content when the intended entry cannot be identified.
- Concurrent changes or unsaved edits that could otherwise be overwritten.

Errors must be reported clearly. The package must never silently replace a persistent log with a temporary buffer or discard existing log content.

### 12.10. Acceptance Criteria
1. Every world has one persistent Org log file.
2. The log filename follows the world-name-based naming convention.
3. Opening a game frame creates the log file if it does not exist.
4. Game frames displaying boards from the same world share the same log buffer.
5. Every new independent log entry begins with a level-one heading.
6. Related information can be represented using nested Org headings.
7. The log remains a normal, editable Org document.
8. Standard Org folding, navigation, editing, image display, and link handling remain available.
9. Package-generated entries do not erase manual edits.
10. Only content explicitly sent through the package's logging interface is added to the log.
11. The log has an independent persistence lifecycle from individual boards.
12. Unsaved log changes are not silently discarded.

### 12.11. Log Window and Status Area Layout
The right-hand side of the game frame contains two separate Emacs windows arranged vertically:
1. **Log window:** displays the world's persistent Org log buffer.
2. **Status window:** displays the current game status.

The log and status area are separate windows displaying separate buffers. The status area is not a section of the log file and must not be rendered as part of the log buffer.

#### 6.1. Window Proportions
The default game frame layout is:
- The board window occupies approximately 80% of the available horizontal space.
- The right-hand column occupies approximately 20% of the available horizontal space.
- Within the right-hand column, the log window occupies approximately 80% of the available vertical space, and the status window occupies approximately 20%.

These proportions must be configurable.

The layout must use standard Emacs window-management facilities. The package must not simulate the board, log, or status area as artificial regions within a single buffer.

#### 6.2. Status Buffer
The status area must display the current game state using a separate buffer.

Depending on the available information, it may show:
- Active board filename.(better in the frame title)
- Active hand.
- Object under the board cursor and its relevant properties.
- Current drawing submode and selected glyph or colors.
- Other useful game-state information explicitly supported by the package.

The status buffer is a display of current state, not a persistent event log. Its contents must be refreshed when relevant game state changes.

Status updates must not create log entries unless a command explicitly requests a corresponding log entry.

The status area must not interfere with editing or navigation in the log buffer.

#### 6.3. Independent Behavior
The log and status windows must have independent purposes and navigation behavior.
- Scrolling the log must not affect the board or status area.
- Updating the status buffer must not move the log's point or replace its contents.
- Appending a log entry must not overwrite status information.
- Switching boards must update the appropriate status information while preserving the world's shared log.
- Multiple game frames associated with the same world share the same log buffer, but each frame may display its own status buffer reflecting the board and game context relevant to that frame.

#### 6.4. Lifecycle
When a game frame is created, the package must establish the board, log, and status windows.

The log window displays the persistent world log described in this specification. If the log file does not exist, it is created according to the automatic-creation rules.

The status buffer may be temporary and can be recreated when necessary. It must not be confused with the persistent log file.

Closing a game frame must not delete the world's log file or discard unsaved log changes. Closing one frame must not invalidate the shared log buffer while another frame still uses it.
## 13. Commands and Keyboard Bindings
### 13.1. Interactive command availability
Every principal operation must be accessible through a documented interactive command, even when no optional menu package is installed.

The public command reference must include commands for game startup, world selection, board management, object management, drawing, hands, stacks, containers, teleportation, and logging.

The proposed command names in this document may be refined, but their functionality must be preserved and names must be consistent throughout the implementation, documentation, and tests.

### 13.2. Function keys and sequential key chords
The game keymap may use F1 through F12 for game commands.

The package must support sequential key sequences of up to three key presses. For example, pressing `F5` followed by `F1` is a two-key sequence.

These are sequential key sequences, not simultaneous physical key combinations.

Bindings must be documented and configurable. The package should avoid unnecessary conflicts with the user's existing keymaps.

### 13.3. Evil compatibility
Standard Evil normal-mode movement must not be globally overridden.

Normal state must remain suitable for navigation, object inspection, and command invocation. Insert-state movement may paint while drawing mode is active.

The package must remain usable without Evil. Hydra may provide optional menus, but no essential operation may depend on it.

## 14. Error Handling and Unsaved Changes
The package must handle missing or invalid resources, missing properties, absent source blocks, invalid coordinates, empty containers, invalid card indices, insufficient free board cells, and failed saves with clear messages.

A command must not silently delete unrelated objects or files, overwrite another board, or leave the game state inconsistent after a failed operation.

Destructive operations must distinguish between removing a board placement, removing an item from a container, consolidating objects into a stack, and deleting persistent resources.

Unsaved board changes must be tracked independently for each board. Switching frames or changing the active-board variable must not silently discard another board's state.

When version-control integration is enabled, successful saves should be followed by a Git commit of the world state. Git provides rollback and recovery but does not replace correct file-writing and error handling.

## 15. Acceptance Criteria
The implementation is considered compliant with this interface specification when:
1. The game can start with an explicit world directory.
2. The game can use a configurable default world directory when no argument is supplied.
3. If neither a usable argument nor a usable default is available, the user is offered a world-selection workflow.
4. A missing requested world or board can be created through an appropriate prompt.
5. Starting the game opens a dedicated game frame without replacing the user's existing editing frame.
6. Multiple boards can be switched within one game frame.
7. Different boards can be displayed in different game frames simultaneously.
8. Frames displaying boards from the same world share the same world-level log buffer.
9. A global active-board variable identifies the current implicit command target and is updated consistently.
10. Board buffers behave as ordinary Emacs text buffers, with non-wrapping lines and usable horizontal and vertical scrolling.
11. The cursor remains navigable across boards larger than the visible window, using Emacs-native scrolling and recentering behavior.
12. Log text wraps naturally, independently of board scrolling.
13. Boards can be created, opened, saved, saved under another name, and closed without silent loss of unsaved changes.
14. Objects can be created, opened, inspected, queried, executed, added, and removed through documented commands.
15. Drawing mode supports character selection, foreground/background colors, pipette sampling, continuous painting, point painting, recent symbols, and region operations.
16. Drawing changes the felt without unintentionally modifying the object layer.
17. Hands support ordering, active-hand switching, first/last/selected/random card operations, source-block execution, and blind operations.
18. Permanent containers preserve independent object files, while explicit stack creation consolidates selected object documents.
19. Container operations support drawing, shuffling, revealing, and laying out contents without silently losing items.
20. Cursor Navigation Between Boards to coordinates is supported.
21. Game messages are written to the appropriate shared log without automatically importing ordinary Emacs messages.
22. Evil and Hydra remain optional.
23. Failure conditions are reported clearly, and operations avoid silent data loss.
24. Module-level unit tests and project-wide integration tests verify the documented behavior.

The guiding principle is to make user-visible behavior explicit and consistent while allowing the implementation to remain modular, readable, and free to choose suitable internal data structures.
