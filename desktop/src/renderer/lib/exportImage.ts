import type { Formation } from '../../shared/formation';
import { ratingColor, ratingForeground, ratingText } from '../../shared/rating';
import type { CustomLineupPlayer } from '../../shared/types';
import { shortName } from './format';

interface ExportOptions {
  title: string;
  formation: Formation;
  assignments: Record<string, CustomLineupPlayer>;
  averageRating: number | null;
}

/**
 * Draws the current XI onto a canvas and returns a PNG data URL, which the main process
 * writes to disk through a save dialog.
 */
export function renderLineupImage(options: ExportOptions): string {
  const width = 900;
  const height = 1280;
  const headerHeight = 92;
  const footerHeight = 64;

  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) return '';

  context.fillStyle = '#0d1b0f';
  context.fillRect(0, 0, width, height);

  // Header
  context.fillStyle = '#ffffff';
  context.font = '700 34px "Segoe UI", system-ui, sans-serif';
  context.textBaseline = 'middle';
  context.fillText(options.title, 32, headerHeight / 2);
  context.font = '800 30px "Segoe UI", system-ui, sans-serif';
  context.fillStyle = '#00c853';
  context.textAlign = 'right';
  context.fillText(options.formation.name, width - 32, headerHeight / 2);
  context.textAlign = 'left';

  // Pitch
  const pitch = {
    x: 32,
    y: headerHeight,
    width: width - 64,
    height: height - headerHeight - footerHeight,
  };
  const gradient = context.createLinearGradient(0, pitch.y, 0, pitch.y + pitch.height);
  gradient.addColorStop(0, '#2e7d32');
  gradient.addColorStop(1, '#1b5e20');
  context.fillStyle = gradient;
  context.fillRect(pitch.x, pitch.y, pitch.width, pitch.height);

  context.strokeStyle = 'rgba(255,255,255,0.55)';
  context.lineWidth = 2;
  const inset = 18;
  context.strokeRect(pitch.x + inset, pitch.y + inset, pitch.width - inset * 2, pitch.height - inset * 2);
  context.beginPath();
  context.moveTo(pitch.x + inset, pitch.y + pitch.height / 2);
  context.lineTo(pitch.x + pitch.width - inset, pitch.y + pitch.height / 2);
  context.stroke();
  context.beginPath();
  context.arc(pitch.x + pitch.width / 2, pitch.y + pitch.height / 2, pitch.width * 0.14, 0, Math.PI * 2);
  context.stroke();
  const boxWidth = pitch.width * 0.46;
  const boxHeight = pitch.height * 0.13;
  context.strokeRect(pitch.x + (pitch.width - boxWidth) / 2, pitch.y + inset, boxWidth, boxHeight);
  context.strokeRect(
    pitch.x + (pitch.width - boxWidth) / 2,
    pitch.y + pitch.height - inset - boxHeight,
    boxWidth,
    boxHeight,
  );

  // Tokens
  for (const slot of options.formation.slots) {
    const player = options.assignments[slot.id];
    const cx = pitch.x + slot.x * pitch.width;
    const cy = pitch.y + (0.965 - slot.y * 0.93) * pitch.height;
    const radius = 26;

    context.beginPath();
    context.arc(cx, cy, radius, 0, Math.PI * 2);
    if (player) {
      context.fillStyle = 'rgba(255,255,255,0.94)';
      context.fill();
    } else {
      context.setLineDash([6, 5]);
      context.strokeStyle = 'rgba(255,255,255,0.7)';
      context.stroke();
      context.setLineDash([]);
    }

    context.textAlign = 'center';
    context.font = '700 14px "Segoe UI", system-ui, sans-serif';
    context.fillStyle = player ? 'rgba(0,0,0,0.78)' : '#ffffff';
    context.fillText(slot.label, cx, cy);

    if (player) {
      // Name plate
      const label = shortName(player.playerName);
      context.font = '600 15px "Segoe UI", system-ui, sans-serif';
      const textWidth = context.measureText(label).width;
      context.fillStyle = 'rgba(0,0,0,0.45)';
      context.fillRect(cx - textWidth / 2 - 8, cy + radius + 6, textWidth + 16, 22);
      context.fillStyle = '#ffffff';
      context.fillText(label, cx, cy + radius + 17);

      // Rating chip
      context.beginPath();
      context.arc(cx + radius - 2, cy - radius + 2, 13, 0, Math.PI * 2);
      context.fillStyle = ratingColor(player.playerRating);
      context.fill();
      context.fillStyle = ratingForeground(player.playerRating);
      context.font = '800 12px "Segoe UI", system-ui, sans-serif';
      context.fillText(ratingText(player.playerRating), cx + radius - 2, cy - radius + 3);
    }
    context.textAlign = 'left';
  }

  // Footer
  context.fillStyle = 'rgba(255,255,255,0.85)';
  context.font = '600 18px "Segoe UI", system-ui, sans-serif';
  context.fillText('LineupLab', 32, height - footerHeight / 2);
  context.textAlign = 'right';
  context.fillText(`Avg rating ${ratingText(options.averageRating)}`, width - 32, height - footerHeight / 2);
  context.textAlign = 'left';

  return canvas.toDataURL('image/png');
}
