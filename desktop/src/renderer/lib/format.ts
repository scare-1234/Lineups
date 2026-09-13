/** yyyy-mm-dd in local time — the format API-Football's `date` parameter expects. */
export function dayKey(date: Date): string {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function addDays(date: Date, days: number): Date {
  const copy = new Date(date);
  copy.setDate(copy.getDate() + days);
  return copy;
}

export function isSameDay(a: Date, b: Date): boolean {
  return dayKey(a) === dayKey(b);
}

/** Seven days back, today, seven days forward. */
export function matchDayStrip(reference = new Date()): Date[] {
  return Array.from({ length: 15 }, (_, index) => addDays(reference, index - 7));
}

export function dayLabel(date: Date, reference = new Date()): string {
  if (isSameDay(date, reference)) return 'Today';
  if (isSameDay(date, addDays(reference, 1))) return 'Tomorrow';
  if (isSameDay(date, addDays(reference, -1))) return 'Yesterday';
  return date.toLocaleDateString(undefined, { weekday: 'short', day: 'numeric' });
}

export function monthDay(date: Date): string {
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

export function kickoffTime(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
}

export function fullDateTime(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

export function dateOnly(iso: string | null): string | null {
  if (!iso) return null;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleDateString(undefined, { dateStyle: 'long' });
}

/** "Rafael Moreno" → "R. Moreno" so names fit on the pitch. */
export function shortName(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length < 2) return name;
  const [first, ...rest] = parts;
  return `${(first ?? '').charAt(0)}. ${rest.join(' ')}`;
}

export function initials(name: string): string {
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part.charAt(0))
    .join('')
    .toUpperCase();
}

export function relativeTime(iso: string): string {
  const stored = new Date(iso).getTime();
  if (Number.isNaN(stored)) return '';
  const minutes = Math.round((Date.now() - stored) / 60000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} h ago`;
  return `${Math.round(hours / 24)} d ago`;
}
