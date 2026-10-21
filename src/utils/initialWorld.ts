import { GameObject, BoardState, PlayerHand, WorldFile, GitCommit } from '../types';
import {
  serializeBoardToOrg,
  serializeObjectToOrg,
  serializeHandToOrg,
  normalizeFeltGrid,
} from './orgParser';

export function createInitialWorld(): {
  board: BoardState;
  objects: Record<string, GameObject>;
  hands: PlayerHand[];
  files: Record<string, WorldFile>;
  gitHistory: GitCommit[];
} {
  const objects: Record<string, GameObject> = {
    'card-ace-spades': {
      id: 'card-ace-spades',
      name: 'Ace of Spades',
      glyph: '🂡',
      type: 'card',
      description: 'The supreme card of the spade suit. Valued at 14 points.',
      properties: {
        ID: 'card-ace-spades',
        NAME: 'Ace of Spades',
        TYPE: 'card',
        GLYPH: '🂡',
        SUIT: 'spades',
        VALUE: '14',
        COLOR: 'black',
        FACE_UP: 't',
      },
      filePath: 'objects/card-ace-spades.org',
      faceUp: true,
      color: 'black',
      value: 14,
    },
    'card-king-hearts': {
      id: 'card-king-hearts',
      name: 'King of Hearts',
      glyph: '🂾',
      type: 'card',
      description: 'The noble King of Hearts, ruler of hearts.',
      properties: {
        ID: 'card-king-hearts',
        NAME: 'King of Hearts',
        TYPE: 'card',
        GLYPH: '🂾',
        SUIT: 'hearts',
        VALUE: '13',
        COLOR: 'red',
        FACE_UP: 't',
      },
      filePath: 'objects/card-king-hearts.org',
      faceUp: true,
      color: 'red',
      value: 13,
    },
    'card-queen-diamonds': {
      id: 'card-queen-diamonds',
      name: 'Queen of Diamonds',
      glyph: '🃍',
      type: 'card',
      description: 'The shimmering Queen of Diamonds.',
      properties: {
        ID: 'card-queen-diamonds',
        NAME: 'Queen of Diamonds',
        TYPE: 'card',
        GLYPH: '🃍',
        SUIT: 'diamonds',
        VALUE: '12',
        COLOR: 'red',
        FACE_UP: 't',
      },
      filePath: 'objects/card-queen-diamonds.org',
      faceUp: true,
      color: 'red',
      value: 12,
    },
    'card-jack-clubs': {
      id: 'card-jack-clubs',
      name: 'Jack of Clubs',
      glyph: '🃛',
      type: 'card',
      description: 'The cunning Jack of Clubs.',
      properties: {
        ID: 'card-jack-clubs',
        NAME: 'Jack of Clubs',
        TYPE: 'card',
        GLYPH: '🃛',
        SUIT: 'clubs',
        VALUE: '11',
        COLOR: 'black',
        FACE_UP: 't',
      },
      filePath: 'objects/card-jack-clubs.org',
      faceUp: true,
      color: 'black',
      value: 11,
    },
    'card-10-spades': {
      id: 'card-10-spades',
      name: '10 of Spades',
      glyph: '🂪',
      type: 'card',
      description: 'Numerical card in the suit of spades.',
      properties: {
        ID: 'card-10-spades',
        NAME: '10 of Spades',
        TYPE: 'card',
        GLYPH: '🂪',
        SUIT: 'spades',
        VALUE: '10',
        COLOR: 'black',
        FACE_UP: 't',
      },
      filePath: 'objects/card-10-spades.org',
      faceUp: true,
      color: 'black',
      value: 10,
    },
    'die-d6-red': {
      id: 'die-d6-red',
      name: 'Red Six-Sided Die',
      glyph: '⚂',
      type: 'die',
      description: 'A standard cubic 6-sided die. Currently showing 3.',
      properties: {
        ID: 'die-d6-red',
        NAME: 'Red Six-Sided Die',
        TYPE: 'die',
        GLYPH: '⚂',
        SIDES: '6',
        VALUE: '3',
        COLOR: '#ef4444',
      },
      filePath: 'objects/die-d6-red.org',
      diceSides: 6,
      value: 3,
      color: '#ef4444',
    },
    'die-d20-blue': {
      id: 'die-d20-blue',
      name: 'Blue D20 Die',
      glyph: '🎲',
      type: 'die',
      description: 'A 20-sided polyhedral gaming die. Rolled: 17.',
      properties: {
        ID: 'die-d20-blue',
        NAME: 'Blue D20 Die',
        TYPE: 'die',
        GLYPH: '🎲',
        SIDES: '20',
        VALUE: '17',
        COLOR: '#3b82f6',
      },
      filePath: 'objects/die-d20-blue.org',
      diceSides: 20,
      value: 17,
      color: '#3b82f6',
    },
    'token-gold-coin': {
      id: 'token-gold-coin',
      name: 'Gold Coin',
      glyph: '🪙',
      type: 'token',
      description: 'A minted gold coin with the seal of the realm.',
      properties: {
        ID: 'token-gold-coin',
        NAME: 'Gold Coin',
        TYPE: 'token',
        GLYPH: '🪙',
        VALUE: '100',
        COLOR: '#eab308',
      },
      filePath: 'objects/token-gold-coin.org',
      value: 100,
      color: '#eab308',
    },
    'token-mana-crystal': {
      id: 'token-mana-crystal',
      name: 'Mana Crystal',
      glyph: '💎',
      type: 'token',
      description: 'Glows with concentrated arcane energy.',
      properties: {
        ID: 'token-mana-crystal',
        NAME: 'Mana Crystal',
        TYPE: 'token',
        GLYPH: '💎',
        POWER: 'high',
        COLOR: '#06b6d4',
      },
      filePath: 'objects/token-mana-crystal.org',
      color: '#06b6d4',
    },
    'pawn-white': {
      id: 'pawn-white',
      name: 'White Pawn',
      glyph: '♙',
      type: 'pawn',
      description: 'Classic wooden chess pawn piece.',
      properties: {
        ID: 'pawn-white',
        NAME: 'White Pawn',
        TYPE: 'pawn',
        GLYPH: '♙',
        COLOR: 'white',
      },
      filePath: 'objects/pawn-white.org',
    },
    'knight-black': {
      id: 'knight-black',
      name: 'Black Knight',
      glyph: '♞',
      type: 'pawn',
      description: 'Obsidian carved knight chess piece.',
      properties: {
        ID: 'knight-black',
        NAME: 'Black Knight',
        TYPE: 'pawn',
        GLYPH: '♞',
        COLOR: 'black',
      },
      filePath: 'objects/knight-black.org',
    },
    // Permanent Container: Deck
    'deck-main': {
      id: 'deck-main',
      name: 'Tavern Playing Deck',
      glyph: '🎴',
      type: 'container',
      description: 'A permanent container holding cards. Supports draw and shuffle without merging object documents.',
      properties: {
        ID: 'deck-main',
        NAME: 'Tavern Playing Deck',
        TYPE: 'container',
        GLYPH: '🎴',
        IS_CONTAINER: 't',
        ITEM_COUNT: '2',
      },
      filePath: 'containers/deck-main.org',
      isContainer: true,
      containedObjectIds: ['card-king-hearts', 'card-10-spades'],
    },
    // Consolidated Stack
    'stack-table-discard': {
      id: 'stack-table-discard',
      name: 'Discard Stack',
      glyph: '🂠',
      type: 'stack',
      description: 'Consolidated Org document containing multiple objects merged together. Standalone files have been incorporated into this document.',
      properties: {
        ID: 'stack-table-discard',
        NAME: 'Discard Stack',
        TYPE: 'stack',
        GLYPH: '🂠',
        IS_STACK: 't',
        STACK_SIZE: '2',
      },
      filePath: 'stacks/stack-table-discard.org',
      isStack: true,
      stackedObjects: [
        {
          id: 'card-ace-spades',
          name: 'Ace of Spades',
          glyph: '🂡',
          type: 'card',
          properties: { VALUE: '14', SUIT: 'spades' },
        },
        {
          id: 'card-queen-diamonds',
          name: 'Queen of Diamonds',
          glyph: '🃍',
          type: 'card',
          properties: { VALUE: '12', SUIT: 'diamonds' },
        },
      ],
    },
  };

  // Build Board Felt
  const width = 16;
  const height = 10;
  const defaultFelt = '.';
  const feltGrid = normalizeFeltGrid(
    Array(height).fill('.'.repeat(width)).join('\n'),
    width,
    height,
    defaultFelt
  );

  const board: BoardState = {
    id: 'board-main',
    name: 'Tavern Felt Table',
    width,
    height,
    defaultFelt,
    feltGrid,
    filePath: 'boards/board-main.org',
    placedObjects: [
      { id: 'deck-main', x: 2, y: 2, layer: 0 },
      { id: 'stack-table-discard', x: 5, y: 2, layer: 0 },
      { id: 'die-d6-red', x: 8, y: 4, layer: 0 },
      { id: 'die-d20-blue', x: 9, y: 4, layer: 0 },
      { id: 'token-gold-coin', x: 12, y: 6, layer: 0 },
      { id: 'token-mana-crystal', x: 13, y: 6, layer: 0 },
      { id: 'pawn-white', x: 4, y: 7, layer: 0 },
      { id: 'knight-black', x: 5, y: 7, layer: 0 },
    ],
  };

  const hands: PlayerHand[] = [
    {
      id: 'hand-player1',
      name: 'Player 1 Hand',
      player: 'Player 1',
      objectIds: ['card-jack-clubs'],
      filePath: 'hands/hand-player1.org',
    },
  ];

  // Generate World Files
  const files: Record<string, WorldFile> = {};

  // Board file
  const boardContent = serializeBoardToOrg(board, objects);
  files[board.filePath] = {
    path: board.filePath,
    name: 'board-main.org',
    type: 'board',
    content: boardContent,
    updatedAt: new Date().toISOString(),
  };

  // Hand file
  for (const hand of hands) {
    const handContent = serializeHandToOrg(hand, objects);
    files[hand.filePath] = {
      path: hand.filePath,
      name: `${hand.id}.org`,
      type: 'hand',
      content: handContent,
      updatedAt: new Date().toISOString(),
    };
  }

  // Object files
  for (const obj of Object.values(objects)) {
    const content = serializeObjectToOrg(obj);
    files[obj.filePath] = {
      path: obj.filePath,
      name: `${obj.id}.org`,
      type: obj.isContainer ? 'container' : obj.isStack ? 'stack' : 'object',
      content,
      updatedAt: new Date().toISOString(),
    };
  }

  // System Documentation files
  files['docs/readme.org'] = {
    path: 'docs/readme.org',
    name: 'readme.org',
    type: 'doc',
    content: `* boardgame.org — Текстовая настольная среда в Emacs и Org-mode
:PROPERTIES:
:AUTHOR: Buyn <buyn.tex@gmail.com>
:LANGUAGE: ru
:END:

** Архитектурные принципы
1. *Объект — это файл*: независимый объект имеет свой Org-документ.
2. *Стопки*: консолидация Org-документов в один; автономные файлы удаляются.
3. *Контейнеры*: организация ссылками без удаления автономных файлов.
4. *Нормализация сукна*: авто-дополнение отсутствующих клеток символом сукна.
5. *Многообъектность*: числовые индикаторы 1-9 и + слева от глифа.
6. *Git-версионирование*: надежная история и откат к снимкам мира.

** Клавиши Emacs (буфер *boardgame-org*)
- Стрелки / h,j,k,l: перемещение курсора
- <f6> или Space: меню Hydra
- H: взять верхний объект в руку
- P: сыграть из руки на сукно
- S: объединить в стопку (удаляет отдельные файлы)
- U: разобрать стопку (воссоздает отдельные файлы)
- d: взять карту из колоды в руку
- s: перемешать колоду
- r: бросить кость
- F: перевернуть карту
- o: открыть Org-файл объекта
`,
    updatedAt: new Date().toISOString(),
  };

  files['docs/boardgame-architecture.org'] = {
    path: 'docs/boardgame-architecture.org',
    name: 'boardgame-architecture.org',
    type: 'doc',
    content: `* boardgame.org — Architecture Overview
:PROPERTIES:
:AUTHOR: Buyn
:SYSTEM: Emacs / Org-mode Tabletop
:END:

** Invariant
An independently existing object has its own Org file. When that object ceases to exist as an independent object because it has been incorporated into another representation (like a Stack), its former standalone file must be removed.

** Stacks vs Containers
- [[file:stacks/stack-table-discard.org][Stack]]: Consolidates multiple Org documents into one single document.
- [[file:containers/deck-main.org][Container]]: Organizes independent objects while preserving their independent files.
`,
    updatedAt: new Date().toISOString(),
  };

  const initialCommit: GitCommit = {
    id: 'git-c0ffee1',
    timestamp: new Date().toISOString(),
    message: 'Initial world commit: Felt board, tavern deck, dice, tokens and player hand',
    author: 'buyn <buyn.tex@gmail.com>',
    snapshot: {
      files: Object.fromEntries(Object.entries(files).map(([k, v]) => [k, v.content])),
      board: JSON.parse(JSON.stringify(board)),
      objects: JSON.parse(JSON.stringify(objects)),
      hands: JSON.parse(JSON.stringify(hands)),
    },
  };

  return {
    board,
    objects,
    hands,
    files,
    gitHistory: [initialCommit],
  };
}
