# Boardgame.org — Commands and Gameplay Behavior
## 1. Purpose and Scope
`boardgame-org-interface.md` defines the user-visible behavior of `boardgame.org`: how the game starts, how users interact with boards and objects, how drawing works, how hands and containers behave, and how game data is opened, created, saved, and managed.

This document complements the architecture and implementation specification. It defines required behavior without unnecessarily prescribing internal data structures, algorithms, or implementation details.

The package is an Emacs Lisp text-based tabletop game engine inspired by ZZT and ASCII board games. Org mode is a hard dependency. Hydra may optionally be used to provide command menus, but it must not be required. Evil compatibility is desirable, but Evil must not be a dependency.

## 2. Core Concepts
The game consists of the following concepts:

- **World:** a directory containing boards, object Org files, hands, containers, and other world-specific data.
- **Board:** a rectangular character-based game space with a felt layer and movable objects.
- **Felt:** the underlying character map, including spaces and arbitrary text characters.
- **Object:** a game entity represented by an Org document or a section within a consolidated stack document.
- **Hand:** an ordered collection of cards or objects represented by an Org file.
- **Container:** a persistent object that organizes references to other objects without merging their independent Org files.
- **Stack:** an explicitly created consolidation of objects into a combined Org document.
- **Card/deck:** an object or collection of objects that can be selected, drawn, played, shuffled, or executed.
- **Game frame:** a dedicated Emacs frame containing the board and side log.
- **Side log:** a game-specific message area that displays only messages explicitly sent to it.

The implementation may choose the most efficient internal representation for these concepts. The observable behavior and persistence semantics defined here must remain consistent.

## 3. Starting the Game and Managing the Frame
### 3.1. Starting the game
The command `boardgame-start` must open a dedicated Emacs frame for the game session.

The game must not replace the user's existing editing frame or require the user to abandon their current Emacs workspace.

The game frame must provide the following layout:

- **Board area:** approximately 80% of the frame width, on the left.
- **Side-log area:** approximately 20% of the frame width, on the right.
- **Optional status area:** a horizontal split in the side-log region, reserving approximately 20% of that region for persistent game information and leaving the remainder for messages.

The proportions must be user-configurable.

The status area may display information such as global variables, tokens, active object properties, the active hand, and drawing-mode settings.

The board must be displayed in a dedicated game buffer, not as a normal Org document. Its associated Org file is the format used for loading and saving the board.

The board buffer must be an ordinary Emacs text buffer. Character colors should be implemented with text properties or another appropriate text-based rendering technique.

Board lines must not wrap. A board may be wider or taller than its visible window. Native Emacs scrolling and cursor visibility behavior should be preserved; the package must not force the entire board to fit into the window.

### 3.2. Worlds and multiple boards
Only one world may be active at a time, but multiple boards from that world may be open simultaneously.

Switching worlds must not silently discard unsaved changes in any open board.

Each open board must retain its own identity and state. Switching between boards must not accidentally overwrite one board with another.

The user must be able to open a different board while keeping the current board open.

### 3.3. Closing the game

Closing the game frame or session must not silently discard unsaved board changes.

The package must provide a clear workflow for saving, abandoning, or cancelling an operation when unsaved changes exist.

Closing the game interface must not automatically delete world files, object files, hands, containers, or saved boards.

## 4. Worlds, Files, and Resource Creation

### 4.1. World structure

A world is a directory containing all files belonging to that game world. It may contain:

- Board Org files.
- Independent object Org files.
- Hand Org files.
- Container and deck definitions.
- Consolidated stack documents.
- Optional persistent logs.
- Other world-specific metadata or resources.

The exact directory structure may be configurable, but the default must be predictable and documented.

References between resources should use world-relative paths wherever practical.

### 4.2. Missing resources

A missing resource must not automatically be treated as a fatal error.

When the user requests a world, board, object, or other persistent resource by name, and that resource does not exist, the package must offer to create it when creation is appropriate.

