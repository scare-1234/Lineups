import { flagLabel } from '../../shared/flags';
import { ROLE_NAME, roleFromApi } from '../../shared/formation';
import type { CustomLineupPlayer, LineupPlayer, Player } from '../../shared/types';
import { Avatar } from './Avatar';
import { RatingBadge } from './Badges';

interface PlayerRowProps {
  name: string;
  nationality: string;
  age: number;
  position: string | null;
  rating: number | null;
  photo: string | null;
  club: string | null;
  number?: number | null;
  isCaptain?: boolean;
  onClick?: () => void;
  trailing?: React.ReactNode;
}

export function PlayerRow({
  name,
  nationality,
  age,
  position,
  rating,
  photo,
  club,
  number,
  isCaptain,
  onClick,
  trailing,
}: PlayerRowProps) {
  const role = roleFromApi(position);
  const positionLabel = role ? ROLE_NAME[role] : position;
  const details = [flagLabel(nationality, '—'), age > 0 ? `${age}` : null, positionLabel]
    .filter((value): value is string => Boolean(value))
    .join(' · ');

  return (
    <button type="button" className="player-row" onClick={onClick} disabled={!onClick}>
      {number !== undefined && number !== null ? <span className="player-number">{number}</span> : null}
      <Avatar url={photo} name={name} />
      <span style={{ minWidth: 0, flex: 1 }}>
        <span className="name">
          {name}
          {isCaptain ? <span className="caption" title="Captain"> (C)</span> : null}
        </span>
        <span className="sub" style={{ display: 'block' }}>
          {details}
        </span>
        {club ? (
          <span className="sub" style={{ display: 'block' }}>
            {club}
          </span>
        ) : null}
      </span>
      {trailing}
      <RatingBadge rating={rating} />
    </button>
  );
}

export function PlayerRowFromPlayer({ player, onClick }: { player: Player; onClick?: () => void }) {
  return (
    <PlayerRow
      name={player.name}
      nationality={player.nationality}
      age={player.age}
      position={player.position}
      rating={player.rating}
      photo={player.photo}
      club={player.clubTeam}
      onClick={onClick}
    />
  );
}

export function PlayerRowFromLineup({ entry, onClick }: { entry: LineupPlayer; onClick?: () => void }) {
  return (
    <PlayerRow
      name={entry.player.name}
      nationality={entry.player.nationality}
      age={entry.player.age}
      position={entry.position}
      rating={entry.rating}
      photo={entry.player.photo}
      club={null}
      number={entry.number > 0 ? entry.number : null}
      isCaptain={entry.matchStats?.isCaptain ?? false}
      onClick={onClick}
    />
  );
}

export function PlayerRowFromCustom({
  player,
  onClick,
  trailing,
}: {
  player: CustomLineupPlayer;
  onClick?: () => void;
  trailing?: React.ReactNode;
}) {
  return (
    <PlayerRow
      name={player.playerName}
      nationality={player.playerNationality}
      age={player.playerAge}
      position={player.playerPosition}
      rating={player.playerRating}
      photo={player.playerPhoto}
      club={player.playerClub}
      onClick={onClick}
      trailing={trailing}
    />
  );
}
