import type { PitchRole } from './types';

export interface FormationSlot {
  /** Stable identifier, also persisted as `positionSlot` ("GK", "LCB", "ST"). */
  id: string;
  label: string;
  role: PitchRole;
  /** 0 is the goalkeeper line, 1 the defensive line, and so on. */
  line: number;
  indexInLine: number;
  /** API-Football style "row:column", persisted as `formationPosition`. */
  grid: string;
  /** Normalised position: x runs left→right, y runs own goal→opponent goal. */
  x: number;
  y: number;
}

export interface Formation {
  name: string;
  /** Outfield lines only, e.g. [4, 2, 3, 1]. */
  lines: number[];
  slots: FormationSlot[];
}

export const ROLE_DEPTH: Record<PitchRole, number> = {
  goalkeeper: 0,
  defender: 1,
  midfielder: 2,
  attacker: 3,
};

export const ROLE_ABBREVIATION: Record<PitchRole, string> = {
  goalkeeper: 'GK',
  defender: 'DEF',
  midfielder: 'MID',
  attacker: 'ATT',
};

export const ROLE_NAME: Record<PitchRole, string> = {
  goalkeeper: 'Goalkeeper',
  defender: 'Defender',
  midfielder: 'Midfielder',
  attacker: 'Attacker',
};

/**
 * Accepts the lineup short codes ("G", "D", "M", "F") and the long spellings
 * the players endpoint returns ("Goalkeeper", "Attacker", …).
 */
export function roleFromApi(value: string | null | undefined): PitchRole | null {
  if (!value) return null;
  switch (value.trim().toLowerCase()) {
    case 'g':
    case 'gk':
    case 'goalkeeper':
    case 'keeper':
      return 'goalkeeper';
    case 'd':
    case 'def':
    case 'defender':
    case 'defence':
    case 'defense':
      return 'defender';
    case 'm':
    case 'mid':
    case 'midfielder':
    case 'midfield':
      return 'midfielder';
    case 'f':
    case 'a':
    case 'att':
    case 'fw':
    case 'attacker':
    case 'forward':
    case 'striker':
      return 'attacker';
    default:
      return null;
  }
}

/**
 * 1 for an exact match, lower the further apart two roles are. A keeper never belongs
 * anywhere but in goal, and nobody else belongs in goal.
 */
export function roleCompatibility(a: PitchRole, b: PitchRole): number {
  if (a === b) return 1;
  if (a === 'goalkeeper' || b === 'goalkeeper') return 0.05;
  return Math.max(0, 1 - 0.35 * Math.abs(ROLE_DEPTH[a] - ROLE_DEPTH[b]));
}

/** Formations offered in the builder. */
export const SUPPORTED_FORMATIONS = [
  '4-3-3',
  '4-4-2',
  '4-2-3-1',
  '3-5-2',
  '3-4-3',
  '5-3-2',
  '4-1-4-1',
  '4-5-1',
] as const;

export const DEFAULT_FORMATION = '4-3-3';

/** Hand-tuned labels so the common shapes read the way a coach would write them. */
const BLUEPRINTS: Record<string, string[][]> = {
  '4-3-3': [
    ['LB', 'LCB', 'RCB', 'RB'],
    ['LCM', 'CM', 'RCM'],
    ['LW', 'ST', 'RW'],
  ],
  '4-4-2': [
    ['LB', 'LCB', 'RCB', 'RB'],
    ['LM', 'LCM', 'RCM', 'RM'],
    ['LST', 'RST'],
  ],
  '4-2-3-1': [
    ['LB', 'LCB', 'RCB', 'RB'],
    ['LDM', 'RDM'],
    ['LW', 'CAM', 'RW'],
    ['ST'],
  ],
  '3-5-2': [
    ['LCB', 'CB', 'RCB'],
    ['LWB', 'LCM', 'CM', 'RCM', 'RWB'],
    ['LST', 'RST'],
  ],
  '3-4-3': [
    ['LCB', 'CB', 'RCB'],
    ['LM', 'LCM', 'RCM', 'RM'],
    ['LW', 'ST', 'RW'],
  ],
  '5-3-2': [
    ['LWB', 'LCB', 'CB', 'RCB', 'RWB'],
    ['LCM', 'CM', 'RCM'],
    ['LST', 'RST'],
  ],
  '4-1-4-1': [
    ['LB', 'LCB', 'RCB', 'RB'],
    ['CDM'],
    ['LM', 'LCM', 'RCM', 'RM'],
    ['ST'],
  ],
  '4-5-1': [
    ['LB', 'LCB', 'RCB', 'RB'],
    ['LM', 'LCM', 'CM', 'RCM', 'RM'],
    ['ST'],
  ],
};