Examples:

- Opening a missing world should offer to create its directory and initialize it.
- Opening a missing board should offer to create a new board.
- Opening a missing object should offer to create its Org document.
- Opening a missing hand should offer to create a hand file when the operation permits creation.

Creation must not silently overwrite existing files. The package must distinguish between a missing resource, an invalid path, a malformed document, and an inaccessible location.

### 4.3. File-selection workflow

Commands that require an Org file must provide a file-selection or completion workflow.

For example, `boardgame-open-board` must let the user choose an existing board Org file or enter a name for a new board.

The user should not have to remember absolute paths for ordinary world-internal operations.

Fuzzy completion may be used when available, but the package must remain usable without a particular fuzzy-finder package.

### 4.4. Board creation

A newly created board must contain valid metadata, dimensions, and an initialized felt map.

The initial felt character must be configurable, with `.` as the default.

A newly created board must be associated with a persistent Org file so it can subsequently be saved and reopened.

### 4.5. File operations and data safety

The package must clearly distinguish between:

- Removing an object from a board.
- Removing an object from a container.
- Consolidating objects into a stack.
- Deleting a container.
- Deleting an independent object file.
- Closing an unsaved board.
- Deleting a saved board or world.

These operations must not be treated as interchangeable.

Destructive operations must provide appropriate confirmation and must not silently delete unrelated resources.

The world should use Git for version history when version-control integration is enabled. After a successful save, the package should commit the resulting world state. Git provides rollback and recovery, but it does not replace correct file writing and error handling.

## 5. Board Operations

### 5.1. Opening and saving boards

The following public commands are required:

| Command | Behavior |
|---|---|
| `boardgame-open-board` | Select an existing board or offer to create one. |
| `boardgame-create-board` | Create a new board after requesting its name and necessary initial settings. |
| `boardgame-save-board` | Save the current in-memory board state to its associated Org file. |
| `boardgame-save-board-as` | Save the board to a newly selected file without silently replacing another board. |
| `boardgame-close-board` | Close the current board after handling unsaved changes. |
| `boardgame-refresh-board` | Refresh the rendered representation from the current game state. |

These names are proposed public API names. Additional commands may be added where necessary.

The Org board file is the serialized representation of the board, not necessarily the live in-memory model.

When loading, the file is the source of truth. When saving, the in-memory game model is the source of truth.

Loading and saving must preserve equivalent gameplay semantics, including dimensions, felt contents, object placement, and relevant object ordering or layering information.

### 5.2. Board representation and dimensions

A board is a rectangular map of character cells.

Its Org file must store its dimensions and contain a `felt` section with a source block holding the character map.

When loading a board:

- If the declared dimensions exceed the dimensions of the stored map, missing cells must be padded with the configured default character, initially `.`.
- If the stored map contains characters outside the declared dimensions, those extra characters must be ignored.
- The resulting board must conform to the declared dimensions.

The serialization format must remain readable and manually editable in Org mode.

### 5.3. Felt layer

The felt layer is the underlying board surface.

It supports arbitrary text characters, including spaces. Where supported by the rendering model, individual felt cells may also have foreground and background colors.

Objects are rendered above the felt. If an object moves or is removed, the previously occupied cell must reveal the underlying felt character and its associated appearance.

The felt must not be destroyed or replaced merely because an object temporarily covers it.

### 5.4. Object placement and overlapping

Multiple objects may occupy the same coordinates.

The implementation decides how to represent object collections and determine the rendering order, provided that the chosen semantics are consistent and serializable.

Only the topmost visible object glyph should be rendered at a cell. The underlying objects remain part of the game state and must remain accessible through object-selection and inspection commands.

Where possible, a count marker should appear immediately to the left of a cell containing multiple objects:

- Counts from 1 through 9 may be represented by a digit.
- Counts greater than 9 may be represented by `+`.
- The marker must be omitted if it would collide with another object, cross the board boundary, or otherwise be rendered incorrectly.

