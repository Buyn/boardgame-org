# `boardgame.org` — Architecture Clarifications and Implementation Principles

**Status:** Normative architectural decisions  
**Language:** English  
**Implementation language:** Emacs Lisp  
**Primary dependency:** Org-mode  
**Optional integration:** Hydra  
**Project philosophy:** File-oriented state management, Org-mode serialization, explicit context transformations, modular implementation, and recoverable world history.

## 1. Architectural Boundaries
The specification distinguishes three categories of requirements:

- **Requirements:** Observable behavior and invariants that every conforming implementation must preserve.
- **Implementation guidance:** Recommended engineering practices that may be adapted when a different implementation is demonstrably more suitable.
- **Implementation freedom:** Internal mechanisms deliberately left unspecified so that the developer can choose an efficient solution.

The specification must not turn implementation freedom into an arbitrary restriction. In particular, it must not prescribe internal data structures, object traversal order, rendering algorithms, or synchronization mechanisms unless those choices are necessary to preserve the required behavior.

The central purpose of `boardgame.org` is to provide a text-based tabletop environment in Emacs, with Org-mode documents serving as editable, human-readable representations of game objects and serialized board state.

The project is not intended to be a conventional database-backed game engine.

## 2. Org Files as Object Identity and Persistent Representation
### 2.1. An Object Is a File

An independently existing game object is represented by an Org file.

An object may represent a card, a die, a token, a container, a deck, or another entity supported by the engine.

An object file contains the object's name, properties, visual representation, and any supported behavior or descriptive source blocks.

The object file is not merely an export or a disposable cache. It is the persistent representation of that independently existing object.

The following invariant applies:

> An independently existing object has its own Org file. When that object ceases to exist as an independent object because it has been incorporated into another representation, its former standalone file must be removed.

Creating an object produces an Org file when the object is materialized. Moving an object between locations changes its placement and organizational relationships. Incorporating an object into a stack changes its representation and removes its former standalone file.

This distinction is fundamental to the project's file-oriented architecture.

### 2.2. Object Creation and Removal

When a new object is created, the system generates an Org document containing at least the required heading and property structure.

The object should be created only when requested by an operation that requires its existence. Merely encountering a symbol or an unresolved reference should not silently create arbitrary objects without the appropriate user interaction or explicit operation.

When an object is removed from the game, its file must be handled consistently with the operation that removed it.

For example:

- Deleting an independent object removes that object and its persistent representation.
- Incorporating an object into a stack removes its former standalone representation because the object's content is transferred into the stack document.
- Moving an object into a permanent container does not remove its standalone file merely because it is no longer on the board.

These operations must not be confused with one another.

### 2.3. Org Documents as Contexts

The project treats Org documents as manageable contexts.

A context may contain one object, many objects, or an organized collection of references to other objects, depending on the context type.

The important architectural operation is the deliberate transformation of these contexts:

- Creating a standalone object produces a new Org document.
- Combining objects into a stack consolidates their Org content into one document.
- Adding an object to a permanent container changes the container's organization while preserving the independent object document.
- Moving an object between the board, a hand, and a container changes its location without automatically changing its identity or document structure.

The implementation should make these distinctions explicit in the command and data-model architecture.

## 3. Stacks and Containers Are Fundamentally Different
Stacks and containers may look similar on the board, but they have different persistence semantics. They must be modeled as distinct concepts rather than two visual variations of the same generic operation.
### 3.1. Stack: Consolidation of Org Documents

A stack is a consolidated Org document containing the content of multiple objects.

Its primary purpose is to transform the representation of objects by merging their previously independent Org documents into a single document.

When several objects are explicitly combined into a stack:

1. The operation identifies the objects selected for consolidation.
2. Their relevant Org content is incorporated into a new or designated stack document.
3. The stack document preserves the information required to represent the combined objects and their internal order.
4. The original objects cease to exist as independent objects.
5. Their former standalone Org files are removed.
6. The resulting stack is represented as one object at its current location.