/** Labels that describe a role more precisely than their line does. */
const ROLE_OVERRIDES: Record<string, PitchRole> = {
  LW: 'attacker',
  RW: 'attacker',
  ST: 'attacker',
  LST: 'attacker',
  RST: 'attacker',
  CF: 'attacker',
  LF: 'attacker',
  RF: 'attacker',
  CAM: 'midfielder',
  CDM: 'midfielder',
  LDM: 'midfielder',
  RDM: 'midfielder',
  LWB: 'defender',
  RWB: 'defender',
};

export function horizontalPosition(index: number, count: number): number {
  if (count <= 1) return 0.5;
  const spread = count >= 5 ? 0.9 : 0.8;
  const start = (1 - spread) / 2;
  return start + (spread * index) / (count - 1);
}

export function verticalPosition(lineIndex: number, lineCount: number): number {
  const first = 0.24;
  const last = 0.9;
  if (lineCount <= 1) return 0.62;
  return first + ((last - first) * lineIndex) / (lineCount - 1);
}

function roleForLine(index: number, lineCount: number): PitchRole {
  if (index === 0) return 'defender';
  if (index === lineCount - 1) return 'attacker';
  return 'midfielder';
}

function genericLabels(count: number, role: PitchRole): string[] {
  const table: Record<string, string[]> = {
    'defender-2': ['LCB', 'RCB'],
    'defender-3': ['LCB', 'CB', 'RCB'],
    'defender-4': ['LB', 'LCB', 'RCB', 'RB'],
    'defender-5': ['LWB', 'LCB', 'CB', 'RCB', 'RWB'],
    'midfielder-1': ['CM'],
    'midfielder-2': ['LCM', 'RCM'],
    'midfielder-3': ['LCM', 'CM', 'RCM'],
    'midfielder-4': ['LM', 'LCM', 'RCM', 'RM'],
    'midfielder-5': ['LM', 'LCM', 'CM', 'RCM', 'RM'],
    'attacker-1': ['ST'],
    'attacker-2': ['LST', 'RST'],
    'attacker-3': ['LW', 'ST', 'RW'],
    'attacker-4': ['LW', 'LF', 'RF', 'RW'],
  };
  const preset = table[`${role}-${count}`];
  if (preset) return preset;
  return Array.from({ length: count }, (_, index) => `${ROLE_ABBREVIATION[role]}${index + 1}`);
}

function uniqueId(label: string, taken: Set<string>): string {
  let candidate = label;
  let suffix = 2;
  while (taken.has(candidate)) {
    candidate = `${label}${suffix}`;
    suffix += 1;
  }
  taken.add(candidate);
  return candidate;
}

/**
 * Parses "4-3-3" — or any other dash separated shape the API returns — into slots.
 * Returns null for shapes that cannot be understood.
 */
export function parseFormation(raw: string | null | undefined): Formation | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;

  const parts = trimmed.split(/[-–]/);
  if (parts.length < 2) return null;

  const lines: number[] = [];
  for (const part of parts) {
    const value = Number(part.trim());
    if (!Number.isInteger(value) || value <= 0 || value > 6) return null;
    lines.push(value);
  }
  const total = lines.reduce((sum, value) => sum + value, 0);
  if (total > 10) return null;

  const name = lines.join('-');
  const labels =
    BLUEPRINTS[name] ?? lines.map((count, index) => genericLabels(count, roleForLine(index, lines.length)));

  const taken = new Set<string>(['GK']);
  const slots: FormationSlot[] = [
    {
      id: 'GK',
      label: 'GK',
      role: 'goalkeeper',
      line: 0,
      indexInLine: 0,
      grid: '1:1',
      x: 0.5,
      y: 0.07,
    },
  ];

  lines.forEach((count, lineIndex) => {
    const lineLabels = labels[lineIndex] ?? [];
    const defaultRole = roleForLine(lineIndex, lines.length);
    for (let index = 0; index < count; index += 1) {
      const label = lineLabels[index] ?? `${ROLE_ABBREVIATION[defaultRole]}${index + 1}`;
      slots.push({
        id: uniqueId(label, taken),
        label,
        role: ROLE_OVERRIDES[label] ?? defaultRole,
        line: lineIndex + 1,
        indexInLine: index,
        grid: `${lineIndex + 2}:${index + 1}`,
        x: horizontalPosition(index, count),
        y: verticalPosition(lineIndex, lines.length),
      });
    }
  });

  return { name, lines, slots };
}

export function formationSlot(formation: Formation, id: string): FormationSlot | undefined {
  return formation.slots.find((slot) => slot.id === id);
}

/** Parses "2:3" into its row and column. */
export function gridCoordinate(grid: string | null | undefined): { row: number; column: number } | null {
  if (!grid) return null;
  const parts = grid.split(':');
  if (parts.length !== 2) return null;
  const row = Number((parts[0] ?? '').trim());
  const column = Number((parts[1] ?? '').trim());
  if (!Number.isInteger(row) || !Number.isInteger(column) || row <= 0 || column <= 0) return null;
  return { row, column };
}

/**
 * Pitch positions for a lineup coming from the API, which supplies "row:column" grids.
 * Falls back to the parsed formation when grids are missing or malformed.
 */
