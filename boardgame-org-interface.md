# User Interface, Commands, and File Lifecycle
## 1. Game Mode and Frame Layout
Starting the game interface must open a **dedicated Emacs frame** for the game session. The game must not replace or repurpose the user's existing editing frame.
The game frame must be divided into the following areas:
- **Board area (~80% of the frame width):** displays the active board as a character-based text buffer.
- **Side log (~20% of the frame width):** displays gameplay messages explicitly sent to the game log. Text must wrap naturally.
- **Optional status area:** the side-log region may be split horizontally, reserving approximately its upper 20% for persistent game information, such as global variables, tokens, active properties, and drawing-mode settings. The remaining area displays the log.

The proportions must be configurable.

The board must be displayed in a dedicated game buffer rather than as a normal Org document. Its associated Org file is the persistent representation used to load and save the board.

The game interface must support multiple board buffers, but only one active world at a time. Opening another board must not silently replace or discard the current board's unsaved state.

The game must use ordinary Emacs buffers and windows. Board navigation and scrolling must remain compatible with normal Emacs behavior. The game must not globally override Evil-mode navigation or require Evil to be installed.

The frame should be initialized with a usable board and log layout. If no world or board has been selected, the package must guide the user through creating or opening one.

## 2. Public Commands
The package must expose documented interactive commands for its principal operations. The following names are proposed canonical command names; implementations may use additional internal helpers.
### 2.1. Game and World Commands

| Command | Purpose |
|---|---|
| `boardgame-start` | Open the dedicated game frame and initialize the game interface. |
| `boardgame-open-world` | Select and activate an existing world directory, or create a new world. |
| `boardgame-create-world` | Prompt for a world name and create its directory and initial structure. |
| `boardgame-switch-world` | Switch to another world, handling unsaved changes according to the configured save policy. |
| `boardgame-close-game` | Close the game session without silently discarding unsaved changes. |

A world is a directory containing its boards, object Org files, hands, containers, and other world-specific data.

Only one world may be active at a time. All world-relative file references must resolve within the active world unless an explicitly supported external reference is used.

### 2.2. Board Commands

| Command | Purpose |
|---|---|
| `boardgame-open-board` | Open an existing board Org file or offer to create a new board. |
| `boardgame-create-board` | Prompt for a board name and create a new board in the active world. |
| `boardgame-save-board` | Serialize the current in-memory board state to its associated Org file. |
| `boardgame-save-board-as` | Save the current board under a new file name selected by the user. |
| `boardgame-close-board` | Close a board buffer after resolving any unsaved changes. |
| `boardgame-add-object` | Add an existing or newly created object to the board. |
| `boardgame-delete-object` | Remove the selected object from the board. |
| `boardgame-find-object` | Find an object by a property or other supported criteria. |
| `boardgame-execute-board-block` | Execute a source block associated with the board. |
| `boardgame-refresh-board` | Reconcile the displayed board with the current in-memory state and supported external changes. |

Removing an object from a board must not automatically delete its Org file. Object deletion from the board and deletion of an object's persistent definition are separate operations.

If multiple objects occupy the cursor's coordinates, commands that act on a single object must provide a way to select the intended object. Commands explicitly designed to act on all objects at those coordinates may process the entire stack.

### 2.3. Object Commands

| Command | Purpose |
|---|---|
| `boardgame-open-object` | Open the Org file associated with the object under the cursor. |
| `boardgame-create-object` | Create a new object Org file and its initial heading and properties. |
| `boardgame-describe-object` | Display the names and symbols of objects at the cursor, including relevant container and felt information. |
| `boardgame-describe-object-extended` | Display the same information and attempt to execute the object's description block. |
| `boardgame-query-object-property` | Query a standard or custom property of an object. |
| `boardgame-execute-object-block` | Execute a source block belonging to the selected object. |
| `boardgame-add-object-to-board` | Select an object from the active world's available Org objects and place it on the board. |
| `boardgame-create-stack` | Explicitly consolidate selected objects into a stack represented by a combined Org document. |
| `boardgame-create-container` | Create a persistent container object. |
| `boardgame-open-container` | Open or inspect a container and its contents. |
| `boardgame-delete-container` | Delete a container through an explicit operation, with appropriate handling of its contents and references. |

Missing descriptions, properties, or optional source blocks must produce a clear message rather than an unhandled error.

Stack creation and container operations must remain distinct. Creating a stack consolidates object documents; using a permanent container reorganizes references to objects without merging or deleting their independent Org files.

### 2.4. Hands, Drawing, and Navigation Commands

The package must also provide documented commands for:

- Switching the active hand.
- Playing a selected, first, last, or random card from a hand.
- Executing a source block from a card in the active hand.
- Drawing, opening, shuffling, and laying out container contents.
- Entering and leaving drawing mode.
- Selecting a drawing symbol and foreground/background colors.
- Sampling a character and its colors with the pipette.
- Choosing a recently used symbol.
- Teleporting to a specified coordinate or a teleport marker.
- Sending an explicit message to the side log.