This marker is a visual convenience, not a restriction on how objects are stored.

Commands must provide a way to select an individual object when several objects occupy the same cell. Commands explicitly intended to affect all objects at that location may process them together.

### 5.5. Adding and removing objects

The board must support explicit commands for adding and removing objects.

Adding an object should offer a list of matching object Org documents in the active world, using completion or fuzzy selection when available.

If no matching object document exists, the package should offer to create one.

Deleting an object from the board removes its board placement; it must not automatically delete its independent Org document.

If multiple objects occupy the current cell, the deletion command must make the target unambiguous. A separate operation may explicitly remove all objects from the cell.

### 5.6. Rendering updates

The renderer should update only the cells affected by a change whenever practical.

For example, moving an object should update its previous cell and its new cell instead of redrawing the entire board.

The implementation must keep the rendered buffer consistent with the game state while avoiding unnecessary full-board rendering after every action.

## 6. Object Documents and Object Commands

### 6.1. Object identity

Each independent game object is represented by an Org document containing a heading named after the object.

An object may have a visual glyph, foreground and background colors, properties, a description, and executable source blocks.

An object file is created on demand. The package must not create a separate Org file automatically for every character appearing on the board.

A character may correspond to a named Org object even when no object document currently exists. When the user requests to open or define such an object, the package should offer to create its document.

Objects consolidated into a stack may be represented as sections of a combined Org document rather than retaining their former standalone files.

### 6.2. Required properties

Every object must have a properties drawer containing at least the properties required to identify its type and its deck or container membership.

If a deck or membership value has not been assigned, the document must use an explicit default such as `unspecified` rather than relying on an absent field to convey an undocumented meaning.

The exact property names should be documented and consistently used.

Additional standard or custom properties may be defined by the user.

### 6.3. Object commands

The package must provide commands for the following operations:

| Command | Behavior |
|---|---|
| `boardgame-open-object` | Open the Org document associated with the object under the cursor. |
| `boardgame-create-object` | Create a new object document with an initial heading and required properties. |
| `boardgame-add-object` | Select an object and place it on the board. |
| `boardgame-delete-object` | Remove a selected object from the board. |
| `boardgame-find-object` | Find objects by a property or other supported criteria. |
| `boardgame-describe-object` | Show information about objects at the current coordinates. |
| `boardgame-describe-object-extended` | Show the same information and attempt to evaluate the object's description block. |
| `boardgame-query-object-property` | Query a standard or custom property. |
| `boardgame-execute-object-block` | Execute a source block associated with the selected object. |

If an object document is missing, opening it must offer to create it when appropriate.

If a property or optional source block is missing, the command must report that condition clearly rather than raising an unhandled error.

### 6.4. Object inspection

The standard description command must report:

- The name and symbol of every object at the cursor coordinates.
- The name and symbol of a relevant container, if present.
- The underlying felt symbol.

If several objects occupy the cell, each must be represented in the description.

The extended description command must also attempt to execute the object's description block.

If no description block exists, the side log must display a clear message such as `Description not found`. The missing block must not crash the game.

### 6.5. Source-block execution

Objects may contain named executable source blocks.

The user must be able to execute a source block belonging to the object under the cursor. The board itself must also support an executable source block.

Execution commands must clearly identify the relevant object or board. Missing blocks and execution failures must be handled with informative errors rather than leaving the game interface in an inconsistent state.

## 7. Drawing Mode

Drawing is a dedicated feature and must be implemented as a separate minor mode or equivalent clearly scoped mode. It must not be reduced to ordinary object-placement commands.

The goal is to provide convenient character-based board editing at approximately the level of classic ZZT-style drawing, including glyph selection, colors, pipette sampling, continuous painting, and point-by-point editing.

### 7.1. Entering and leaving drawing mode

The user must be able to enable and disable drawing mode explicitly.

