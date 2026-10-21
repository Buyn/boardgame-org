import React, { useState } from 'react';
import { GameObject, GameObjectType } from '../types';
import { X, Plus, Sparkles, Check } from 'lucide-react';

interface ObjectModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (obj: Partial<GameObject>, destination: 'board' | 'hand' | 'catalog') => void;
  initialType?: GameObjectType;
}

export const ObjectModal: React.FC<ObjectModalProps> = ({
  isOpen,
  onClose,
  onSave,
  initialType = 'token',
}) => {
  const [name, setName] = useState('');
  const [glyph, setGlyph] = useState('♟');
  const [type, setType] = useState<GameObjectType>(initialType);
  const [description, setDescription] = useState('');
  const [destination, setDestination] = useState<'board' | 'hand' | 'catalog'>('board');
  const [properties, setProperties] = useState<Record<string, string>>({});
  const [newPropKey, setNewPropKey] = useState('');
  const [newPropVal, setNewPropVal] = useState('');

  if (!isOpen) return null;

  const sampleGlyphs = [
    // Cards
    '🂡', '🂾', '🃍', '🃛', '🂪', '🃏', '🎴',
    // Dice
    '⚀', '⚁', '⚂', '⚃', '⚄', '⚅', '🎲',
    // Tokens & Chess
    '🪙', '💎', '🛡️', '⚔️', '🏹', '♟', '♙', '♞', '♝', '♜', '♛', '♚', '🤺', '🧙'
  ];

  const handleAddProp = () => {
    if (newPropKey.trim()) {
      setProperties((prev) => ({
        ...prev,
        [newPropKey.trim().toUpperCase()]: newPropVal.trim(),
      }));
      setNewPropKey('');
      setNewPropVal('');
    }
  };

  const handleRemoveProp = (key: string) => {
    setProperties((prev) => {
      const next = { ...prev };
      delete next[key];
      return next;
    });
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    const id = `${type}-${name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}-${Math.random().toString(36).substring(2, 6)}`;
    const filePath = `objects/${id}.org`;

    onSave(
      {
        id,
        name: name.trim(),
        glyph,
        type,
        description: description.trim(),
        properties: {
          ...properties,
          ID: id,
          NAME: name.trim(),
          TYPE: type,
          GLYPH: glyph,
        },
        filePath,
        faceUp: true,
      },
      destination
    );

    // Reset and close
    setName('');
    setDescription('');
    setProperties({});
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 z-50 font-mono text-xs">
      <div className="w-full max-w-lg bg-[#181825] border-2 border-[#89b4fa] rounded-xl shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 bg-[#11111b] border-b border-[#313244]">
          <div className="flex items-center gap-2">
            <Sparkles className="w-4 h-4 text-[#89b4fa]" />
            <span className="font-bold text-[#cdd6f4]">Mint New Org Game Object</span>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded hover:bg-[#313244] text-[#6c7086] hover:text-[#cdd6f4]"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="p-4 space-y-4 max-h-[75vh] overflow-y-auto">
          {/* Object Name & Glyph Preview */}
          <div className="flex items-start gap-3">
            <div className="flex flex-col items-center gap-1">
              <span className="text-[10px] text-[#6c7086] uppercase font-bold">Glyph</span>
              <div className="w-14 h-14 rounded-lg bg-[#1e1e2e] border-2 border-[#89b4fa] flex items-center justify-center text-3xl shadow">
                {glyph}
              </div>
            </div>

            <div className="flex-1 space-y-2">
              <div>
                <label className="block text-[11px] font-bold text-[#cdd6f4] mb-1">
                  Object Name
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Bronze Dragon Token, King of Spades"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full px-3 py-1.5 rounded bg-[#1e1e2e] border border-[#313244] text-[#cdd6f4] focus:outline-none focus:border-[#89b4fa]"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-[#cdd6f4] mb-1">
                  Type
                </label>
                <select
                  value={type}
                  onChange={(e) => setType(e.target.value as GameObjectType)}
                  className="w-full px-3 py-1.5 rounded bg-[#1e1e2e] border border-[#313244] text-[#cdd6f4] focus:outline-none focus:border-[#89b4fa]"
                >
                  <option value="card">Card</option>
                  <option value="die">Die</option>
                  <option value="token">Token</option>
                  <option value="pawn">Pawn / Piece</option>
                  <option value="tile">Tile</option>
                  <option value="container">Container (Permanent)</option>
                </select>
              </div>
            </div>
          </div>

          {/* Glyph Quick Palette */}
          <div>
            <label className="block text-[10px] text-[#6c7086] uppercase font-bold mb-1">
              Quick Glyph Presets or enter custom symbol:
            </label>
            <div className="flex flex-wrap gap-1.5 p-2 rounded bg-[#1e1e2e] border border-[#313244]">
              {sampleGlyphs.map((g) => (
                <button
                  key={g}
                  type="button"
                  onClick={() => setGlyph(g)}
                  className={`w-7 h-7 rounded flex items-center justify-center text-base hover:bg-[#313244] transition-all ${
                    glyph === g ? 'bg-[#89b4fa]/30 ring-1 ring-[#89b4fa]' : ''
                  }`}
                >
                  {g}
                </button>
              ))}
              <input
                type="text"
                maxLength={4}
                value={glyph}
                onChange={(e) => setGlyph(e.target.value)}
                className="w-12 text-center rounded bg-[#11111b] border border-[#313244] text-[#cdd6f4]"
                title="Custom character or emoji"
              />
            </div>
          </div>

          {/* Description */}
          <div>
            <label className="block text-[11px] font-bold text-[#cdd6f4] mb-1">
              Description / Lore
            </label>
            <textarea
              rows={2}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Descriptive text stored in the Org document body..."
              className="w-full px-3 py-1.5 rounded bg-[#1e1e2e] border border-[#313244] text-[#cdd6f4] focus:outline-none focus:border-[#89b4fa] resize-none"
            />
          </div>

          {/* Destination */}
          <div>
            <label className="block text-[11px] font-bold text-[#cdd6f4] mb-1">
              Materialize Location
            </label>
            <div className="grid grid-cols-3 gap-2">
              {[
                { id: 'board', label: 'Place on Felt Cursor' },
                { id: 'hand', label: 'Add to Player Hand' },
                { id: 'catalog', label: 'Save to World Only' },
              ].map((dest) => (
                <button
                  key={dest.id}
                  type="button"
                  onClick={() => setDestination(dest.id as any)}
                  className={`py-1.5 px-2 rounded border text-center transition-all ${
                    destination === dest.id
                      ? 'bg-[#89b4fa]/20 border-[#89b4fa] text-[#89b4fa] font-bold'
                      : 'bg-[#1e1e2e] border-[#313244] text-[#a6adc8] hover:bg-[#252538]'
                  }`}
                >
                  {dest.label}
                </button>
              ))}
            </div>
          </div>

          {/* Custom Org Properties Drawer Inputs */}
          <div>
            <label className="block text-[11px] font-bold text-[#cdd6f4] mb-1">
              Org Property Drawer (:PROPERTIES:)
            </label>
            <div className="space-y-1.5">
              {Object.entries(properties).map(([k, v]) => (
                <div
                  key={k}
                  className="flex items-center justify-between px-2 py-1 rounded bg-[#1e1e2e] border border-[#313244]"
                >
                  <span className="text-[#f38ba8]">:{k}:</span>
                  <span className="text-[#fab387] truncate max-w-[180px]">{v}</span>
                  <button
                    type="button"
                    onClick={() => handleRemoveProp(k)}
                    className="text-[#6c7086] hover:text-[#f38ba8]"
                  >
                    <X className="w-3 h-3" />
                  </button>
                </div>
              ))}

              <div className="flex gap-1.5 pt-1">
                <input
                  type="text"
                  placeholder="KEY (e.g. VALUE)"
                  value={newPropKey}
                  onChange={(e) => setNewPropKey(e.target.value)}
                  className="flex-1 px-2 py-1 rounded bg-[#11111b] border border-[#313244] text-[#cdd6f4] text-xs"
                />
                <input
                  type="text"
                  placeholder="VALUE"
                  value={newPropVal}
                  onChange={(e) => setNewPropVal(e.target.value)}
                  className="flex-1 px-2 py-1 rounded bg-[#11111b] border border-[#313244] text-[#cdd6f4] text-xs"
                />
                <button
                  type="button"
                  onClick={handleAddProp}
                  className="px-2.5 py-1 rounded bg-[#313244] hover:bg-[#45475a] text-[#a6e3a1]"
                >
                  <Plus className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          </div>

          {/* Submit */}
          <div className="pt-2 border-t border-[#313244] flex items-center justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-3 py-1.5 rounded bg-[#313244] hover:bg-[#45475a] text-[#cdd6f4]"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-1.5 rounded bg-[#89b4fa] hover:bg-[#b4befe] text-[#11111b] font-bold shadow-md transition-colors"
            >
              Mint Object & Org File
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
