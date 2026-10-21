export type GameObjectType = 'card' | 'die' | 'token' | 'pawn' | 'tile' | 'container' | 'stack';

export interface GameObject {
  id: string;
  name: string;
  glyph: string;
  type: GameObjectType;
  description?: string;
  properties: Record<string, string>;
  filePath: string;
  // Specific properties
  faceUp?: boolean;
  color?: string;
  value?: number | string;
  diceSides?: number;
  // For containers
  isContainer?: boolean;
  containedObjectIds?: string[]; // IDs of independent objects
  // For stacks
  isStack?: boolean;
  stackedObjects?: Array<{
    id: string;
    name: string;
    glyph: string;
    type: GameObjectType;
    properties: Record<string, string>;
  }>;
}

export interface PlacedObjectRef {
  id: string; // references object in world
  x: number;
  y: number;
  layer: number;
}

export interface BoardState {
  id: string;
  name: string;
  width: number;
  height: number;
  defaultFelt: string;
  feltGrid: string[][]; // 2D array of chars representing felt background
  placedObjects: PlacedObjectRef[];
  filePath: string;
}

export interface PlayerHand {
  id: string;
  name: string;
  player: string;
  objectIds: string[];
  filePath: string;
}

export interface WorldFile {
  path: string;
  name: string;
  type: 'board' | 'object' | 'stack' | 'container' | 'hand' | 'doc';
  content: string;
  updatedAt: string;
}

export interface GitCommit {
  id: string;
  timestamp: string;
  message: string;
  author: string;
  snapshot: {
    files: Record<string, string>;
    board: BoardState;
    objects: Record<string, GameObject>;
    hands: PlayerHand[];
  };
}

export type ViewMode = 'split' | 'tabletop-only' | 'org-only';
