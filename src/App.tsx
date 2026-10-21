import React, { useState, useEffect, useCallback } from 'react';
import {
  BoardState,
  GameObject,
  PlayerHand,
  WorldFile,
  GitCommit,
  ViewMode,
  GameObjectType,
} from './types';
import {
  createInitialWorld
} from './utils/initialWorld';
import {
  parseBoardOrg,
  parseObjectOrg,
  parseHandOrg,
  serializeBoardToOrg,
  serializeObjectToOrg,
  serializeHandToOrg,
} from './utils/orgParser';
import { Header } from './components/Header';
import { Tabletop } from './components/Tabletop';
import { OrgEditor } from './components/OrgEditor';
import { FileBrowser } from './components/FileBrowser';
import { HandView } from './components/HandView';
import { HydraMenu } from './components/HydraMenu';
import { GitHistoryModal } from './components/GitHistoryModal';
import { ObjectModal } from './components/ObjectModal';

export function App() {
  const [world, setWorld] = useState(() => createInitialWorld());
  const [activeFilePath, setActiveFilePath] = useState<string>('boards/board-main.org');
  const [cursorPos, setCursorPos] = useState<{ x: number; y: number }>({ x: 2, y: 2 });
  const [viewMode, setViewMode] = useState<ViewMode>('split');
  const [isHydraOpen, setIsHydraOpen] = useState<boolean>(false);
  const [isGitModalOpen, setIsGitModalOpen] = useState<boolean>(false);
  const [isNewObjectOpen, setIsNewObjectOpen] = useState<boolean>(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState<boolean>(false);

  const { board, objects, hands, files, gitHistory } = world;
  const currentHand = hands[0];

  // Helper to commit world state to Git history
  const createCommit = useCallback(
    (message: string, nextBoard: BoardState, nextObjects: Record<string, GameObject>, nextHands: PlayerHand[], nextFiles: Record<string, WorldFile>) => {
      const commitId = `commit-${Math.random().toString(36).substring(2, 9)}`;
      const newCommit: GitCommit = {
        id: commitId,
        timestamp: new Date().toISOString(),
        message,
        author: 'buyn <buyn.tex@gmail.com>',
        snapshot: {
          files: Object.fromEntries(Object.entries(nextFiles).map(([k, v]) => [k, v.content])),
          board: JSON.parse(JSON.stringify(nextBoard)),
          objects: JSON.parse(JSON.stringify(nextObjects)),
          hands: JSON.parse(JSON.stringify(nextHands)),
        },
      };

      setWorld({
        board: nextBoard,
        objects: nextObjects,
        hands: nextHands,
        files: nextFiles,
        gitHistory: [newCommit, ...gitHistory],
      });
    },
    [gitHistory]
  );

  // Move object on board
  const handleMoveObject = useCallback(
    (objectId: string, targetX: number, targetY: number) => {
      const nextPlaced = board.placedObjects.map((ref) =>
        ref.id === objectId ? { ...ref, x: targetX, y: targetY } : ref
      );

      const nextBoard: BoardState = {
        ...board,
        placedObjects: nextPlaced,
      };

      const boardContent = serializeBoardToOrg(nextBoard, objects);
      const nextFiles: Record<string, WorldFile> = {
        ...files,
        [board.filePath]: {
          ...files[board.filePath],
          content: boardContent,
          updatedAt: new Date().toISOString(),
        },
      };

      const objName = objects[objectId]?.name || objectId;
      createCommit(
        `Move ${objName} to (${targetX}, ${targetY})`,
        nextBoard,
        objects,
        hands,
        nextFiles
      );
    },
    [board, objects, hands, files, createCommit]
  );

  // Pick up object from board to player hand
  const handlePickupToHand = useCallback(
    (objectId: string) => {
      const nextPlaced = board.placedObjects.filter((ref) => ref.id !== objectId);
      const nextBoard: BoardState = {
        ...board,
        placedObjects: nextPlaced,
      };

      const nextHands = hands.map((h) =>
        h.id === currentHand.id
          ? { ...h, objectIds: [...h.objectIds, objectId] }
          : h
      );

      const boardContent = serializeBoardToOrg(nextBoard, objects);
      const handContent = serializeHandToOrg(nextHands[0], objects);

      const nextFiles: Record<string, WorldFile> = {
        ...files,
        [board.filePath]: {
          ...files[board.filePath],
          content: boardContent,
          updatedAt: new Date().toISOString(),
        },
        [currentHand.filePath]: {
          ...files[currentHand.filePath],
          content: handContent,
          updatedAt: new Date().toISOString(),
        },
      };

      const objName = objects[objectId]?.name || objectId;
      createCommit(
        `Pickup ${objName} from board to hand`,
        nextBoard,
        objects,
        nextHands,
        nextFiles
      );
    },
    [board, objects, hands, files, currentHand, createCommit]
  );

  // Play object from hand to board cursor
  const handlePlayToBoard = useCallback(
    (objectId: string) => {
      const nextHands = hands.map((h) =>
        h.id === currentHand.id
          ? { ...h, objectIds: h.objectIds.filter((id) => id !== objectId) }
          : h
      );

      const nextPlaced = [
        ...board.placedObjects,
        { id: objectId, x: cursorPos.x, y: cursorPos.y, layer: 0 },
      ];

      const nextBoard: BoardState = {
        ...board,
        placedObjects: nextPlaced,
      };

      const boardContent = serializeBoardToOrg(nextBoard, objects);
      const handContent = serializeHandToOrg(nextHands[0], objects);

      const nextFiles: Record<string, WorldFile> = {
        ...files,
        [board.filePath]: {
          ...files[board.filePath],
          content: boardContent,
          updatedAt: new Date().toISOString(),
        },
        [currentHand.filePath]: {
          ...files[currentHand.filePath],
          content: handContent,
          updatedAt: new Date().toISOString(),
        },
      };

      const objName = objects[objectId]?.name || objectId;
      createCommit(
        `Play ${objName} to board at (${cursorPos.x}, ${cursorPos.y})`,
        nextBoard,
        objects,
        nextHands,
        nextFiles
      );
    },
    [board, objects, hands, files, currentHand, cursorPos, createCommit]
  );

  // Roll die
  const handleRollDie = useCallback(
    (objectId: string) => {
      const obj = objects[objectId];
      if (!obj || obj.type !== 'die') return;

      const sides = obj.diceSides || 6;
      const roll = Math.floor(Math.random() * sides) + 1;

      // Glyph for standard d6
      const d6Glyphs = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
      const glyph = sides === 6 ? d6Glyphs[roll - 1] : '🎲';

      const nextObj: GameObject = {
        ...obj,
        value: roll,
        glyph,
        properties: {
          ...obj.properties,
          VALUE: String(roll),
          GLYPH: glyph,
        },
      };

      const nextObjects = {
        ...objects,
        [objectId]: nextObj,
      };

      const objContent = serializeObjectToOrg(nextObj);
      const boardContent = serializeBoardToOrg(board, nextObjects);

      const nextFiles: Record<string, WorldFile> = {
        ...files,
        [obj.filePath]: {
          ...files[obj.filePath],
          content: objContent,
          updatedAt: new Date().toISOString(),
        },
        [board.filePath]: {
          ...files[board.filePath],
          content: boardContent,
          updatedAt: new Date().toISOString(),
        },
      };

      createCommit(
        `Roll ${obj.name}: ${roll}`,
        board,
        nextObjects,
        hands,
        nextFiles
      );
    },
    [board, objects, hands, files, createCommit]
  );

  // Flip card
  const handleFlipCard = useCallback(
    (objectId: string) => {
      const obj = objects[objectId];
      if (!obj) return;

      const nextFaceUp = !(obj.faceUp !== false);
      const nextObj: GameObject = {
        ...obj,
        faceUp: nextFaceUp,
        properties: {
          ...obj.properties,
          FACE_UP: nextFaceUp ? 't' : 'nil',
        },
      };

      const nextObjects = {
        ...objects,
        [objectId]: nextObj,
      };

      const objContent = serializeObjectToOrg(nextObj);
      const boardContent = serializeBoardToOrg(board, nextObjects);

      const nextFiles: Record<string, WorldFile> = {
        ...files,
        [obj.filePath]: {
          ...files[obj.filePath],
          content: objContent,
          updatedAt: new Date().toISOString(),
        },
        [board.filePath]: {
          ...files[board.filePath],
          content: boardContent,
          updatedAt: new Date().toISOString(),
        },
      };

      createCommit(
        `Flip ${obj.name} (${nextFaceUp ? 'face up' : 'face down'})`,
        board,
        nextObjects,
        hands,
        nextFiles
      );
    },
    [board, objects, hands, files, createCommit]
  );

  // Consolidate Stack at cell (x, y) per Section 3.1
  const handleStackCell = useCallback(
    (x: number, y: number) => {
      const cellObjects = board.placedObjects.filter((ref) => ref.x === x && ref.y === y);
      if (cellObjects.length < 2) return;

      const stackedItems = cellObjects.map((ref) => {
        const o = objects[ref.id];
        return {
          id: o.id,
          name: o.name,
          glyph: o.glyph,
          type: o.type,
          properties: o.properties,
        };
      });

      const stackId = `stack-${Math.random().toString(36).substring(2, 7)}`;
      const stackPath = `stacks/${stackId}.org`;

      const stackObject: GameObject = {
        id: stackId,
        name: `Consolidated Stack (${stackedItems.length} items)`,
        glyph: '🂠',
        type: 'stack',
        description: 'A consolidated Org document containing the merged content of multiple objects.',
        filePath: stackPath,
        isStack: true,
        stackedObjects: stackedItems,
        properties: {
          ID: stackId,
          NAME: `Consolidated Stack (${stackedItems.length} items)`,
          TYPE: 'stack',
          GLYPH: '🂠',
          IS_STACK: 't',
          STACK_SIZE: String(stackedItems.length),
        },
      };

      // 1. Remove consolidated objects from individual objects & remove their standalone files
      const nextObjects = { ...objects };
      const nextFiles = { ...files };

      for (const item of stackedItems) {
        const itemObj = objects[item.id];
        if (itemObj) {
          delete nextObjects[item.id];
          delete nextFiles[itemObj.filePath];
        }
      }

      // 2. Add stack object
      nextObjects[stackId] = stackObject;
      const stackContent = serializeObjectToOrg(stackObject);
      nextFiles[stackPath] = {
        path: stackPath,
        name: `${stackId}.org`,
        type: 'stack',
        content: stackContent,
        updatedAt: new Date().toISOString(),
      };

      // 3. Update board placed objects
      const nextPlaced = [
        ...board.placedObjects.filter((ref) => !(ref.x === x && ref.y === y)),
        { id: stackId, x, y, layer: 0 },
      ];

      const nextBoard: BoardState = {
        ...board,
        placedObjects: nextPlaced,
      };

      nextFiles[board.filePath] = {
        ...nextFiles[board.filePath],
        content: serializeBoardToOrg(nextBoard, nextObjects),
        updatedAt: new Date().toISOString(),
      };

      setActiveFilePath(stackPath);

      createCommit(
        `Consolidate ${stackedItems.length} objects into stack ${stackId} and remove standalone files`,
        nextBoard,
        nextObjects,
        hands,
        nextFiles
      );
    },
    [board, objects, hands, files, createCommit]
  );

  // Expand Stack into independent Org files per Section 3.1
  const handleExpandStack = useCallback(
    (stackId: string) => {
      const stackObj = objects[stackId];
      if (!stackObj || !stackObj.isStack || !stackObj.stackedObjects) return;

      const stackRef = board.placedObjects.find((r) => r.id === stackId);
      const coord = stackRef ? { x: stackRef.x, y: stackRef.y } : cursorPos;

      const nextObjects = { ...objects };
      const nextFiles = { ...files };
      delete nextObjects[stackId];
      delete nextFiles[stackObj.filePath];

      const newPlacedRefs = [...board.placedObjects.filter((r) => r.id !== stackId)];

      // Reconstruct standalone documents
      stackObj.stackedObjects.forEach((item, idx) => {
        const objId = item.id;
        const filePath = `objects/${objId}.org`;
        const newObj: GameObject = {
          id: objId,
          name: item.name,
          glyph: item.glyph,
          type: item.type,
          description: `Reconstituted from stack ${stackObj.name}`,
          properties: item.properties,
          filePath,
          faceUp: true,
        };

        nextObjects[objId] = newObj;
        nextFiles[filePath] = {
          path: filePath,
          name: `${objId}.org`,
          type: 'object',
          content: serializeObjectToOrg(newObj),
          updatedAt: new Date().toISOString(),
        };

        newPlacedRefs.push({
          id: objId,
          x: coord.x,
          y: coord.y,
          layer: idx,
        });
      });

      const nextBoard: BoardState = {
        ...board,
        placedObjects: newPlacedRefs,
      };

      nextFiles[board.filePath] = {
        ...nextFiles[board.filePath],
        content: serializeBoardToOrg(nextBoard, nextObjects),
        updatedAt: new Date().toISOString(),
      };

      createCommit(
        `Expand stack ${stackId} into ${stackObj.stackedObjects.length} independent Org documents`,
        nextBoard,
        nextObjects,
        hands,
        nextFiles
      );
    },
    [board, objects, hands, files, cursorPos, createCommit]
  );

  // Draw from container into player hand
  const handleDrawFromContainer = useCallback(
    (containerId: string) => {
      const container = objects[containerId];
      if (!container || !container.isContainer || !container.containedObjectIds?.length) return;

      const [drawnId, ...remainingIds] = container.containedObjectIds;
      const drawnObj = objects[drawnId];

      const nextContainer: GameObject = {
        ...container,
        containedObjectIds: remainingIds,
        properties: {
          ...container.properties,
          ITEM_COUNT: String(remainingIds.length),
        },
      };

      const nextObjects = {
        ...objects,
        [containerId]: nextContainer,
      };

      const nextHands = hands.map((h) =>
        h.id === currentHand.id
          ? { ...h, objectIds: [...h.objectIds, drawnId] }
          : h
      );

      const nextFiles = { ...files };
      nextFiles[container.filePath] = {
        ...nextFiles[container.filePath],
        content: serializeObjectToOrg(nextContainer),
        updatedAt: new Date().toISOString(),
      };
      nextFiles[currentHand.filePath] = {
        ...nextFiles[currentHand.filePath],
        content: serializeHandToOrg(nextHands[0], nextObjects),
        updatedAt: new Date().toISOString(),
      };

      const drawnName = drawnObj?.name || drawnId;
      createCommit(
        `Draw ${drawnName} from ${container.name} to player hand`,
        board,
        nextObjects,
        nextHands,
        nextFiles
      );
    },
    [board, objects, hands, files, currentHand, createCommit]
  );

  // Shuffle container
  const handleShuffleContainer = useCallback(
    (containerId: string) => {
      const container = objects[containerId];
      if (!container || !container.isContainer || !container.containedObjectIds) return;

      const shuffled = [...container.containedObjectIds].sort(() => Math.random() - 0.5);
      const nextContainer: GameObject = {
        ...container,
        containedObjectIds: shuffled,
      };

      const nextObjects = {
        ...objects,
        [containerId]: nextContainer,
      };

      const nextFiles = { ...files };
      nextFiles[container.filePath] = {
        ...nextFiles[container.filePath],
        content: serializeObjectToOrg(nextContainer),
        updatedAt: new Date().toISOString(),
      };

      createCommit(
        `Shuffle container ${container.name}`,
        board,
        nextObjects,
        hands,
        nextFiles
      );
    },
    [board, objects, hands, files, createCommit]
  );

  // Delete object
  const handleDeleteObject = useCallback(
    (objectId: string) => {
      const obj = objects[objectId];
      if (!obj) return;

      const nextObjects = { ...objects };
      delete nextObjects[objectId];

      const nextFiles = { ...files };
      delete nextFiles[obj.filePath];

      const nextPlaced = board.placedObjects.filter((r) => r.id !== objectId);
      const nextBoard = { ...board, placedObjects: nextPlaced };
      nextFiles[board.filePath] = {
        ...nextFiles[board.filePath],
        content: serializeBoardToOrg(nextBoard, nextObjects),
        updatedAt: new Date().toISOString(),
      };

      const nextHands = hands.map((h) => ({
        ...h,
        objectIds: h.objectIds.filter((id) => id !== objectId),
      }));
      nextFiles[currentHand.filePath] = {
        ...nextFiles[currentHand.filePath],
        content: serializeHandToOrg(nextHands[0], nextObjects),
        updatedAt: new Date().toISOString(),
      };

      createCommit(
        `Delete object ${obj.name} and remove ${obj.filePath}`,
        nextBoard,
        nextObjects,
        nextHands,
        nextFiles
      );
    },
    [board, objects, hands, files, currentHand, createCommit]
  );

  // Save modified Org content directly from editor (Round-trip persistence!)
  const handleSaveContent = useCallback(
    (filePath: string, newContent: string) => {
      const targetFile = files[filePath];
      if (!targetFile) return;

      let nextBoard = board;
      let nextObjects = { ...objects };
      let nextHands = [...hands];

      // Re-parse based on file type
      if (targetFile.type === 'board') {
        nextBoard = parseBoardOrg(newContent, filePath);
      } else if (targetFile.type === 'hand') {
        const updatedHand = parseHandOrg(newContent, filePath);
        nextHands = nextHands.map((h) => (h.filePath === filePath ? updatedHand : h));
      } else if (['object', 'stack', 'container'].includes(targetFile.type)) {
        const updatedObj = parseObjectOrg(newContent, filePath);
        nextObjects[updatedObj.id] = updatedObj;
      }

      const nextFiles: Record<string, WorldFile> = {
        ...files,
        [filePath]: {
          ...targetFile,
          content: newContent,
          updatedAt: new Date().toISOString(),
        },
      };

      createCommit(
        `Direct Org edit saved: ${targetFile.name}`,
        nextBoard,
        nextObjects,
        nextHands,
        nextFiles
      );
    },
    [board, objects, hands, files, createCommit]
  );

  // Select an object to inspect in the Org editor
  const handleSelectObject = useCallback(
    (objectId: string) => {
      const obj = objects[objectId];
      if (obj && files[obj.filePath]) {
        setActiveFilePath(obj.filePath);
      }
    },
    [objects, files]
  );

  // Mint new object
  const handleCreateObject = (newObj: Partial<GameObject>, destination: 'board' | 'hand' | 'catalog') => {
    const fullObj = newObj as GameObject;
    const nextObjects = {
      ...objects,
      [fullObj.id]: fullObj,
    };

    const content = serializeObjectToOrg(fullObj);
    const nextFiles: Record<string, WorldFile> = {
      ...files,
      [fullObj.filePath]: {
        path: fullObj.filePath,
        name: `${fullObj.id}.org`,
        type: fullObj.isContainer ? 'container' : fullObj.isStack ? 'stack' : 'object',
        content,
        updatedAt: new Date().toISOString(),
      },
    };

    let nextBoard = board;
    let nextHands = hands;

    if (destination === 'board') {
      nextBoard = {
        ...board,
        placedObjects: [
          ...board.placedObjects,
          { id: fullObj.id, x: cursorPos.x, y: cursorPos.y, layer: 0 },
        ],
      };
      nextFiles[board.filePath] = {
        ...nextFiles[board.filePath],
        content: serializeBoardToOrg(nextBoard, nextObjects),
        updatedAt: new Date().toISOString(),
      };
    } else if (destination === 'hand') {
      nextHands = hands.map((h) =>
        h.id === currentHand.id
          ? { ...h, objectIds: [...h.objectIds, fullObj.id] }
          : h
      );
      nextFiles[currentHand.filePath] = {
        ...nextFiles[currentHand.filePath],
        content: serializeHandToOrg(nextHands[0], nextObjects),
        updatedAt: new Date().toISOString(),
      };
    }

    setActiveFilePath(fullObj.filePath);
    createCommit(
      `Mint new object ${fullObj.name} (${destination})`,
      nextBoard,
      nextObjects,
      nextHands,
      nextFiles
    );
  };

  // Rollback world to a Git commit
  const handleRollback = useCallback((commit: GitCommit) => {
    const { snapshot } = commit;
    const restoredFiles: Record<string, WorldFile> = {};
    for (const [path, content] of Object.entries(snapshot.files)) {
      const type = path.startsWith('boards/')
        ? 'board'
        : path.startsWith('stacks/')
        ? 'stack'
        : path.startsWith('containers/')
        ? 'container'
        : path.startsWith('hands/')
        ? 'hand'
        : path.startsWith('docs/')
        ? 'doc'
        : 'object';

      restoredFiles[path] = {
        path,
        name: path.split('/').pop() || path,
        type: type as any,
        content,
        updatedAt: new Date().toISOString(),
      };
    }

    setWorld({
      board: JSON.parse(JSON.stringify(snapshot.board)),
      objects: JSON.parse(JSON.stringify(snapshot.objects)),
      hands: JSON.parse(JSON.stringify(snapshot.hands)),
      files: restoredFiles,
      gitHistory,
    });
  }, [gitHistory]);

  // Handle Hydra action keys
  const handleHydraAction = useCallback(
    (actionKey: string) => {
      setIsHydraOpen(false);
      switch (actionKey) {
        case 'N':
        case 'P':
        case 'c':
          setIsNewObjectOpen(true);
          break;
        case 's':
          // Save active file
          if (activeFilePath && files[activeFilePath]) {
            handleSaveContent(activeFilePath, files[activeFilePath].content);
          }
          break;
        case 'o':
          // Focus board or first object
          setActiveFilePath(board.filePath);
          break;
        case 'k':
          handleStackCell(cursorPos.x, cursorPos.y);
          break;
        case 'u': {
          const currentCellObjs = board.placedObjects.filter(
            (r) => r.x === cursorPos.x && r.y === cursorPos.y
          );
          const top = currentCellObjs[currentCellObjs.length - 1];
          if (top && objects[top.id]?.isStack) {
            handleExpandStack(top.id);
          }
          break;
        }
        case 'd': {
          const currentCellObjs = board.placedObjects.filter(
            (r) => r.x === cursorPos.x && r.y === cursorPos.y
          );
          const top = currentCellObjs[currentCellObjs.length - 1];
          if (top && objects[top.id]?.isContainer) {
            handleDrawFromContainer(top.id);
          }
          break;
        }
        case 'r': {
          const currentCellObjs = board.placedObjects.filter(
            (r) => r.x === cursorPos.x && r.y === cursorPos.y
          );
          const top = currentCellObjs[currentCellObjs.length - 1];
          if (top && objects[top.id]?.type === 'die') {
            handleRollDie(top.id);
          }
          break;
        }
        case 'f': {
          const currentCellObjs = board.placedObjects.filter(
            (r) => r.x === cursorPos.x && r.y === cursorPos.y
          );
          const top = currentCellObjs[currentCellObjs.length - 1];
          if (top) {
            handleFlipCard(top.id);
          }
          break;
        }
        case 'g':
          setIsGitModalOpen(true);
          break;
        case 'D': {
          const currentCellObjs = board.placedObjects.filter(
            (r) => r.x === cursorPos.x && r.y === cursorPos.y
          );
          const top = currentCellObjs[currentCellObjs.length - 1];
          if (top) {
            handleDeleteObject(top.id);
          }
          break;
        }
        default:
          break;
      }
    },
    [
      activeFilePath,
      files,
      board,
      cursorPos,
      objects,
      handleSaveContent,
      handleStackCell,
      handleExpandStack,
      handleDrawFromContainer,
      handleRollDie,
      handleFlipCard,
      handleDeleteObject,
    ]
  );

  // Keyboard navigation on tabletop (Arrow keys, F6 for Hydra)
  useEffect(() => {
    const handleGlobalKeyDown = (e: KeyboardEvent) => {
      // Don't intercept when user is typing in input or textarea
      if (
        document.activeElement?.tagName === 'INPUT' ||
        document.activeElement?.tagName === 'TEXTAREA'
      ) {
        return;
      }

      if (e.key === 'F6' || (e.code === 'Space' && !e.repeat && !isHydraOpen)) {
        e.preventDefault();
        setIsHydraOpen((prev) => !prev);
        return;
      }

      // Cursor movement
      if (e.key === 'ArrowRight' || e.key === 'l') {
        e.preventDefault();
        setCursorPos((prev) => ({ ...prev, x: Math.min(board.width - 1, prev.x + 1) }));
      } else if (e.key === 'ArrowLeft' || e.key === 'h') {
        e.preventDefault();
        setCursorPos((prev) => ({ ...prev, x: Math.max(0, prev.x - 1) }));
      } else if (e.key === 'ArrowDown' || e.key === 'j') {
        e.preventDefault();
        setCursorPos((prev) => ({ ...prev, y: Math.min(board.height - 1, prev.y + 1) }));
      } else if (e.key === 'ArrowUp' || e.key === 'k') {
        e.preventDefault();
        setCursorPos((prev) => ({ ...prev, y: Math.max(0, prev.y - 1) }));
      }
    };

    window.addEventListener('keydown', handleGlobalKeyDown);
    return () => window.removeEventListener('keydown', handleGlobalKeyDown);
  }, [board.width, board.height, isHydraOpen]);

  const activeFile = files[activeFilePath] || null;

  return (
    <div className="flex flex-col h-screen w-screen bg-[#1e1e2e] text-[#cdd6f4] font-mono select-none overflow-hidden">
      {/* Top Header */}
      <Header
        viewMode={viewMode}
        onViewModeChange={setViewMode}
        onOpenHydra={() => setIsHydraOpen(true)}
        onOpenGitHistory={() => setIsGitModalOpen(true)}
        onOpenNewObject={() => setIsNewObjectOpen(true)}
        onResetWorld={() => setWorld(createInitialWorld())}
        commitCount={gitHistory.length}
      />

      {/* Main Workspace Body */}
      <div className="flex-1 flex overflow-hidden">
        {/* Left World File Tree */}
        <div className={`w-64 flex-shrink-0 ${sidebarCollapsed ? 'hidden' : 'block'}`}>
          <FileBrowser
            files={files}
            activeFilePath={activeFilePath}
            onSelectFile={(path) => setActiveFilePath(path)}
            onCreateFile={(type) => {
              setIsNewObjectOpen(true);
            }}
            onDeleteFile={handleDeleteObject}
          />
        </div>

        {/* Center/Right Panels */}
        <div className="flex-1 flex flex-col min-w-0">
          <div className="flex-1 flex overflow-hidden">
            {/* Tabletop View */}
            {(viewMode === 'split' || viewMode === 'tabletop-only') && (
              <div
                className={`flex-1 min-w-0 ${
                  viewMode === 'split' ? 'w-1/2 border-r border-[#313244]' : 'w-full'
                }`}
              >
                <Tabletop
                  board={board}
                  objects={objects}
                  cursorPos={cursorPos}
                  onCursorChange={setCursorPos}
                  onMoveObject={handleMoveObject}
                  onSelectObject={handleSelectObject}
                  onPickupToHand={handlePickupToHand}
                  onRollDie={handleRollDie}
                  onFlipCard={handleFlipCard}
                  onStackCell={handleStackCell}
                  onExpandStack={handleExpandStack}
                  onShuffleContainer={handleShuffleContainer}
                  onDrawFromContainer={handleDrawFromContainer}
                  onDeleteObject={handleDeleteObject}
                  onOpenHydra={() => setIsHydraOpen(true)}
                  onAddObjectAtCursor={() => setIsNewObjectOpen(true)}
                />
              </div>
            )}

            {/* Org Document Editor / Buffer View */}
            {(viewMode === 'split' || viewMode === 'org-only') && (
              <div
                className={`flex-1 min-w-0 ${
                  viewMode === 'split' ? 'w-1/2' : 'w-full'
                }`}
              >
                <OrgEditor
                  currentFile={activeFile}
                  onSaveContent={handleSaveContent}
                  onNavigateToFile={(path) => {
                    if (files[path]) {
                      setActiveFilePath(path);
                    }
                  }}
                />
              </div>
            )}
          </div>

          {/* Bottom Player Hand View */}
          {currentHand && (
            <HandView
              hand={currentHand}
              objects={objects}
              cursorPos={cursorPos}
              onPlayToBoard={handlePlayToBoard}
              onSelectObject={handleSelectObject}
              onFlipCard={handleFlipCard}
            />
          )}
        </div>
      </div>

      {/* Modals */}
      <HydraMenu
        isOpen={isHydraOpen}
        onClose={() => setIsHydraOpen(false)}
        onAction={handleHydraAction}
      />

      <GitHistoryModal
        isOpen={isGitModalOpen}
        onClose={() => setIsGitModalOpen(false)}
        commits={gitHistory}
        onRollback={handleRollback}
      />

      <ObjectModal
        isOpen={isNewObjectOpen}
        onClose={() => setIsNewObjectOpen(false)}
        onSave={handleCreateObject}
      />
    </div>
  );
}

export default App;