These commands must be usable through `M-x`, with key bindings available in the game keymap. Key bindings must not interfere with standard Evil normal-mode movement. Hydra may optionally provide menus when installed, but must not be a required dependency.

## 3. File Selection and Creation Workflow
Commands that require a world directory, board Org file, object Org file, hand file, or other persistent game document must provide a clear file-selection workflow.
### 3.1. Opening an Existing File

When a command requires an existing file, it must offer an appropriate selection interface. This may be `read-file-name`, a completion interface, or a fuzzy finder when available.

For example, invoking `boardgame-open-board` should allow the user to select a board Org file belonging to the active world.

The implementation should prefer files in the active world and should not require the user to manually enter full absolute paths for ordinary operations.

### 3.2. Creating a Missing File

If the requested file does not exist, the package must offer to create it where creation is valid.

Examples:

- Opening a board must allow the user to select an existing board or create a new one by entering its name.
- Opening an object must allow the user to create the corresponding object Org file if it is missing.
- Opening or activating a world must allow the user to create the requested world directory if it does not exist.
- Creating a hand or other persistent game document must prompt for its name and create it in the appropriate location.

The user must not be required to run a separate creation command before every open operation. Where appropriate, opening and creating should be integrated into a single workflow.

The package must distinguish between a missing resource that can validly be created and an invalid path, inaccessible directory, malformed file, or other genuine error. It must not silently create arbitrary files in unintended locations.

### 3.3. File Naming and Locations

Names supplied by the user must be converted into valid file paths within the active world's directory structure.

The implementation must:

- Use consistent, documented extensions and naming conventions.
- Avoid silently overwriting existing files.
- Prompt before overwriting or replacing existing data.
- Create required parent directories when appropriate.
- Keep references between boards, objects, hands, and containers consistent when files are created or renamed.
- Use world-relative paths for world-internal references wherever practical.

The exact directory layout should be configurable or clearly documented, but the default layout must be predictable.

## 4. World and Board Creation Semantics

**A requested world or board that does not physically exist is a potential creation request, not automatically an error.**

If a user specifies a world name and that world directory is absent, the package should offer to create the directory and initialize its required structure.

If a user specifies a board name and its Org file is absent, the package should offer to create the board file with the required metadata and an initial felt section.

A newly created board must have valid dimensions and an initialized felt map. Missing cells must use the configured default felt character, which defaults to `.`.

Creation must be explicit enough to prevent accidental data loss, but straightforward enough that users can create a world or board directly from the relevant open command.

The package must not treat every missing path as permission to create a file silently. It should ask for confirmation when the requested operation is ambiguous or could create an unintended resource.

## 5. Board Loading and Saving

The board Org file is the persistent serialization format, not necessarily the live game model.

- **Loading:** the selected Org file is the source of truth for reconstructing the board's initial in-memory state.
- **Saving:** the current in-memory state is the source of truth for serializing the board back into Org format.

Saving must preserve the board's dimensions, felt contents, object placements, relevant object ordering or layering semantics, and other state necessary to reconstruct an equivalent board.

The user must be able to edit the serialized Org document manually. Loading and saving must preserve the documented game semantics rather than depending on hidden, non-serialized state.

The package should track whether a board has unsaved changes and prompt before discarding them when closing, switching, or replacing its state.

After a successful board save, the package should commit the world state to Git when version-control integration is enabled and configured. Git history provides recovery and rollback capabilities, but does not replace correct file-writing and error-handling behavior.

## 6. Side Log Behavior
The side log must display only messages explicitly sent through the game's logging API. Ordinary Emacs messages, warnings, and internal diagnostics must not be copied into the game log automatically.

New gameplay messages should appear at the bottom, and the log should follow the newest message when a new message is added. Users must still be able to scroll manually with standard Emacs commands.

The default implementation may use a temporary, unsaved log buffer. Persistent per-board logs may be offered as an optional feature, stored in a separate Org file associated with the board. The persistence policy must be configurable and documented.

## 7. User-Facing Documentation

The package documentation must include:

- Installation and dependency requirements.
- How to start the game and what frame layout to expect.
- How to create, open, save, and close worlds and boards.
- The complete list of interactive commands and their purpose.
- How objects are added, removed, inspected, and edited.
- How hands, stacks, containers, and drawing mode work.
- Default key bindings and how to customize them.
- File naming conventions and the world's directory structure.
- How missing worlds, boards, and objects are created.
- How Git history and recovery work.
- Known limitations and any behavior that remains configurable or implementation-dependent.

A user should be able to understand and operate the game through documented interactive commands without reading the implementation source code.
