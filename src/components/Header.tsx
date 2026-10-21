import React from 'react';
import { ViewMode } from '../types';
import {
  Terminal,
  Columns2,
  Maximize2,
  FileCode,
  GitBranch,
  Sparkles,
  HelpCircle,
  RefreshCw,
  FolderOpen
} from 'lucide-react';

interface HeaderProps {
  viewMode: ViewMode;
  onViewModeChange: (mode: ViewMode) => void;
  onOpenHydra: () => void;
  onOpenGitHistory: () => void;
  onOpenNewObject: () => void;
  onResetWorld: () => void;
  commitCount: number;
}

export const Header: React.FC<HeaderProps> = ({
  viewMode,
  onViewModeChange,
  onOpenHydra,
  onOpenGitHistory,
  onOpenNewObject,
  onResetWorld,
  commitCount,
}) => {
  return (
    <header className="flex items-center justify-between px-4 py-2 bg-[#11111b] border-b border-[#313244] font-mono text-xs select-none">
      {/* Title & Brand */}
      <div className="flex items-center gap-3">
        <div className="flex items-center gap-2">
          <div className="w-6 h-6 rounded bg-gradient-to-br from-[#89b4fa] to-[#cba6f7] flex items-center justify-center text-sm shadow">
            🎲
          </div>
          <div>
            <div className="font-bold text-[#cdd6f4] tracking-tight flex items-center gap-1.5">
              <span>boardgame.org</span>
              <span className="text-[10px] px-1.5 py-0.2 bg-[#89b4fa]/20 text-[#89b4fa] rounded font-semibold">
                Emacs / Org-mode Tabletop
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Middle Quick Actions */}
      <div className="hidden md:flex items-center gap-2">
        <button
          onClick={onOpenHydra}
          className="flex items-center gap-1.5 px-2.5 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#89dceb] transition-colors"
          title="Open Hydra Menu [F6]"
        >
          <Terminal className="w-3.5 h-3.5" />
          <span>Hydra [F6]</span>
        </button>

        <button
          onClick={onOpenNewObject}
          className="flex items-center gap-1.5 px-2.5 py-1 rounded bg-[#89b4fa]/20 hover:bg-[#89b4fa]/30 text-[#89b4fa] transition-colors"
        >
          <Sparkles className="w-3.5 h-3.5" />
          <span>New Object</span>
        </button>

        <button
          onClick={onOpenGitHistory}
          className="flex items-center gap-1.5 px-2.5 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#b4befe] transition-colors"
          title="Inspect Git World History & Snapshots"
        >
          <GitBranch className="w-3.5 h-3.5" />
          <span>Git ({commitCount})</span>
        </button>
      </div>

      {/* Right: Layout Switcher & Reset */}
      <div className="flex items-center gap-2">
        <div className="flex items-center bg-[#1e1e2e] p-0.5 rounded border border-[#313244]">
          <button
            onClick={() => onViewModeChange('split')}
            className={`p-1 rounded transition-colors ${
              viewMode === 'split'
                ? 'bg-[#89b4fa] text-[#11111b]'
                : 'text-[#6c7086] hover:text-[#cdd6f4]'
            }`}
            title="Split: Tabletop + Org Buffer"
          >
            <Columns2 className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={() => onViewModeChange('tabletop-only')}
            className={`p-1 rounded transition-colors ${
              viewMode === 'tabletop-only'
                ? 'bg-[#89b4fa] text-[#11111b]'
                : 'text-[#6c7086] hover:text-[#cdd6f4]'
            }`}
            title="Focus: Tabletop Felt"
          >
            <Maximize2 className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={() => onViewModeChange('org-only')}
            className={`p-1 rounded transition-colors ${
              viewMode === 'org-only'
                ? 'bg-[#89b4fa] text-[#11111b]'
                : 'text-[#6c7086] hover:text-[#cdd6f4]'
            }`}
            title="Focus: Org Buffer"
          >
            <FileCode className="w-3.5 h-3.5" />
          </button>
        </div>

        <button
          onClick={onResetWorld}
          className="p-1 rounded hover:bg-[#313244] text-[#6c7086] hover:text-[#f38ba8] transition-colors"
          title="Reset World to default state"
        >
          <RefreshCw className="w-3.5 h-3.5" />
        </button>
      </div>
    </header>
  );
};