The operation is explicit. Two objects occupying the same board coordinate do not automatically become a stack.

A stack may subsequently be moved as one object, including into a permanent container.

**The defining property of a stack is consolidation of object documents, not merely grouping objects spatially.**

If a stack is later expanded into independent objects, the implementation must reconstruct the standalone documents and remove the consolidated representation when appropriate. The precise expansion workflow and identity-generation rules may be specified separately.

The specification must not require automatic dissolution whenever a stack contains only one remaining entry unless that behavior is explicitly adopted as a separate rule.

### 3.2. Permanent Container: Organization Without Consolidation

A permanent container is a persistent Org document that organizes independently existing objects.

Its defining property is that it changes the arrangement and location of objects without merging their standalone Org documents.

When an object is placed into a permanent container:

1. The object is removed from its former board position or hand, as applicable.
2. Its standalone Org file remains intact.
3. The container records the object's membership and position in its internal ordering.
4. The container itself remains a persistent object, even when empty, unless an explicit deletion command removes it.

The container is therefore an organizer of objects, not a transformer of their underlying Org documents.

A permanent container may contain independent objects, stacks, or other containers. Nesting is possible because each of these entities can be represented as an object in its own right.

A container may also define custom behavior through its properties or source blocks, such as drawing, shuffling, selecting, or revealing contents.

These behaviors operate on the container's organization and its members. They must not implicitly merge the members' documents.

### 3.3. Comparison

| Property | Stack | Permanent container |
|---|---|---|
| Primary purpose | Consolidate object documents | Organize independent objects |
| Object Org files | Incorporated into the stack document; standalone files removed | Preserved independently |
| Membership representation | Object content consolidated into one document | Membership and order represented by the container |
| Board representation | One object | One object |
| Can contain other stacks? | Subject to the stack's content model | Yes |
| Can contain other containers? | Subject to the stack's content model | Yes |
| Empty state | Governed by stack operations | Container persists until explicitly deleted |
| Automatic creation from overlap | No | No |
| Explicit user operation | Required | Required for creation and relevant transformations |

### 3.4. Implementation Consequences

The implementation must not use the same persistence operation for both concepts merely because both can display multiple items at one coordinate.

The operations should have distinct names, responsibilities, and tests.

Tests must verify not only what appears on the board but also which Org files exist afterward and what their contents represent.

## 4. Source of Truth and Serialization
### 4.1. The In-Memory Model

The running game has an internal representation of its current state.

The implementation may use suitable Emacs Lisp data structures, such as structs, hash tables, lists, vectors, or combinations of them.

The specification deliberately does not prescribe one particular representation.

The in-memory model must be capable of supporting the required behavior: object lookup, board coordinates, layering, hands, containers, object properties, rendering, and serialization.

It must not be confused with the Org file used to persist a board.

### 4.2. Loading

When a board is loaded, its Org document is the source of truth for the board state being reconstructed.

The loader interprets the document and creates the corresponding in-memory representation.

The resulting state must preserve the information required by the specification, including:

- Board dimensions and felt contents.
- Object locations and references.
- Object display information stored in the board representation.
- The relationships and ordering explicitly represented by the document.
- Hand references and other supported board-level state.

Object-specific properties and behavior may be obtained from the corresponding object documents, according to the data model.

The implementation may cache parsed data or use other optimizations, provided they do not undermine the defined loading and saving semantics.

### 4.3. Saving
When a board is saved, the current in-memory model is the source of truth for the state being serialized.
The serializer writes that model into the board's Org document.
It must not blindly overwrite the current board with stale values from the document originally loaded.
The saved representation must be sufficient to reconstruct the intended state on a subsequent load.
The serializer and loader should be designed as complementary operations. Their behavior should be verified with round-trip tests.
For a state that contains only supported, serializable data, the following conceptual relationship should hold:
`deserialize(serialize(state))` reconstructs an equivalent state.
Equivalence concerns the defined game semantics, not necessarily the identity of internal Lisp objects or the exact arrangement of data structures in memory.

