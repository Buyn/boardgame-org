import { GameObject, BoardState, PlayerHand, GameObjectType, PlacedObjectRef } from '../types';

/**
 * Extracts property drawer key-values from Org content
 */
export function parseOrgProperties(content: string): Record<string, string> {
  const props: Record<string, string> = {};
  const propMatch = content.match(/:PROPERTIES:([\s\S]*?):END:/i);
  if (propMatch && propMatch[1]) {
    const lines = propMatch[1].split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      const match = trimmed.match(/^:([A-Za-z0-9_-]+):\s*(.*)$/);
      if (match) {
        props[match[1].toUpperCase()] = match[2].trim();
      }
    }
  }
  return props;
}

/**
 * Parses an Org document representing an object
 */
export function parseObjectOrg(content: string, filePath: string): GameObject {
  const props = parseOrgProperties(content);
  
  // Extract heading name
  const headingMatch = content.match(/^\*\s+(.+)$/m);
  const name = props['NAME'] || (headingMatch ? headingMatch[1].trim() : 'Unnamed Object');
  const id = props['ID'] || filePath.replace(/[^a-zA-Z0-9_-]/g, '-');
  const glyph = props['GLYPH'] || '♟';
  const type = (props['TYPE']?.toLowerCase() || 'token') as GameObjectType;
  const isContainer = props['TYPE']?.toLowerCase() === 'container' || !!props['IS_CONTAINER'];
  const isStack = props['TYPE']?.toLowerCase() === 'stack' || !!props['IS_STACK'];

  // Extract description
  let description = '';
  const bodyMatch = content.split(/^\*\s+.+$/m)[1];
  if (bodyMatch) {
    description = bodyMatch.trim();
  }

  // Parse contained or stacked items if applicable
  let containedObjectIds: string[] = [];
  if (isContainer) {
    const linkMatches = content.matchAll(/\[\[(?:file:)?([^\]]+)\]\[([^\]]*)\]\]/g);
    for (const m of linkMatches) {
      const refPath = m[1];
      const refId = refPath.replace(/\.org$/, '').split('/').pop() || refPath;
      containedObjectIds.push(refId);
    }
    // Also support fallback list
    if (containedObjectIds.length === 0 && props['CONTAINED_IDS']) {
      containedObjectIds = props['CONTAINED_IDS'].split(',').map(s => s.trim()).filter(Boolean);
    }
  }

  const stackedObjects: Array<{
    id: string;
    name: string;
    glyph: string;
    type: GameObjectType;
    properties: Record<string, string>;
  }> = [];

  if (isStack) {
    const subheadings = content.matchAll(/^\*\*\s+(.+)$([\s\S]*?)(?=^\*\*|\s*$)/gm);
    for (const sub of subheadings) {
      const itemTitle = sub[1].trim();
      const itemBody = sub[2];
      const itemProps = parseOrgProperties(itemBody);
      const glyph = itemProps['GLYPH'] || itemTitle.match(/^(\S+)/)?.[1] || '🂠';
      stackedObjects.push({
        id: itemProps['ORIGINAL_ID'] || itemProps['ID'] || `sub-${Math.random().toString(36).substring(2, 7)}`,
        name: itemProps['NAME'] || itemTitle,
        glyph,
        type: (itemProps['TYPE']?.toLowerCase() || 'card') as GameObjectType,
        properties: itemProps,
      });
    }
  }

  return {
    id,
    name,
    glyph,
    type,
    description,
    properties: props,
    filePath,
    faceUp: props['FACE_UP'] === 't' || props['FACE_UP'] === 'true',
    color: props['COLOR'],
    value: props['VALUE'],
    diceSides: props['SIDES'] ? parseInt(props['SIDES'], 10) : undefined,
    isContainer,
    containedObjectIds: isContainer ? containedObjectIds : undefined,
    isStack,
    stackedObjects: isStack ? stackedObjects : undefined,
  };
}

/**
 * Serializes a GameObject to an Org document
 */
