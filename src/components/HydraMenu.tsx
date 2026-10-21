import React, { useEffect } from 'react';
import { X, Sparkles, Terminal } from 'lucide-react';

interface HydraMenuProps {
  isOpen: boolean;
  onClose: () => void;
  onAction: (actionKey: string) => void;
}

export const HydraMenu: React.FC<HydraMenuProps> = ({ isOpen, onClose, onAction }) => {
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      // Escape or q closes Hydra
      if (e.key === 'Escape' || e.key === 'q' || e.key === 'Q') {
        e.preventDefault();
        onClose();
        return;
      }

      const key = e.key;
      // Handle hotkeys
      const validKeys = [
        'P', 'N', 's', 'p', 'n', 'o', 'L', 'l', 'm', 'k', 'u', 'd', 'r', 'f', 'g', 'D', 'c'
      ];
      if (validKeys.includes(key)) {
        e.preventDefault();
        onAction(key);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose, onAction]);

  if (!isOpen) return null;

  const hydraGroups = [
    {
      title: 'Emacs Org & Zetstack Commands',
      items: [
        { key: 'N', label: 'create-next', desc: 'Mint new Org object after target', color: 'text-[#89b4fa]' },
        { key: 'P', label: 'create-prev', desc: 'Mint new Org object before target', color: 'text-[#89b4fa]' },
        { key: 'n', label: 'goto-next', desc: 'Follow forward pointer in stack', color: 'text-[#f38ba8]' },
        { key: 'p', label: 'goto-prev', desc: 'Follow backward pointer in stack', color: 'text-[#f38ba8]' },
        { key: 's', label: 'rename & save', desc: 'Atomic rename with ID sync', color: 'text-[#f38ba8]' },
        { key: 'o', label: 'open-by-name', desc: 'Fuzzy pick Org object file', color: 'text-[#a6e3a1]' },
        { key: 'L', label: 'add-link', desc: 'Insert bidirectional Org link', color: 'text-[#f9e2af]' },
        { key: 'l', label: 'stub-link', desc: 'Insert zlink stub node', color: 'text-[#f9e2af]' },
      ],
    },
    {
      title: 'Tabletop Felt & Persistence Actions',
      items: [
        { key: 'k', label: 'consolidate-stack', desc: 'Merge cell objects into single Org stack document', color: 'text-[#fab387]' },
        { key: 'u', label: 'expand-stack', desc: 'Disintegrate stack into standalone Org files', color: 'text-[#fab387]' },
        { key: 'd', label: 'draw-container', desc: 'Draw from deck/container to hand', color: 'text-[#89dceb]' },
        { key: 'r', label: 'roll-dice', desc: 'Roll die at cursor', color: 'text-[#a6e3a1]' },
        { key: 'f', label: 'flip-card', desc: 'Toggle face-up / face-down', color: 'text-[#cba6f7]' },
        { key: 'g', label: 'git-history', desc: 'Inspect world repository commits & rollback', color: 'text-[#b4befe]' },
        { key: 'D', label: 'remove-file', desc: 'Delete current object Org file', color: 'text-[#f38ba8]' },
      ],
    },
  ];

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-end sm:items-center justify-center p-4 z-50 animate-in fade-in duration-150">
      <div className="w-full max-w-2xl bg-[#181825] border-2 border-[#89b4fa] rounded-xl shadow-2xl overflow-hidden font-mono text-xs">
        {/* Hydra Header */}
        <div className="flex items-center justify-between px-4 py-2.5 bg-[#11111b] border-b border-[#313244]">
          <div className="flex items-center gap-2">
            <Terminal className="w-4 h-4 text-[#89b4fa]" />
            <span className="font-bold text-[#cdd6f4]">hydra-boardgame-org-menu</span>
            <span className="px-1.5 py-0.5 rounded bg-[#313244] text-[#89b4fa] text-[10px]">
              Press Key or Click
            </span>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded hover:bg-[#313244] text-[#6c7086] hover:text-[#cdd6f4]"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Hydra Command Groups */}
        <div className="p-4 space-y-4 max-h-[70vh] overflow-y-auto">
          {hydraGroups.map((group, gIdx) => (
            <div key={gIdx} className="space-y-2">
              <div className="text-[11px] font-bold text-[#a6adc8] uppercase tracking-wider flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 rounded-full bg-[#89b4fa]"></span>
                {group.title}
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {group.items.map((item) => (
                  <button
                    key={item.key}
                    onClick={() => {
                      onAction(item.key);
                    }}
                    className="flex items-start gap-2.5 p-2 rounded-lg bg-[#1e1e2e] hover:bg-[#313244] border border-[#313244] text-left transition-all group"
                  >
                    <span className="px-2 py-0.5 rounded bg-[#11111b] font-bold text-sm text-[#89b4fa] group-hover:text-[#a6e3a1] ring-1 ring-[#45475a]">
                      {item.key}
                    </span>
                    <div className="flex-1 min-w-0">
                      <div className={`font-semibold ${item.color}`}>
                        {item.label}
                      </div>
                      <div className="text-[10px] text-[#6c7086] truncate">
                        {item.desc}
                      </div>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* Hydra Footer */}
        <div className="px-4 py-2 bg-[#11111b] border-t border-[#313244] flex items-center justify-between text-[#6c7086] text-[11px]">
          <span>Press [q] or [Esc] to quit Hydra</span>
          <span className="text-[#a6e3a1]">Normative Architectural Model</span>
        </div>
      </div>
    </div>
  );
};