### 4.4. Human-Editable Persistence

A primary design goal is that users can edit saved Org documents directly and load the edited documents back into the game.

Consequently, the persistence format is part of the user-facing architecture, not an opaque implementation detail.

The document structure should be understandable, consistent, and sufficiently explicit to permit manual editing.

The implementation should validate the data it reads and report malformed or missing information clearly. Optional properties may have defaults where the specification defines them.

The loader must not assume that every document was generated exclusively by the current running session.

### 4.5. Board File Structure
A board Org document contains named sections for the board's persistent components.

The felt section contains a source block representing the background grid. Board properties specify the intended dimensions.

Object entries describe objects placed on the board, including their coordinates, references to object files, and relevant display information.

Hand sections describe hands associated with the board or world and identify their corresponding hand documents.

The exact internal representation of the loaded model remains an implementation decision. The serialized format, however, must preserve the defined semantics.

### 4.6. Felt Dimensions and Normalization

The felt source block may contain fewer or more characters than the dimensions declared by the board.

When loading:

- Missing cells are filled with the designated default felt symbol.
- Content outside the declared dimensions is ignored.
- The resulting board conforms to its declared dimensions.

When saving, the serialized felt should represent the intended board dimensions consistently.

The implementation should define how line endings and character positions are handled. Since Emacs buffers operate on characters rather than display columns, rendering must account for the display width of the supported glyphs. If the board format is intended to use one display column per cell, its supported cell characters must respect that constraint or be normalized appropriately.

## 5. Object Ordering and Rendering
The specification defines the visual and behavioral results of rendering, not the internal data structure used to achieve them.

Multiple objects may occupy the same board coordinate.

The felt layer is underneath all objects. When objects occupy a coordinate, the felt character is not displayed as the foreground content of that cell.

The implementation must render the objects according to a consistent layering rule and provide a way to indicate that a cell contains multiple objects.

The original design calls for rendering one visible object glyph and a count indicator immediately to its left when possible:

- A count from 1 to 9 may be represented by its corresponding digit.
- A larger count is represented by `+`.
- The indicator is omitted if it cannot be rendered without colliding with another object or exceeding the board boundary.

The implementation must not fail merely because the indicator cannot be displayed.

The exact ordering of objects in memory, the choice of traversal algorithm, and the data structure used to determine which object appears on top are implementation decisions.

The serialized board must nevertheless preserve enough information to reconstruct the intended object arrangement. In particular, if document order defines layering, the loader and serializer must preserve that ordering.

If a different representation is chosen, it must preserve equivalent behavior and remain compatible with manual editing of the Org document.

## 6. Persistence Reliability and Version Control
### 6.1. Recovery Strategy

The initial implementation should not introduce an elaborate transaction manager, locking framework, or bespoke rollback subsystem without a demonstrated requirement.

The project is deliberately file-oriented. Its persistent state consists of readable text documents, making version control a natural mechanism for retaining historical states.

The intended strategy is to use a version-controlled world directory and create a commit after successful persistence operations.

This provides a history of changes and a practical way to inspect, revert, or recover from unwanted modifications.

### 6.2. World Repository

A world is a directory containing its board documents, object documents, hand documents, containers, and other world-specific Org files.

The world directory should be suitable for management by a version-control system such as Git.

The implementation should avoid introducing unnecessary external databases or opaque storage formats.

Repository initialization and configuration may be performed by the user or supported by dedicated setup commands.

### 6.3. Saving and Committing

The intended workflow is:

1. Serialize the current model to the relevant Org documents.
2. Complete the requested file writes.
3. If persistence succeeds, create a version-control commit representing the resulting world state.
4. If persistence fails, report the failure and do not report the operation as successfully saved and committed.

The exact Git integration, commit message format, handling of unchanged files, and user configuration should be documented separately.

The implementation should not assume that a successful Git commit makes an operation transactional or eliminates every possibility of partial file modification.