export function serializeObjectToOrg(obj: GameObject): string {
  const lines: string[] = [];
  lines.push(':PROPERTIES:');
  lines.push(`:ID: ${obj.id}`);
  lines.push(`:NAME: ${obj.name}`);
  lines.push(`:TYPE: ${obj.type}`);
  lines.push(`:GLYPH: ${obj.glyph}`);
  if (obj.faceUp !== undefined) {
    lines.push(`:FACE_UP: ${obj.faceUp ? 't' : 'nil'}`);
  }
  if (obj.color) {
    lines.push(`:COLOR: ${obj.color}`);
  }
  if (obj.value !== undefined) {
    lines.push(`:VALUE: ${obj.value}`);
  }
  if (obj.diceSides) {
    lines.push(`:SIDES: ${obj.diceSides}`);
  }
  if (obj.isContainer) {
    lines.push(`:IS_CONTAINER: t`);
    lines.push(`:ITEM_COUNT: ${obj.containedObjectIds?.length || 0}`);
  }
  if (obj.isStack) {
    lines.push(`:IS_STACK: t`);
    lines.push(`:STACK_SIZE: ${obj.stackedObjects?.length || 0}`);
  }
  for (const [key, val] of Object.entries(obj.properties)) {
    if (!['ID', 'NAME', 'TYPE', 'GLYPH', 'FACE_UP', 'COLOR', 'VALUE', 'SIDES', 'IS_CONTAINER', 'IS_STACK', 'ITEM_COUNT', 'STACK_SIZE'].includes(key.toUpperCase())) {
      lines.push(`:${key.toUpperCase()}: ${val}`);
    }
  }
  lines.push(':END:');
  lines.push('');
  lines.push(`* ${obj.name}`);
  if (obj.description) {
    lines.push(obj.description);
  }
  lines.push('');

  // If container, list member references
  if (obj.isContainer && obj.containedObjectIds && obj.containedObjectIds.length > 0) {
    lines.push('* Container Members');
    for (const refId of obj.containedObjectIds) {
      lines.push(`- [[file:objects/${refId}.org][${refId}]]`);
    }
    lines.push('');
  }

  // If stack, consolidate subheadings
  if (obj.isStack && obj.stackedObjects && obj.stackedObjects.length > 0) {
    lines.push('* Stack Items (Consolidated Org Documents)');
    for (const item of obj.stackedObjects) {
      lines.push(`** ${item.glyph} ${item.name}`);
      lines.push(':PROPERTIES:');
      lines.push(`:ORIGINAL_ID: ${item.id}`);
      lines.push(`:NAME: ${item.name}`);
      lines.push(`:GLYPH: ${item.glyph}`);
      lines.push(`:TYPE: ${item.type}`);
      for (const [k, v] of Object.entries(item.properties)) {
        if (!['ORIGINAL_ID', 'ID', 'NAME', 'GLYPH', 'TYPE'].includes(k.toUpperCase())) {
          lines.push(`:${k.toUpperCase()}: ${v}`);
        }
      }
      lines.push(':END:');
      lines.push('');
    }
  }

  return lines.join('\n');
}

/**
 * Normalizes felt dimensions per boardgame-org.md Section 4.6
 * - Missing cells filled with designated default felt symbol
 * - Content outside declared dimensions is ignored
 */
export function normalizeFeltGrid(rawFelt: string, width: number, height: number, defaultFelt: string): string[][] {
  const lines = rawFelt.split('\n');
  const grid: string[][] = [];

  for (let r = 0; r < height; r++) {
    const rowLine = lines[r] || '';
    const rowChars = Array.from(rowLine);
    const row: string[] = [];
    for (let c = 0; c < width; c++) {
      row.push(rowChars[c] || defaultFelt);
    }
    grid.push(row);
  }

  return grid;
}

/**
 * Parses a Board Org document
 */
