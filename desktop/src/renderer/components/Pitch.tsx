import type { CSSProperties, ReactNode } from 'react';
import type { Formation } from '../../shared/formation';

export type PitchOrientation = 'full' | 'bottomHalf' | 'topHalf';

/**
 * Maps a normalised formation point (x left→right, y own goal→opponent goal) onto the
 * pitch. `full` is one team attacking upwards; the halves place two teams on one pitch.
 */
export function pitchPosition(orientation: PitchOrientation, x: number, y: number): CSSProperties {
  switch (orientation) {
    case 'full':
      return { left: `${x * 100}%`, top: `${(0.965 - y * 0.93) * 100}%` };
    case 'bottomHalf':
      return { left: `${x * 100}%`, top: `${(0.985 - y * 0.47) * 100}%` };
    case 'topHalf':
      return { left: `${(1 - x) * 100}%`, top: `${(0.015 + y * 0.47) * 100}%` };
  }
}

interface PitchProps {
  /** width ÷ height; 0.68 is a full pitch, 0.72 suits a single team. */
  aspect?: number;
  children?: ReactNode;
}

/** The green surface with its white markings. */
export function Pitch({ aspect = 0.68, children }: PitchProps) {
  return (
    <div className="pitch" style={{ aspectRatio: String(aspect) }}>
      <svg viewBox="0 0 100 150" preserveAspectRatio="none" aria-hidden="true">
        <g fill="none" stroke="rgba(255,255,255,0.55)" strokeWidth="0.7">
          <rect x="3.5" y="3.5" width="93" height="143" />
          <line x1="3.5" y1="75" x2="96.5" y2="75" />
          <circle cx="50" cy="75" r="14" />
          <rect x="28" y="3.5" width="44" height="20" />
          <rect x="39" y="3.5" width="22" height="8" />
          <rect x="28" y="126.5" width="44" height="20" />
          <rect x="39" y="138.5" width="22" height="8" />
        </g>
        <circle cx="50" cy="75" r="1" fill="rgba(255,255,255,0.55)" />
      </svg>
      {children}
    </div>
  );
}

/** Tiny preview used by the formation picker and saved lineup cards. */
export function MiniPitch({ formation }: { formation: Formation }) {
  return (
    <div className="mini-pitch" aria-label={formation.name}>
      {formation.slots.map((slot) => (
        <span key={slot.id} className="mini-dot" style={pitchPosition('full', slot.x, slot.y)} />
      ))}
    </div>
  );
}
