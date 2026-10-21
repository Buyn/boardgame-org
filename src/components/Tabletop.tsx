import React, { useState } from 'react';
import { BoardState, GameObject, PlacedObjectRef } from '../types';
import {
  Layers,
  Dices,
  Hand as HandIcon,
  Plus,
  RefreshCw,
  FolderInput,
  ExternalLink,
  Trash2,
  Eye,
  Shuffle,
  ChevronRight,
  Maximize2
} from 'lucide-react';

interface TabletopProps {
  board: BoardState;
  objects: Record<string, GameObject>;
  cursorPos: { x: number; y: number };
  onCursorChange: (pos: { x: number; y: number }) => void;
  onMoveObject: (objectId: string, targetX: number, targetY: number) => void;
  onSelectObject: (objectId: string) => void;
  onPickupToHand: (objectId: string) => void;
  onRollDie: (objectId: string) => void;
  onFlipCard: (objectId: string) => void;
  onStackCell: (x: number, y: number) => void;
  onExpandStack: (objectId: string) => void;
  onShuffleContainer: (objectId: string) => void;
  onDrawFromContainer: (objectId: string) => void;
  onDeleteObject: (objectId: string) => void;
  onOpenHydra: () => void;
  onAddObjectAtCursor: () => void;
}

export const Tabletop: React.FC<TabletopProps> = ({
  board,
  objects,
  cursorPos,
  onCursorChange,
  onMoveObject,
  onSelectObject,
  onPickupToHand,
  onRollDie,
  onFlipCard,
  onStackCell,
  onExpandStack,
  onShuffleContainer,
  onDrawFromContainer,
  onDeleteObject,
  onOpenHydra,
  onAddObjectAtCursor,
}) => {
  const [draggedObjectId, setDraggedObjectId] = useState<string | null>(null);
  const [hoveredCell, setHoveredCell] = useState<{ x: number; y: number } | null>(null);
  const [layerInspectorOpen, setLayerInspectorOpen] = useState(false);

  // Map of coordinate key "x,y" to list of placed objects
  const cellObjectsMap = React.useMemo(() => {
    const map = new Map<string, PlacedObjectRef[]>();
    for (const ref of board.placedObjects) {
      const key = `${ref.x},${ref.y}`;
      const list = map.get(key) || [];
      list.push(ref);
      map.set(key, list);
    }
    // Sort each cell by layer ascending
    map.forEach((list) => {
      list.sort((a, b) => a.layer - b.layer);
    });
    return map;
  }, [board.placedObjects]);

  const currentCellObjects = cellObjectsMap.get(`${cursorPos.x},${cursorPos.y}`) || [];
  const topObjectRef = currentCellObjects[currentCellObjects.length - 1];
  const topObject = topObjectRef ? objects[topObjectRef.id] : null;

  const handleCellClick = (x: number, y: number) => {
    onCursorChange({ x, y });
    const cellObjs = cellObjectsMap.get(`${x},${y}`) || [];
    if (cellObjs.length > 0) {
      const top = cellObjs[cellObjs.length - 1];
      onSelectObject(top.id);
    }
  };

  const handleDragStart = (e: React.DragEvent, objectId: string) => {
    e.dataTransfer.setData('text/plain', objectId);
    setDraggedObjectId(objectId);
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
  };

  const handleDrop = (e: React.DragEvent, targetX: number, targetY: number) => {
    e.preventDefault();
    const objectId = e.dataTransfer.getData('text/plain') || draggedObjectId;
    if (objectId) {
      onMoveObject(objectId, targetX, targetY);
      onCursorChange({ x: targetX, y: targetY });
    }
    setDraggedObjectId(null);
  };

  // Convert column index to A, B, C...
  const colName = (col: number) => String.fromCharCode(65 + col);

  return (
    <div className="flex flex-col h-full bg-[#181825] border-r border-[#313244] select-none overflow-hidden">
      {/* Tabletop Control Header */}
      <div className="flex items-center justify-between px-3 py-2 bg-[#11111b] border-b border-[#313244] text-xs">
        <div className="flex items-center gap-2">
          <span className="font-bold text-[#89b4fa] flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-sm bg-[#89b4fa]"></span>
            FELT TABLETOP
          </span>
          <span className="text-[#6c7086]">|</span>
          <span className="text-[#cdd6f4]">
            {board.name} ({board.width}×{board.height})
          </span>
          <span className="text-[#6c7086]">|</span>
          <span className="px-1.5 py-0.5 rounded bg-[#313244] text-[#fab387] font-semibold">
            Point: {colName(cursorPos.x)}{cursorPos.y + 1} ({cursorPos.x}, {cursorPos.y})
          </span>
        </div>

        <div className="flex items-center gap-1.5">
          <button
            onClick={onOpenHydra}
            title="Open Hydra Menu (F6 / Space)"
            className="flex items-center gap-1 px-2 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#89dceb] transition-colors"
          >
            <span>Hydra [F6]</span>
          </button>
          <button
            onClick={onAddObjectAtCursor}
            title="Place / Spawn new object at cursor"
            className="flex items-center gap-1 px-2 py-1 rounded bg-[#89b4fa]/20 text-[#89b4fa] hover:bg-[#89b4fa]/30 transition-colors"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Place</span>
          </button>
          {currentCellObjects.length > 1 && (
            <button
              onClick={() => onStackCell(cursorPos.x, cursorPos.y)}
              title="Consolidate cell objects into an Org Stack"
              className="flex items-center gap-1 px-2 py-1 rounded bg-[#f9e2af]/20 text-[#f9e2af] hover:bg-[#f9e2af]/30 transition-colors"
            >
              <Layers className="w-3.5 h-3.5" />
              <span>Consolidate Stack ({currentCellObjects.length})</span>
            </button>
          )}
        </div>
      </div>

      {/* Main Grid Viewport */}
      <div className="flex-1 overflow-auto p-4 flex items-center justify-center bg-[#11111b]/80 relative">
        <div className="inline-block p-4 rounded-xl bg-[#181825] border-2 border-[#313244] shadow-2xl">
          {/* Column letters */}
          <div className="flex ml-8 mb-1">
            {Array.from({ length: board.width }).map((_, c) => (
              <div
                key={c}
                className={`w-10 sm:w-11 text-center font-mono text-[11px] font-semibold ${
                  c === cursorPos.x ? 'text-[#89b4fa]' : 'text-[#6c7086]'
                }`}
              >
                {colName(c)}
              </div>
            ))}
          </div>

          {/* Grid rows */}
          <div className="flex flex-col gap-1">
            {Array.from({ length: board.height }).map((_, r) => (
              <div key={r} className="flex items-center gap-1">
                {/* Row Number */}
                <div
                  className={`w-7 text-right pr-2 font-mono text-[11px] font-semibold ${
                    r === cursorPos.y ? 'text-[#89b4fa]' : 'text-[#6c7086]'
                  }`}
                >
                  {r + 1}
                </div>

                {/* Cells in Row */}
                {Array.from({ length: board.width }).map((_, c) => {
                  const isCursor = cursorPos.x === c && cursorPos.y === r;
                  const isHovered = hoveredCell?.x === c && hoveredCell?.y === r;
                  const key = `${c},${r}`;
                  const cellObjs = cellObjectsMap.get(key) || [];
                  const topRef = cellObjs[cellObjs.length - 1];
                  const obj = topRef ? objects[topRef.id] : null;
                  const count = cellObjs.length;
                  const feltChar = board.feltGrid[r]?.[c] || board.defaultFelt;

                  return (
                    <div
                      key={c}
                      onClick={() => handleCellClick(c, r)}
                      onMouseEnter={() => setHoveredCell({ x: c, y: r })}
                      onMouseLeave={() => setHoveredCell(null)}
                      onDragOver={handleDragOver}
                      onDrop={(e) => handleDrop(e, c, r)}
                      className={`relative w-10 h-10 sm:w-11 sm:h-11 rounded flex items-center justify-center font-mono text-lg cursor-pointer transition-all ${
                        isCursor
                          ? 'ring-2 ring-[#89b4fa] bg-[#313244] shadow-lg shadow-[#89b4fa]/20 z-10 scale-105'
                          : isHovered
                          ? 'bg-[#252538] ring-1 ring-[#585b70]'
                          : 'bg-[#1e1e2e]/90 hover:bg-[#252538]'
                      } border border-[#313244]/60`}
                    >
                      {/* Felt background character if empty */}
                      {!obj && (
                        <span className="text-[#45475a] text-sm select-none">
                          {feltChar}
                        </span>
                      )}

                      {/* Placed Object Render */}
                      {obj && (
                        <div
                          draggable
                          onDragStart={(e) => handleDragStart(e, obj.id)}
                          className={`relative flex items-center justify-center w-full h-full cursor-grab active:cursor-grabbing ${
                            obj.color ? `text-[${obj.color}]` : 'text-[#cdd6f4]'
                          }`}
                          title={`${obj.name} (${obj.type}) - Click to inspect, drag to move`}
                        >
                          {/* Glyph */}
                          <span className="text-xl transform hover:scale-110 transition-transform drop-shadow">
                            {obj.faceUp === false ? '🂠' : obj.glyph}
                          </span>

                          {/* Count indicator per boardgame-org.md Section 5:
                              A count from 1 to 9 may be represented by its digit; larger count is +
                              Renders count indicator on upper-left */}
                          {count > 1 && (
                            <span className="absolute -top-1 -left-1 px-1 min-w-[14px] h-3.5 flex items-center justify-center text-[9px] font-bold rounded-full bg-[#f9e2af] text-[#11111b] shadow ring-1 ring-[#181825]">
                              {count <= 9 ? count : '+'}
                            </span>
                          )}

                          {/* Stack / Container indicator badge */}
                          {obj.isContainer && (
                            <span className="absolute -bottom-1 -right-1 text-[8px] px-1 bg-[#89dceb] text-[#11111b] font-bold rounded">
                              DECK
                            </span>
                          )}
                          {obj.isStack && (
                            <span className="absolute -bottom-1 -right-1 text-[8px] px-1 bg-[#f38ba8] text-[#11111b] font-bold rounded">
                              STACK
                            </span>
                          )}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Selected Cell Action Panel / Status Modeline */}
      <div className="bg-[#11111b] border-t border-[#313244] p-3 text-xs">
        {topObject ? (
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <span className="text-2xl p-1 bg-[#1e1e2e] rounded border border-[#313244]">
                {topObject.faceUp === false ? '🂠' : topObject.glyph}
              </span>
              <div>
                <div className="flex items-center gap-2">
                  <span className="font-bold text-[#cdd6f4] text-sm">{topObject.name}</span>
                  <span className="px-1.5 py-0.5 rounded bg-[#313244] text-[#89b4fa] text-[10px] uppercase font-semibold">
                    {topObject.type}
                  </span>
                  {currentCellObjects.length > 1 && (
                    <span className="px-1.5 py-0.5 rounded bg-[#f9e2af]/20 text-[#f9e2af] text-[10px]">
                      {currentCellObjects.length} items at cell
                    </span>
                  )}
                </div>
                <div className="text-[#a6adc8] text-[11px] font-mono mt-0.5">
                  File: <span className="text-[#89dceb]">{topObject.filePath}</span>
                </div>
              </div>
            </div>

            {/* Quick action buttons for selected object */}
            <div className="flex items-center flex-wrap gap-1.5">
              <button
                onClick={() => onSelectObject(topObject.id)}
                className="px-2 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#cdd6f4] flex items-center gap-1 transition-colors"
              >
                <Eye className="w-3 h-3 text-[#89b4fa]" />
                <span>Inspect Org</span>
              </button>

              <button
                onClick={() => onPickupToHand(topObject.id)}
                className="px-2 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#a6e3a1] flex items-center gap-1 transition-colors"
                title="Pick up into Player Hand"
              >
                <HandIcon className="w-3 h-3" />
                <span>To Hand</span>
              </button>

              {topObject.type === 'die' && (
                <button
                  onClick={() => onRollDie(topObject.id)}
                  className="px-2 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#fab387] flex items-center gap-1 transition-colors"
                >
                  <Dices className="w-3 h-3" />
                  <span>Roll Die</span>
                </button>
              )}

              {topObject.type === 'card' && (
                <button
                  onClick={() => onFlipCard(topObject.id)}
                  className="px-2 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#cba6f7] flex items-center gap-1 transition-colors"
                >
                  <RefreshCw className="w-3 h-3" />
                  <span>Flip ({topObject.faceUp !== false ? 'Face Down' : 'Face Up'})</span>
                </button>
              )}

              {topObject.isContainer && (
                <>
                  <button
                    onClick={() => onDrawFromContainer(topObject.id)}
                    className="px-2 py-1 rounded bg-[#89b4fa]/20 hover:bg-[#89b4fa]/30 text-[#89b4fa] flex items-center gap-1 transition-colors"
                  >
                    <FolderInput className="w-3 h-3" />
                    <span>Draw 1 ({topObject.containedObjectIds?.length || 0} left)</span>
                  </button>
                  <button
                    onClick={() => onShuffleContainer(topObject.id)}
                    className="px-2 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#f9e2af] flex items-center gap-1 transition-colors"
                  >
                    <Shuffle className="w-3 h-3" />
                    <span>Shuffle</span>
                  </button>
                </>
              )}

              {topObject.isStack && (
                <button
                  onClick={() => onExpandStack(topObject.id)}
                  className="px-2 py-1 rounded bg-[#f38ba8]/20 hover:bg-[#f38ba8]/30 text-[#f38ba8] flex items-center gap-1 transition-colors"
                  title="Expand stack back into independent Org files"
                >
                  <Maximize2 className="w-3 h-3" />
                  <span>Expand Stack ({topObject.stackedObjects?.length || 0})</span>
                </button>
              )}

              <button
                onClick={() => onDeleteObject(topObject.id)}
                className="px-2 py-1 rounded bg-[#313244] hover:bg-[#f38ba8]/20 text-[#f38ba8] flex items-center gap-1 transition-colors"
                title="Delete object and its Org representation"
              >
                <Trash2 className="w-3 h-3" />
              </button>
            </div>
          </div>
        ) : (
          <div className="flex items-center justify-between text-[#6c7086]">
            <span>Empty Felt Cell ({colName(cursorPos.x)}{cursorPos.y + 1}). Use [Place] or drag cards/tokens here.</span>
            <span className="font-mono text-[11px]">Emacs Hydra Menu: press [F6] or Space</span>
          </div>
        )}
      </div>
    </div>
  );
};