Version control is the chosen recovery mechanism; it is not a substitute for correct file handling.

### 6.4. Recovery and Inspection

Users should be able to inspect the history of a world, identify the changes introduced by an operation, and restore an earlier state through ordinary version-control tools.

The package may provide convenience commands for common operations, but it should not unnecessarily hide or replace Git's native capabilities.

The initial design should prioritize transparent persistence and practical recovery over a complex custom transaction architecture.

## 7. Implementation Quality Requirements
The implementation should follow these engineering principles:
- **DRY:** Shared behavior belongs in reusable functions rather than duplicated code.
- **Single responsibility:** Functions should have clear, narrowly defined responsibilities.
- **Readable code:** Prefer explicit names and straightforward control flow over clever abstractions.
- **Modularity:** Divide the package into multiple Emacs Lisp files according to functional responsibility.
- **Testability:** Design core logic so that it can be tested without requiring a complete interactive game session whenever possible.
- **Configurable behavior:** Use user options and documented defaults for behavior that may reasonably vary.
- **Graceful handling of optional information:** Missing optional properties should not cause failures.
- **Explicit transformations:** Operations that consolidate documents or change object ownership must be distinct from ordinary movement and organization.
- **Human-readable persistence:** Keep the Org representation understandable and editable.
- **Native Emacs integration:** Prefer existing Emacs and Org-mode facilities when they satisfy the requirements.

As a project guideline, functions should generally remain below 50 lines of code. When a function becomes longer, the developer should consider extracting logically independent steps into well-named helpers.

This is a readability guideline, not a reason to split coherent logic into artificial fragments.

The package should be divided into files based on responsibility, such as board data, serialization, objects, hands, containers, rendering, drawing, logging, commands, and tests. The final module boundaries may evolve as the implementation becomes clearer.

## 8. Testing Requirements
The project should use both unit tests and integration tests.

Unit tests should cover individual modules and their defined responsibilities.

Integration tests should verify interactions between modules and the consistency of complete workflows.

Particularly important tests include:

- Loading and saving a board.
- Round-trip serialization of board state.
- Normalization of felt dimensions.
- Rendering and movement of objects.
- Multiple objects occupying one coordinate.
- Creating and removing standalone object files.
- Consolidating objects into a stack and removing the former standalone files.
- Placing objects in a permanent container without merging their documents.
- Moving objects between a board, a hand, and a container.
- Preserving object ordering where ordering affects behavior.
- Reporting malformed documents and missing optional information.
- Saving a world and recording its resulting state in version control.

Tests must verify persistent file effects as well as the visible game state. A test that confirms an object appears correctly on the board is insufficient if the operation also requires creating, retaining, consolidating, or removing particular Org files.

## 9. Deliberately Unspecified Implementation Details
The following decisions remain open unless later requirements make them necessary:

- The concrete in-memory representation of the board and game objects.
- The exact algorithms used to render or update board cells.
- The internal traversal order of objects, provided defined ordering semantics are preserved.
- The specific Emacs Lisp data structures used for stacks, hands, and containers.
- The implementation of incremental rendering.
- The mechanism used to coordinate internal operations during a single Emacs session.
- The precise organization of internal helper functions and module files.

The developer is expected to choose efficient, maintainable solutions and document significant decisions where they affect future development.

These freedoms do not permit changing the externally defined semantics of stacks, containers, serialization, or object persistence.

## 10. Governing Principle
`boardgame.org` should treat Org-mode documents as first-class, human-editable representations of game objects and persisted board state.

The system may maintain any suitable internal model while running, but it must preserve the defined relationship between that model and the serialized documents.

The most important distinction in the architecture is between **moving and organizing objects** and **transforming their document representation**.

A permanent container organizes objects while preserving their independent documents. A stack consolidates object documents into a single representation.

Every implementation decision should preserve that distinction, keep the persistent state understandable, and allow users to inspect and recover their worlds through ordinary file-oriented tools.