Drawing mode operates on the felt layer, not on the object layer.

When drawing mode is enabled, objects must be temporarily hidden as necessary to expose the underlying felt. Hiding objects for drawing must not delete, move, or otherwise alter them.

When drawing mode is disabled, objects must be rendered again over the edited felt.

Drawing must not inadvertently modify object positions or object documents.

### 7.2. Evil-mode compatibility

Drawing mode must work without requiring Evil to be installed.

If Evil is available:

- Normal-state cursor movement must continue to behave as normal navigation.
- Drawing must not globally replace or disable ordinary Evil normal-mode movement.
- In insert state, movement may paint along the path when drawing mode is enabled.
- Normal-state movement should remain navigation unless the user explicitly invokes a drawing operation bound for that state.
- Leaving drawing mode must restore the ordinary movement behavior expected by the user's configuration.

The implementation must not force the user into insert state or another Evil state merely because drawing mode is enabled.

Where Evil is absent, the package must provide usable Emacs-native commands and bindings for drawing.

### 7.3. Selecting the drawing character

The user must be able to select a character used for painting the felt.

The selected character may be any supported character, including spaces.

The drawing interface must provide a convenient way to select a symbol from a list of recently used symbols.

The recent-symbol list must be ordered by recency, with the most recently used symbols appearing first, except that the currently active symbol should not be redundantly presented as another recent choice.

Selecting a symbol must update the active drawing character without changing existing board cells.

### 7.4. Foreground and background colors

The user must be able to select the foreground and background colors used when painting.

Color selection must be independent of character selection: the user may change a color without changing the active glyph.

The drawing interface must expose the currently selected character and colors through its status display or another suitable visual indicator.

Color changes must apply to subsequent painting operations and must not recolor unrelated cells unless the user explicitly requests a bulk operation.

The available color representation and rendering mechanism may be chosen by the implementation, provided that saved board data can preserve the supported appearance.

### 7.5. Continuous and point-by-point painting

Drawing mode must support both:

- **Continuous painting:** moving through cells in the applicable drawing interaction paints the traversed cells with the selected character and colors.
- **Point-by-point painting:** the user explicitly paints individual cells without requiring a continuous stroke.

When continuous painting is active, the drawing behavior must respect the user's editing state and must not interfere with ordinary navigation when drawing is inactive.

Painting replaces the existing felt character at the targeted cell. It does not create a game object.

Painting with a space must be supported so the user can erase characters from the felt.

### 7.6. Pipette

The drawing mode must provide a pipette operation that samples the felt at a selected cell.

The pipette must retrieve the existing felt character and, where available, its foreground and background colors.

The sampled values become the active drawing settings. Sampling must not modify the sampled cell.

If an object is covering the cell, the pipette must sample the underlying felt rather than the object's visible glyph.

### 7.7. Drawing over selected regions

The user must be able to select a region of the board and apply a drawing operation to the selected cells.

Supported region operations should include replacing felt characters and applying the active drawing character and colors.

Where the selection contains objects, drawing operations must affect the felt layer only. They must not delete or move objects.

The implementation should support the user's ordinary Emacs or Evil selection workflow where practical. Evil visual selection must continue to behave normally; the package must not globally replace its semantics.

Commands that operate on a selection must clearly distinguish between applying a change to every felt cell in a region and applying an object operation to objects located in that region.

### 7.8. Drawing and the board renderer

Drawing changes must be reflected promptly in the board buffer.

When drawing on a cell, the renderer should update that cell rather than unnecessarily rebuilding the entire board.

Disabling drawing mode must restore object visibility without losing the changes made to the felt.

The current drawing character, colors, and mode status should be visible in the optional status area or another configurable indicator.

## 8. Hands and Cards

Hands are independent Org files. The order of cards or objects in a hand is determined by the order of their headings.

The package must support any number of hands, but only one active hand at a time.

A hand may belong to a player, an opponent, or another game participant. The exact ownership model may be configurable.

