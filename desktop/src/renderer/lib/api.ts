import type { LineupLabApi } from '../../shared/api';

/** The bridge the preload installed. Nothing else in the renderer touches the outside world. */
export const api: LineupLabApi = window.lineupLab;
