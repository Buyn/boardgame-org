import React from 'react';
import { PlayerHand, GameObject } from '../types';
import { Hand as HandIcon, Play, RefreshCw, Eye, ArrowUpRight } from 'lucide-react';

interface HandViewProps {
  hand: PlayerHand;
  objects: Record<string, GameObject>;
  cursorPos: { x: number; y: number };
  onPlayToBoard: (objectId: string) => void;
  onSelectObject: (objectId: string) => void;
  onFlipCard: (objectId: string) => void;
}

export const HandView: React.FC<HandViewProps> = ({
  hand,
  objects,
  cursorPos,
  onPlayToBoard,
  onSelectObject,
  onFlipCard,
}) => {
  const colName = (col: number) => String.fromCharCode(65 + col);

  return (
    <div className="flex items-center gap-3 px-4 py-2.5 bg-[#181825] border-t border-[#313244] font-mono text-xs select-none">
      {/* Hand Label */}
      <div className="flex items-center gap-2 border-r border-[#313244] pr-4">
        <HandIcon className="w-4 h-4 text-[#cba6f7]" />
        <div>
          <div className="font-bold text-[#cdd6f4] flex items-center gap-1.5">
            <span>{hand.name}</span>
            <span className="px-1.5 py-0.2 rounded-full bg-[#313244] text-[#cba6f7] text-[10px]">
              {hand.objectIds.length}
            </span>
          </div>
          <div className="text-[10px] text-[#6c7086]">
            File: {hand.filePath}
          </div>
        </div>
      </div>

      {/* Items in Hand */}
      <div className="flex-1 flex items-center gap-2 overflow-x-auto py-1">
        {hand.objectIds.length === 0 ? (
          <span className="text-[#585b70] italic text-[11px]">
            Hand is empty. Pick up cards from felt or draw from container.
          </span>
        ) : (
          hand.objectIds.map((objId) => {
            const obj = objects[objId];
            if (!obj) return null;

            return (
              <div
                key={obj.id}
                className="group relative flex items-center gap-2 px-3 py-1.5 bg-[#1e1e2e] hover:bg-[#313244] rounded-lg border border-[#313244] transition-all hover:scale-102 hover:shadow-lg cursor-pointer"
                onClick={() => onSelectObject(obj.id)}
              >
                {/* Glyph */}
                <span className="text-xl">
                  {obj.faceUp === false ? '🂠' : obj.glyph}
                </span>

                {/* Details */}
                <div className="min-w-0">
                  <div className="font-bold text-[#cdd6f4] text-xs truncate max-w-[110px]">
                    {obj.name}
                  </div>
                  <div className="text-[10px] text-[#89b4fa] uppercase">
                    {obj.type}
                  </div>
                </div>

                {/* Hover Quick Actions */}
                <div className="flex items-center gap-1 ml-1">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onPlayToBoard(obj.id);
                    }}
                    className="p-1 rounded bg-[#a6e3a1]/20 hover:bg-[#a6e3a1] text-[#a6e3a1] hover:text-[#11111b] transition-colors"
                    title={`Play to Felt cell ${colName(cursorPos.x)}${cursorPos.y + 1}`}
                  >
                    <ArrowUpRight className="w-3.5 h-3.5" />
                  </button>
                  {obj.type === 'card' && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onFlipCard(obj.id);
                      }}
                      className="p-1 rounded bg-[#cba6f7]/20 hover:bg-[#cba6f7] text-[#cba6f7] hover:text-[#11111b] transition-colors"
                      title="Flip face up/down"
                    >
                      <RefreshCw className="w-3 h-3" />
                    </button>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Target Cell Play Hint */}
      <div className="hidden md:flex items-center gap-1.5 text-[11px] text-[#6c7086] border-l border-[#313244] pl-3">
        <span>Target:</span>
        <span className="text-[#fab387] font-semibold bg-[#313244] px-1.5 py-0.5 rounded">
          {colName(cursorPos.x)}{cursorPos.y + 1}
        </span>
      </div>
    </div>
  );
};