### 8.1. Hand visibility

A hand may operate in a visible or blind mode.

In blind mode, operations must be possible without displaying or revealing the hand's contents. This is necessary for opponent hands and hidden information.

Commands must distinguish between operations that manipulate a hand and operations that reveal its contents.

The UI must not expose hidden card names or contents through an incidental display, list, or log message when a blind operation is requested.

### 8.2. Hand display and selection

The user must be able to inspect or select cards from the active hand when the hand is visible.

The implementation may use a separate window, a bottom panel, the existing information pane, or another suitable interface. The exact layout is not fixed.

The interface should show useful contextual information about the active hand and its selected card where appropriate.

Switching the active hand must not silently change the contents or ordering of other hands.

### 8.3. Hand commands

The package must provide distinct commands for:

- Opening or creating a hand Org file.
- Switching the active hand.
- Adding an object or card to a hand.
- Selecting a card from a visible hand.
- Playing the first card.
- Playing the last card.
- Playing a selected card.
- Playing a random card.
- Executing a source block from a card in the active hand.
- Executing a source block from the first card by default.
- Executing a source block from a card specified by an explicit index.
- Performing supported operations on a blind hand without revealing its contents.

When an operation selects a card by index, the indexing convention must be documented and applied consistently.

### 8.4. Playing a card onto the board

A card may be played at the current board cursor position or another explicitly selected position.

If the destination cell is occupied by a permanent container, the card must be added to that container rather than placed visibly on the board.

This rule applies to hand-to-board placement. It must not be confused with stack creation, which is an explicit document-consolidation operation.

The implementation must define and document whether playing a card consumes it from the hand or copies it, according to the operation and game rules. It must not silently duplicate or discard a card when the behavior is ambiguous.

## 9. Stacks and Permanent Containers

Stacks and containers serve different purposes and must remain separate concepts.

### 9.1. Stacks: explicit document consolidation

A stack is created by an explicit command. It must not be created automatically merely because objects occupy the same cell.

The stack-creation command must accept a list of object coordinates, defaulting to the object or objects under the current cursor when no explicit list is supplied.

The operation must:

1. Identify the selected objects and their Org content.
2. Consolidate that content into one combined Org document.
3. Remove the former independent object files after their content has been successfully consolidated.
4. Remove the selected independent objects from the board.
5. Represent the consolidated result as a single stack object at the designated stack location.

The combined document must preserve the information needed to represent the consolidated objects and their relevant properties and content.

Stack creation is fundamentally an Org-document transformation and a change in object representation. It is not merely a visual grouping.

The implementation must avoid leaving the game in a state where the original documents have been deleted but the consolidated document was not successfully written.

The lifecycle of a stack when individual members are later extracted, including whether a one-member stack dissolves automatically, must be explicitly documented by the implementation. It must not be confused with automatic stack creation.

### 9.2. Permanent containers: organization without consolidation

A permanent container is a persistent object represented by its own Org file.

A container organizes references to objects. It must not merge the Org documents of those objects or delete their independent files merely because they enter the container.

Placing an object on top of a permanent container must remove that object's visible placement from the board and add a reference to it in the container's contents.

The object's independent Org file remains intact.

A container may contain individual objects, stacks, or other containers. Nested containers must be supported.

An empty permanent container remains on the board unless the user explicitly deletes it.

Containers must be capable of holding ordered contents, and their contents must remain associated with the correct object documents.

### 9.3. Container-specific source blocks

A container may define executable source blocks for deck or container operations, such as drawing or shuffling.

The package must support executing a relevant container block through an explicit command or another documented interaction.

Missing optional container blocks must be handled gracefully.

### 9.4. Container commands

The package must provide separate operations for:

