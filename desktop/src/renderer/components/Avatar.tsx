import { useState } from 'react';
import { initials as toInitials } from '../lib/format';
import type { Team } from '../../shared/types';

interface AvatarProps {
  url: string | null;
  name: string;
  size?: number;
}

/** Circular player photo with an initials fallback when the photo is missing. */
export function Avatar({ url, name, size = 40 }: AvatarProps) {
  const [failed, setFailed] = useState(false);
  const showImage = url !== null && !failed;
  return (
    <span className="avatar" style={{ width: size, height: size, fontSize: Math.round(size * 0.36) }}>
      {showImage ? (
        <img src={url} alt="" loading="lazy" onError={() => setFailed(true)} />
      ) : (
        toInitials(name) || '·'
      )}
    </span>
  );
}

export function Crest({ team, size = 24 }: { team: Team; size?: number }) {
  const [failed, setFailed] = useState(false);
  const showImage = team.logo !== null && !failed;
  return (
    <span className="crest" style={{ width: size, height: size, fontSize: Math.round(size * 0.4) }}>
      {showImage ? (
        <img src={team.logo ?? ''} alt="" loading="lazy" onError={() => setFailed(true)} />
      ) : (
        <span className="muted">{toInitials(team.name)}</span>
      )}
    </span>
  );
}