export function parseBoardOrg(content: string, filePath: string): BoardState {
  const props = parseOrgProperties(content);
  const width = parseInt(props['WIDTH'] || '16', 10);
  const height = parseInt(props['HEIGHT'] || '10', 10);
  const defaultFelt = props['DEFAULT_FELT'] || '.';
  const name = props['NAME'] || 'Board Felt';
  const id = props['ID'] || 'board-main';

  // Parse Felt source block
  let feltRaw = '';
  const feltMatch = content.match(/#\+begin_src\s+felt[^\n]*\n([\s\S]*?)#\+end_src/i);
  if (feltMatch && feltMatch[1]) {
    feltRaw = feltMatch[1].trim();
  } else {
    // Generate default felt
    feltRaw = Array(height).fill(defaultFelt.repeat(width)).join('\n');
  }

  const feltGrid = normalizeFeltGrid(feltRaw, width, height, defaultFelt);

  // Parse placed objects table or subheadings
  const placedObjects: PlacedObjectRef[] = [];
  const tableMatch = content.match(/\* Placed Objects\n([\s\S]*?)(?=\n\*|\n#\+|\s*$)/i);
  if (tableMatch && tableMatch[1]) {
    const lines = tableMatch[1].split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith('|') || trimmed.includes('---') || trimmed.toLowerCase().includes('layer') || trimmed.toLowerCase().includes('id')) {
        continue;
      }
      const parts = trimmed.split('|').map(s => s.trim()).filter(Boolean);
      // Format: ID | X | Y | Layer
      if (parts.length >= 3) {
        const objId = parts[0];
        const x = parseInt(parts[1], 10);
        const y = parseInt(parts[2], 10);
        const layer = parts[3] ? parseInt(parts[3], 10) : 0;
        if (!isNaN(x) && !isNaN(y)) {
          placedObjects.push({ id: objId, x, y, layer });
        }
      }
    }
  }

  return {
    id,
    name,
    width,
    height,
    defaultFelt,
    feltGrid,
    placedObjects,
    filePath,
  };
}

/**
 * Serializes a BoardState to an Org document
 */
export function serializeBoardToOrg(board: BoardState, objectsMap: Record<string, GameObject>): string {
  const lines: string[] = [];
  lines.push(':PROPERTIES:');
  lines.push(`:ID: ${board.id}`);
  lines.push(`:NAME: ${board.name}`);
  lines.push(`:WIDTH: ${board.width}`);
  lines.push(`:HEIGHT: ${board.height}`);
  lines.push(`:DEFAULT_FELT: ${board.defaultFelt}`);
  lines.push(':END:');
  lines.push('');
  lines.push(`* ${board.name}`);
  lines.push('Serialized tabletop environment for boardgame.org.');
  lines.push('');
  lines.push('* Felt');
  lines.push(`#+begin_src felt :dimensions ${board.width}x${board.height}`);
  for (const row of board.feltGrid) {
    lines.push(row.join(''));
  }
  lines.push('#+end_src');
  lines.push('');
  lines.push('* Placed Objects');
  lines.push('| ID | X | Y | Layer | Glyph | Name | File |');
  lines.push('|----+---+---+-------+-------+------+------|');
  for (const p of board.placedObjects) {
    const obj = objectsMap[p.id];
    const glyph = obj ? obj.glyph : '?';
    const name = obj ? obj.name : p.id;
    const file = obj ? obj.filePath : `objects/${p.id}.org`;
    lines.push(`| ${p.id} | ${p.x} | ${p.y} | ${p.layer} | ${glyph} | ${name} | ${file} |`);
  }
  lines.push('');
  return lines.join('\n');
}

/**
 * Parses an Org document for player hand
 */
export function parseHandOrg(content: string, filePath: string): PlayerHand {
  const props = parseOrgProperties(content);
  const id = props['ID'] || filePath.replace(/[^a-zA-Z0-9_-]/g, '-');
  const name = props['NAME'] || 'Player Hand';
  const player = props['PLAYER'] || 'Player 1';
  
  const objectIds: string[] = [];
  const linkMatches = content.matchAll(/\[\[(?:file:)?([^\]]+)\]\[([^\]]*)\]\]/g);
  for (const m of linkMatches) {
    const refPath = m[1];
    const refId = refPath.replace(/\.org$/, '').split('/').pop() || refPath;
    objectIds.push(refId);
  }
  if (objectIds.length === 0 && props['OBJECT_IDS']) {
    objectIds.push(...props['OBJECT_IDS'].split(',').map(s => s.trim()).filter(Boolean));
  }

  return {
    id,
    name,
    player,
    objectIds,
    filePath,
  };
}

/**
 * Serializes a PlayerHand to an Org document
 */
export function serializeHandToOrg(hand: PlayerHand, objectsMap: Record<string, GameObject>): string {
  const lines: string[] = [];
  lines.push(':PROPERTIES:');
  lines.push(`:ID: ${hand.id}`);
  lines.push(`:NAME: ${hand.name}`);
  lines.push(`:PLAYER: ${hand.player}`);
  lines.push(`:ITEM_COUNT: ${hand.objectIds.length}`);
  lines.push(':END:');
  lines.push('');
  lines.push(`* ${hand.name} (${hand.player})`);
  lines.push('Game objects currently held in hand.');
  lines.push('');
  lines.push('* Hand Items');
  for (const id of hand.objectIds) {
    const obj = objectsMap[id];
    const name = obj ? `${obj.name} (${obj.glyph})` : id;
    lines.push(`- [[file:objects/${id}.org][${name}]]`);
  }
  lines.push('');
  return lines.join('\n');
}
