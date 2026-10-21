import React, { useState, useEffect } from 'react';
import { WorldFile } from '../types';
import { Save, Code, Eye, RefreshCw, FileText, CheckCircle2, AlertCircle } from 'lucide-react';

interface OrgEditorProps {
  currentFile: WorldFile | null;
  onSaveContent: (path: string, newContent: string) => void;
  onNavigateToFile: (path: string) => void;
}

export const OrgEditor: React.FC<OrgEditorProps> = ({
  currentFile,
  onSaveContent,
  onNavigateToFile,
}) => {
  const [content, setContent] = useState<string>('');
  const [isRawMode, setIsRawMode] = useState<boolean>(false);
  const [isDirty, setIsDirty] = useState<boolean>(false);
  const [saveStatus, setSaveStatus] = useState<string | null>(null);

  useEffect(() => {
    if (currentFile) {
      setContent(currentFile.content);
      setIsDirty(false);
      setSaveStatus(null);
    }
  }, [currentFile?.path, currentFile?.updatedAt]);

  const handleChange = (newVal: string) => {
    setContent(newVal);
    setIsDirty(true);
    setSaveStatus(null);
  };

  const handleSave = () => {
    if (!currentFile) return;
    try {
      onSaveContent(currentFile.path, content);
      setIsDirty(false);
      setSaveStatus('Saved & Synced');
      setTimeout(() => setSaveStatus(null), 2500);
    } catch (err: any) {
      setSaveStatus(`Error: ${err.message}`);
    }
  };

  // Keyboard shortcut for saving (Ctrl+S / C-x C-s)
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
      e.preventDefault();
      handleSave();
    }
  };

  if (!currentFile) {
    return (
      <div className="flex flex-col items-center justify-center h-full bg-[#1e1e2e] text-[#6c7086] p-6 text-center">
        <FileText className="w-12 h-12 mb-3 text-[#45475a]" />
        <p className="font-semibold text-sm text-[#cdd6f4]">No Org Buffer Selected</p>
        <p className="text-xs max-w-xs mt-1">
          Select an object on the tabletop or choose an Org file from the world file tree.
        </p>
      </div>
    );
  }

  // Syntax highlight Org lines for the rich view
  const renderHighlightedLine = (line: string, index: number) => {
    // Top-level Heading
    if (line.startsWith('* ')) {
      return (
        <div key={index} className="font-bold text-[#89b4fa] text-base py-0.5">
          {line}
        </div>
      );
    }
    // Level 2 Heading
    if (line.startsWith('** ')) {
      return (
        <div key={index} className="font-semibold text-[#a6e3a1] text-sm py-0.5 pl-2">
          {line}
        </div>
      );
    }
    // Level 3 Heading
    if (line.startsWith('*** ')) {
      return (
        <div key={index} className="font-medium text-[#f9e2af] text-xs py-0.5 pl-4">
          {line}
        </div>
      );
    }
    // Property drawer delimiter
    if (line.trim() === ':PROPERTIES:' || line.trim() === ':END:') {
      return (
        <div key={index} className="text-[#9399b2] font-semibold text-xs py-0.5">
          {line}
        </div>
      );
    }
    // Property key-value
    if (line.trim().startsWith(':') && line.includes(': ')) {
      const parts = line.split(': ');
      return (
        <div key={index} className="text-xs pl-3 py-0.5">
          <span className="text-[#f38ba8] font-medium">{parts[0]}: </span>
          <span className="text-[#fab387]">{parts.slice(1).join(': ')}</span>
        </div>
      );
    }
    // Source block begin / end
    if (line.startsWith('#+begin_src') || line.startsWith('#+end_src')) {
      return (
        <div key={index} className="text-[#cba6f7] font-semibold text-xs bg-[#11111b] px-2 py-0.5 rounded">
          {line}
        </div>
      );
    }
    // Table rows
    if (line.trim().startsWith('|')) {
      return (
        <div key={index} className="text-xs text-[#a6adc8] font-mono whitespace-pre bg-[#181825]/60 px-1">
          {line}
        </div>
      );
    }
    // Links [[target][description]]
    const linkMatch = line.match(/\[\[(?:file:)?([^\]]+)\]\[([^\]]*)\]\]/);
    if (linkMatch) {
      const target = linkMatch[1];
      const label = linkMatch[2] || target;
      return (
        <div key={index} className="text-xs text-[#cdd6f4] py-0.5 pl-2">
          - Link:{' '}
          <button
            onClick={() => onNavigateToFile(target.startsWith('objects/') || target.startsWith('boards/') || target.startsWith('stacks/') || target.startsWith('containers/') || target.startsWith('hands/') ? target : `objects/${target}.org`)}
            className="text-[#89dceb] underline underline-offset-2 hover:text-[#b4befe] font-semibold transition-colors"
          >
            {label} ↗
          </button>
        </div>
      );
    }

    return (
      <div key={index} className="text-xs text-[#cdd6f4] py-0.5 whitespace-pre-wrap">
        {line || '\u00A0'}
      </div>
    );
  };

  const lineCount = content.split('\n').length;

  return (
    <div className="flex flex-col h-full bg-[#181825] font-mono text-xs select-text overflow-hidden">
      {/* Editor Buffer Toolbar */}
      <div className="flex items-center justify-between px-3 py-2 bg-[#11111b] border-b border-[#313244]">
        <div className="flex items-center gap-2 overflow-hidden">
          <span className="w-2 h-2 rounded-full bg-[#a6e3a1]"></span>
          <span className="font-semibold text-[#cdd6f4] truncate">
            {currentFile.name}
          </span>
          <span className="text-[#6c7086] text-[10px] hidden sm:inline">
            ({currentFile.path})
          </span>
          {isDirty && (
            <span className="px-1.5 py-0.5 text-[10px] bg-[#fab387]/20 text-[#fab387] rounded font-bold">
              MODIFIED *
            </span>
          )}
        </div>

        <div className="flex items-center gap-2">
          {saveStatus && (
            <span className="text-[11px] text-[#a6e3a1] flex items-center gap-1 font-semibold animate-pulse">
              <CheckCircle2 className="w-3 h-3" />
              {saveStatus}
            </span>
          )}

          <button
            onClick={() => setIsRawMode(!isRawMode)}
            className={`flex items-center gap-1 px-2 py-1 rounded transition-colors ${
              isRawMode
                ? 'bg-[#89b4fa] text-[#11111b] font-bold'
                : 'bg-[#313244] text-[#cdd6f4] hover:bg-[#45475a]'
            }`}
            title="Toggle between Syntax Highlighting and Direct Text Editing"
          >
            {isRawMode ? <Eye className="w-3 h-3" /> : <Code className="w-3 h-3" />}
            <span>{isRawMode ? 'Formatted' : 'Raw Text'}</span>
          </button>

          <button
            onClick={handleSave}
            disabled={!isDirty}
            className={`flex items-center gap-1 px-2.5 py-1 rounded font-bold transition-all ${
              isDirty
                ? 'bg-[#a6e3a1] text-[#11111b] hover:bg-[#94e2d5] shadow-sm'
                : 'bg-[#313244] text-[#6c7086] cursor-not-allowed'
            }`}
            title="Save buffer and sync in-memory tabletop [Ctrl+S]"
          >
            <Save className="w-3 h-3" />
            <span>Save [C-x C-s]</span>
          </button>
        </div>
      </div>

      {/* Buffer View Area */}
      <div className="flex-1 overflow-auto bg-[#1e1e2e] relative">
        {isRawMode ? (
          <div className="flex min-h-full">
            {/* Gutter / Line numbers */}
            <div className="w-10 py-3 bg-[#181825] border-r border-[#313244] text-[#585b70] text-right pr-2 select-none font-mono text-xs">
              {Array.from({ length: lineCount }).map((_, i) => (
                <div key={i} className="leading-5">
                  {i + 1}
                </div>
              ))}
            </div>

            {/* Editable Textarea */}
            <textarea
              value={content}
              onChange={(e) => handleChange(e.target.value)}
              onKeyDown={handleKeyDown}
              className="flex-1 p-3 bg-transparent text-[#cdd6f4] font-mono text-xs leading-5 focus:outline-none resize-none whitespace-pre overflow-x-auto"
              spellCheck={false}
              placeholder="Edit Org document contents here..."
            />
          </div>
        ) : (
          <div className="p-4 space-y-0.5">
            {content.split('\n').map((line, idx) => renderHighlightedLine(line, idx))}
          </div>
        )}
      </div>

      {/* Emacs Authentic Modeline */}
      <div className="px-3 py-1 bg-[#181825] border-t border-[#313244] flex items-center justify-between text-[11px] text-[#9399b2] select-none font-mono">
        <div className="flex items-center gap-2">
          <span className="font-bold text-[#89b4fa]">-U:---</span>
          <span className="text-[#cdd6f4] font-semibold">{currentFile.name}</span>
          <span>(Org {isRawMode ? 'Edit' : 'View'})</span>
          <span>[UTF-8]</span>
        </div>
        <div className="flex items-center gap-3">
          <span>{lineCount} lines</span>
          <span>All</span>
          <span className="text-[#a6e3a1]">Round-trip Sync Ready</span>
        </div>
      </div>
    </div>
  );
};
