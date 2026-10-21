import React, { useState } from 'react';
import { GitCommit } from '../types';
import { GitBranch, GitCommit as GitCommitIcon, Clock, RotateCcw, X, Check, FileText } from 'lucide-react';

interface GitHistoryModalProps {
  isOpen: boolean;
  onClose: () => void;
  commits: GitCommit[];
  onRollback: (commit: GitCommit) => void;
}

export const GitHistoryModal: React.FC<GitHistoryModalProps> = ({
  isOpen,
  onClose,
  commits,
  onRollback,
}) => {
  const [selectedCommitId, setSelectedCommitId] = useState<string>(commits[0]?.id || '');

  if (!isOpen) return null;

  const selectedCommit = commits.find((c) => c.id === selectedCommitId) || commits[0];

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 z-50 font-mono text-xs">
      <div className="w-full max-w-3xl bg-[#181825] border-2 border-[#b4befe] rounded-xl shadow-2xl overflow-hidden flex flex-col max-h-[85vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 bg-[#11111b] border-b border-[#313244]">
          <div className="flex items-center gap-2">
            <GitBranch className="w-4 h-4 text-[#b4befe]" />
            <span className="font-bold text-[#cdd6f4]">World Git Repository History</span>
            <span className="px-1.5 py-0.5 rounded bg-[#313244] text-[#b4befe] text-[10px]">
              {commits.length} commits
            </span>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded hover:bg-[#313244] text-[#6c7086] hover:text-[#cdd6f4]"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Content Split: Commit List on Left, Snapshot Details on Right */}
        <div className="flex-1 flex flex-col md:flex-row overflow-hidden">
          {/* Commit List */}
          <div className="w-full md:w-1/2 border-r border-[#313244] overflow-y-auto p-3 space-y-2">
            <div className="text-[11px] font-bold text-[#a6adc8] mb-2 px-1">
              COMMITS TIMELINE
            </div>
            {commits.map((commit, idx) => {
              const isSelected = commit.id === selectedCommitId;
              return (
                <div
                  key={commit.id}
                  onClick={() => setSelectedCommitId(commit.id)}
                  className={`p-2.5 rounded-lg border cursor-pointer transition-all ${
                    isSelected
                      ? 'bg-[#313244] border-[#89b4fa] shadow-md'
                      : 'bg-[#1e1e2e] border-[#313244] hover:bg-[#252538]'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-[#89b4fa] text-[11px] flex items-center gap-1">
                      <GitCommitIcon className="w-3.5 h-3.5" />
                      {commit.id.substring(0, 10)}
                    </span>
                    <span className="text-[10px] text-[#6c7086] flex items-center gap-1">
                      <Clock className="w-3 h-3" />
                      {new Date(commit.timestamp).toLocaleTimeString()}
                    </span>
                  </div>

                  <p className="font-semibold text-[#cdd6f4] mt-1 text-xs line-clamp-2">
                    {commit.message}
                  </p>

                  <div className="flex items-center justify-between mt-2 text-[10px] text-[#9399b2]">
                    <span>{commit.author}</span>
                    <span className="text-[#a6e3a1]">
                      {Object.keys(commit.snapshot.files).length} files
                    </span>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Commit Details / Snapshot */}
          <div className="w-full md:w-1/2 p-4 flex flex-col bg-[#11111b] overflow-y-auto">
            {selectedCommit ? (
              <div className="space-y-4">
                <div>
                  <span className="text-[10px] font-bold text-[#6c7086] uppercase">
                    Commit Hash
                  </span>
                  <div className="font-bold text-[#89b4fa] text-sm">
                    {selectedCommit.id}
                  </div>
                </div>

                <div>
                  <span className="text-[10px] font-bold text-[#6c7086] uppercase">
                    Commit Message
                  </span>
                  <div className="font-medium text-[#cdd6f4] text-xs bg-[#1e1e2e] p-2.5 rounded border border-[#313244]">
                    {selectedCommit.message}
                  </div>
                </div>

                <div>
                  <span className="text-[10px] font-bold text-[#6c7086] uppercase">
                    World Snapshot Contents
                  </span>
                  <div className="mt-1 space-y-1 max-h-48 overflow-y-auto">
                    {Object.keys(selectedCommit.snapshot.files).map((f) => (
                      <div
                        key={f}
                        className="flex items-center gap-2 text-[11px] text-[#cdd6f4] py-0.5"
                      >
                        <FileText className="w-3 h-3 text-[#a6e3a1]" />
                        <span>{f}</span>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="pt-2 border-t border-[#313244]">
                  <button
                    onClick={() => {
                      onRollback(selectedCommit);
                      onClose();
                    }}
                    className="w-full flex items-center justify-center gap-2 py-2 px-3 rounded-lg bg-[#fab387] hover:bg-[#f9e2af] text-[#11111b] font-bold transition-colors shadow-lg"
                  >
                    <RotateCcw className="w-4 h-4" />
                    <span>Rollback / Restore World to This Commit</span>
                  </button>
                  <p className="text-[10px] text-[#6c7086] text-center mt-2">
                    Restores all Org files, board state, and hand items to this point in time.
                  </p>
                </div>
              </div>
            ) : (
              <div className="text-[#6c7086] text-center my-auto">
                No commit selected.
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