- Creating a permanent container.
- Opening or inspecting a container.
- Adding an object to a container.
- Adding a card from the active hand to a container.
- Drawing an object from a container to the active hand.
- Drawing from the top.
- Drawing from the bottom.
- Drawing a random item.
- Opening or revealing a card beside or above its deck.
- Shuffling a deck or container.
- Listing contents in random order unless another order is requested.
- Laying out all contents on the board.
- Executing a container's supported source blocks.
- Refreshing object properties from their Org documents when the displayed or cached properties are stale.
- Explicitly deleting a container.

The package must distinguish container deletion from deleting the objects referenced by that container. Deleting a container must not silently delete its contents' independent files.

### 9.5. Revealing and listing contents

A command to reveal or list container contents must support a randomized order by default when no other order is requested.

Where an operation supports a specified order, such as top-to-bottom or bottom-to-top, that order must be respected.

For blind or hidden containers, revealing contents must be an explicit action rather than an accidental side effect of another operation.

### 9.6. Laying out contents

The user must be able to lay out all items from a container onto the board.

Each item must occupy a previously free cell around the source container. The operation must not overwrite unrelated objects or silently place items on occupied cells.

The implementation may choose a placement strategy, but it must handle insufficient free space with a clear message and a consistent result. It must not silently lose items that could not be placed.

### 9.7. Containers holding stacks

A permanent container may hold a stack as one item. The stack remains a consolidated document, while the container stores its reference.

Adding a stack to a container must not automatically unpack or reconsolidate it.

Container organization and stack consolidation are independent operations.

## 10. Teleportation and Navigation

The package must support teleporting to specified board coordinates.

Teleportation must also be possible through markers placed on the board. Markers may be predefined in the board data or placed by the player through an appropriate command.

The package must provide commands to:

- Teleport to explicit coordinates.
- Navigate to a selected teleport marker.
- Create or place a teleport marker where supported.
- Remove or edit a player-created marker where supported.

Teleportation must not alter the felt or remove objects from the destination cell. The behavior when the destination contains multiple objects must remain consistent with ordinary object selection.

Invalid coordinates or missing markers must produce a clear message without leaving the cursor in an undefined state.

## 11. Side Log and Status Area

### 11.1. Side-log content

The side log displays only messages explicitly sent through the game's logging interface.

Ordinary Emacs messages, warnings, and internal diagnostics must not be copied into the game log automatically.

The log may display object descriptions, command results, game events, selected properties, and other explicit gameplay messages.

It should support text, foreground/background color information, and relative-path image references where the implementation supports them.

### 11.2. Scrolling

When a new message is sent, the log should scroll to show the newest message.

The user must remain able to scroll manually using ordinary Emacs commands. Adding new messages must not disable manual navigation through older entries.

The board's scrolling must remain independent of the log's scrolling.

### 11.3. Persistence

The default may be a temporary, unsaved log buffer.

Persistent logging may be provided as an option, using a separate Org file associated with the board. When enabled, the file should be loaded alongside the board and created if absent.

The choice between temporary and persistent logging remains a configurable design decision until finalized. The implementation must not silently imply that a temporary log is permanently saved.

### 11.4. Status area

The optional status area should display stable contextual information, such as:

- Active world and board.
- Active hand.
- Current object or selected object properties.
- Relevant global variables or tokens.
- Drawing mode status.
- Active drawing character and colors.

The status area must remain distinct from the side log's stream of gameplay messages.

## 12. Keyboard Bindings and Command Access

All principal operations must be available through documented interactive commands, even when no optional menu package is installed.

### 12.1. Function keys and key sequences

The game keymap may use F1 through F12 for game commands.

The package must support sequential key chords of up to three key presses. For example, pressing `F5` followed by `F1` is a two-key sequence.

These are sequential key sequences, not simultaneous physical key combinations.

The key bindings must be configurable and documented. The implementation should avoid unnecessary conflicts with the user's existing keymaps and provide an appropriate way to customize or disable game-specific bindings.

### 12.2. Evil compatibility

The package must not globally override standard Evil normal-mode cursor movement.

