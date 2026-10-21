import React, { useState } from 'react';
import { WorldFile } from '../types';
import {
  Folder,
  FileCode,
  FileText,
  Layers,
  Archive,
  Hand as HandIcon,
  Plus,
  Trash2,
  ChevronDown,
  ChevronRight,
  Database
} from 'lucide-react';

interface FileBrowserProps {
  files: Record<string, WorldFile>;
  activeFilePath: string;
  onSelectFile: (path: string) => void;
  onCreateFile: (type: 'object' | 'stack' | 'container' | 'board' | 'hand' | 'doc') => void;
  onDeleteFile: (path: string) => void;
}

export const FileBrowser: React.FC<FileBrowserProps> = ({
  files,
  activeFilePath,
  onSelectFile,
  onCreateFile,
  onDeleteFile,
}) => {
  const [collapsedCategories, setCollapsedCategories] = useState<Record<string, boolean>>({});

  const toggleCategory = (cat: string) => {
    setCollapsedCategories((prev) => ({
      ...prev,
      [cat]: !prev[cat],
    }));
  };

  const categories = [
    { id: 'board', label: 'Boards', icon: Database, color: 'text-[#89b4fa]' },
    { id: 'object', label: 'Objects', icon: FileCode, color: 'text-[#a6e3a1]' },
    { id: 'stack', label: 'Stacks (Consolidated)', icon: Layers, color: 'text-[#f38ba8]' },
    { id: 'container', label: 'Containers (Decks/Bags)', icon: Archive, color: 'text-[#f9e2af]' },
    { id: 'hand', label: 'Player Hands', icon: HandIcon, color: 'text-[#cba6f7]' },
    { id: 'doc', label: 'Docs & Architecture', icon: FileText, color: 'text-[#89dceb]' },
  ];

  const filesByCategory: Record<string, WorldFile[]> = {
    board: [],
    object: [],
    stack: [],
    container: [],
    hand: [],
    doc: [],
  };

  for (const file of Object.values(files)) {
    if (filesByCategory[file.type]) {
      filesByCategory[file.type].push(file);
    } else {
      filesByCategory['doc'].push(file);
    }
  }

  return (
    <div className="flex flex-col h-full bg-[#181825] border-r border-[#313244] text-xs font-mono select-none overflow-hidden">
      {/* File Tree Header */}
      <div className="flex items-center justify-between px-3 py-2 bg-[#11111b] border-b border-[#313244]">
        <div className="flex items-center gap-1.5 font-bold text-[#cdd6f4]">
          <Folder className="w-3.5 h-3.5 text-[#f9e2af]" />
          <span>WORLD REPO</span>
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={() => onCreateFile('object')}
            title="Create new Object Org file"
            className="p-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#a6e3a1] transition-colors"
          >
            <Plus className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Categories & File List */}
      <div className="flex-1 overflow-auto p-2 space-y-2">
        {categories.map((cat) => {
          const list = filesByCategory[cat.id] || [];
          const isCollapsed = collapsedCategories[cat.id];
          const Icon = cat.icon;

          return (
            <div key={cat.id} className="space-y-0.5">
              {/* Category Header */}
              <div
                onClick={() => toggleCategory(cat.id)}
                className="flex items-center justify-between px-2 py-1 rounded hover:bg-[#313244]/50 cursor-pointer text-[#a6adc8] group"
              >
                <div className="flex items-center gap-1.5">
                  {isCollapsed ? (
                    <ChevronRight className="w-3 h-3 text-[#6c7086]" />
                  ) : (
                    <ChevronDown className="w-3 h-3 text-[#6c7086]" />
                  )}
                  <Icon className={`w-3.5 h-3.5 ${cat.color}`} />
                  <span className="font-semibold text-[#cdd6f4]">{cat.label}</span>
                </div>
                <span className="text-[10px] text-[#6c7086] group-hover:text-[#cdd6f4]">
                  {list.length}
                </span>
              </div>

              {/* Items in Category */}
              {!isCollapsed && (
                <div className="pl-4 space-y-0.5">
                  {list.length === 0 ? (
                    <div className="text-[11px] text-[#585b70] italic px-2 py-0.5">
                      (empty)
                    </div>
                  ) : (
                    list.map((file) => {
                      const isActive = activeFilePath === file.path;

                      return (
                        <div
                          key={file.path}
                          onClick={() => onSelectFile(file.path)}
                          className={`flex items-center justify-between px-2 py-1 rounded cursor-pointer transition-colors group ${
                            isActive
                              ? 'bg-[#89b4fa]/20 text-[#89b4fa] font-bold border-l-2 border-[#89b4fa]'
                              : 'text-[#cdd6f4] hover:bg-[#313244]/60'
                          }`}
                        >
                          <span className="truncate max-w-[140px] text-[11px]">
                            {file.name}
                          </span>

                          {/* Delete button (except for main board) */}
                          {file.path !== 'boards/board-main.org' && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                onDeleteFile(file.path);
                              }}
                              className="opacity-0 group-hover:opacity-100 p-0.5 hover:text-[#f38ba8] transition-opacity"
                              title="Delete file"
                            >
                              <Trash2 className="w-3 h-3" />
                            </button>
                          )}
                        </div>
                      );
                    })
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Directory summary footer */}
      <div className="px-3 py-1.5 bg-[#11111b] border-t border-[#313244] text-[10px] text-[#6c7086] flex items-center justify-between">
        <span>Files: {Object.keys(files).length} Org documents</span>
        <span className="text-[#a6e3a1]">File-Oriented State</span>
      </div>
    </div>
  );
};