export function layoutPoints(
  grids: (string | null | undefined)[],
  fallbackFormation: string | null | undefined,
): { x: number; y: number }[] {
  const parsed = grids.map((grid) => gridCoordinate(grid));

  if (parsed.length > 0 && parsed.every((value) => value !== null)) {
    const coordinates = parsed as { row: number; column: number }[];
    const rows = Array.from(new Set(coordinates.map((value) => value.row))).sort((a, b) => a - b);
    const columnsByRow = new Map<number, number[]>();
    for (const coordinate of coordinates) {
      const existing = columnsByRow.get(coordinate.row) ?? [];
      existing.push(coordinate.column);
      columnsByRow.set(coordinate.row, existing);
    }
    for (const columns of columnsByRow.values()) {
      columns.sort((a, b) => a - b);
    }

    return coordinates.map((coordinate) => {
      const rowIndex = Math.max(0, rows.indexOf(coordinate.row));
      const columns = columnsByRow.get(coordinate.row) ?? [coordinate.column];
      const columnIndex = Math.max(0, columns.indexOf(coordinate.column));
      const y = rowIndex === 0 ? 0.07 : verticalPosition(rowIndex - 1, Math.max(1, rows.length - 1));
      const x = rowIndex === 0 ? 0.5 : horizontalPosition(columnIndex, columns.length);
      return { x, y };
    });
  }

  const formation = parseFormation(fallbackFormation);
  if (formation) {
    const points = formation.slots.map((slot) => ({ x: slot.x, y: slot.y }));
    if (points.length >= grids.length) return points.slice(0, grids.length);
    return [
      ...points,
      ...Array.from({ length: grids.length - points.length }, () => ({ x: 0.5, y: 0.5 })),
    ];
  }

  // Last resort: spread everybody out in evenly sized rows.
  const perRow = 4;
  const rowCount = Math.max(1, Math.ceil(grids.length / perRow));
  return grids.map((_, index) => ({
    x: horizontalPosition(index % perRow, perRow),
    y: verticalPosition(Math.floor(index / perRow), rowCount),
  }));
}

function slotCost(origin: FormationSlot, destination: FormationSlot, role: PitchRole | null): number {
  const dx = origin.x - destination.x;
  const dy = origin.y - destination.y;
  const distance = Math.sqrt(dx * dx + dy * dy);
  const score = roleCompatibility(role ?? origin.role, destination.role);
  return distance + (1 - score) * 1.5;
}

/**
 * Moves existing picks onto a new formation, keeping everyone as close as possible to
 * where they were and preferring slots that match their role. Players with nowhere to
 * go come back in `unplaced`.
 */
export function remapAssignments<T>(
  assignments: Record<string, T>,
  from: Formation,
  to: Formation,
  roleOf: (value: T) => PitchRole | null,
): { assigned: Record<string, T>; unplaced: T[] } {
  const entries = Object.entries(assignments);
  if (entries.length === 0) return { assigned: {}, unplaced: [] };

  // Keepers first, then back to front, so the spine settles before the wide players.
  const ordered = entries
    .flatMap(([slotId, value]) => {
      const slot = formationSlot(from, slotId);
      return slot ? [{ slot, value }] : [];
    })
    .sort((a, b) => (a.slot.line !== b.slot.line ? a.slot.line - b.slot.line : a.slot.indexInLine - b.slot.indexInLine));

  // Anything whose old slot disappeared still deserves a place.
  const unplaced: T[] = entries
    .filter(([slotId]) => formationSlot(from, slotId) === undefined)
    .map(([, value]) => value);

  const available = [...to.slots];
  const assigned: Record<string, T> = {};

  for (const entry of ordered) {
    if (available.length === 0) {
      unplaced.push(entry.value);
      continue;
    }
    const role = roleOf(entry.value);
    let bestIndex = 0;
    let bestCost = Number.POSITIVE_INFINITY;
    available.forEach((slot, index) => {
      const cost = slotCost(entry.slot, slot, role);
      if (cost < bestCost) {
        bestCost = cost;
        bestIndex = index;
      }
    });
    const [target] = available.splice(bestIndex, 1);
    if (target) assigned[target.id] = entry.value;
  }

  return { assigned, unplaced };
}

/** The free slot that suits a role best — used when a player is picked without a target. */
export function bestSlotFor(
  role: PitchRole | null,
  formation: Formation,
  occupied: Set<string>,
): FormationSlot | null {
  const free = formation.slots.filter((slot) => !occupied.has(slot.id));
  if (free.length === 0) return null;
  if (!role) return free[0] ?? null;

  let best = free[0] ?? null;
  let bestScore = best ? roleCompatibility(role, best.role) : -1;
  for (const slot of free.slice(1)) {
    const score = roleCompatibility(role, slot.role);
    if (score > bestScore) {
      best = slot;
      bestScore = score;
    }
  }
  return best;
}