Normal state remains useful for navigation, inspecting objects, and invoking commands. Insert state may be used for continuous drawing when drawing mode is enabled.

The package must not require Evil and must remain usable with ordinary Emacs keymaps.

### 12.3. Optional menus

If Hydra is installed, it may be used to provide convenient grouped menus for board operations, object operations, drawing, hands, containers, and navigation.

Hydra must remain optional. Its absence must not disable commands or make any essential feature inaccessible.

## 13. Error Handling and Consistency

All commands must handle common failure conditions gracefully.

Examples include:

- A requested world, board, object, or hand file does not exist.
- An Org document is malformed or unreadable.
- A requested property or source block is missing.
- A drawing operation targets an invalid coordinate.
- A container has no items to draw.
- A layout operation has insufficient free cells.
- A requested card index is invalid.
- A save operation fails.
- A destructive operation would affect more objects than intended.

Errors must be communicated clearly through an appropriate Emacs message or game-log entry.

The package must not silently lose objects, delete independent object files during ordinary container operations, or overwrite unrelated documents.

Stack consolidation must not remove the original documents until the consolidated representation has been successfully created.

Git commits should be made after successful saves when version-control integration is enabled. Git history is a recovery mechanism, not a substitute for correct handling of failed writes.

## 14. Proposed Public Command Reference

The following list summarizes the command families that must be documented. It is not a restriction on additional commands.

| Command family | Required operations |
|---|---|
| Game | Start, close, switch world |
| World | Open, create, activate, switch |
| Board | Open, create, save, save as, close, refresh |
| Objects | Add, create, open, delete from board, find, describe, query properties, execute source blocks |
| Drawing | Enable/disable, select glyph, select foreground/background colors, pipette, continuous paint, point paint, paint a selected region, select a recent glyph |
| Hands | Open/create, switch active hand, add card, play first/last/selected/random card, execute a card's source block, perform blind operations |
| Containers | Create, open, add, draw top/bottom/random, reveal, list, shuffle, lay out contents, execute container blocks, delete |
| Stacks | Explicitly consolidate selected objects and manage the resulting stack |
| Navigation | Teleport to coordinates, use teleport markers, create or edit markers |
| Logging | Send explicit messages, optionally manage persistent logs |

The final package documentation must list the actual command names and their key bindings. The names in this document are proposed canonical names and may be refined consistently during implementation.

## 15. Implementation Freedom and Acceptance Criteria

This document specifies required user-visible behavior, not a mandatory internal architecture.

The implementation may choose its own in-memory data structures, rendering strategy, ordering representation, command-dispatch mechanism, and window-management helpers.

However, it must satisfy these acceptance criteria:

1. Starting the game opens a dedicated frame with a board and side log.
2. The user can create or open a world and create, open, save, and close boards.
3. Missing resources trigger an appropriate creation workflow instead of an unexplained failure.
4. Board state can be serialized to and reconstructed from editable Org documents.
5. Felt characters remain intact beneath objects and are restored when objects move or are removed.
6. Multiple objects may occupy a cell, and individual objects remain accessible.
7. Drawing mode supports character selection, colors, pipette sampling, continuous and point-by-point painting, and region operations without modifying the object layer.
8. Hands support ordered cards, active-hand switching, selected and random card operations, and blind actions.
9. Permanent containers organize references without merging or deleting independent object files.
10. Stack creation is explicit and consolidates selected object documents into one representation.
11. Teleportation, object inspection, property queries, and source-block execution are available through documented commands.
12. Game logging is separate from ordinary Emacs messages.
13. Evil remains optional, normal-mode movement is not globally overridden, and Hydra remains optional.
14. Missing data, invalid operations, and failed saves are handled without silently losing game content.
15. The implementation is covered by module-level unit tests and integration tests for complete gameplay workflows.

The central principle is to keep the user-visible rules explicit while allowing the developer to choose a simple, readable, and efficient implementation.
