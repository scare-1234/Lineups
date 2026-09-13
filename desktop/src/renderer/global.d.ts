import type { LineupLabApi } from '../shared/api';

declare global {
  interface Window {
    lineupLab: LineupLabApi;
  }
}

export {};
