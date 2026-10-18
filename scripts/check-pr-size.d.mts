export const LIMIT: number;
export const WARN_ABOVE: number;
export function isProduction(path: string): boolean;
export function countProduction(numstat: string): {
  total: number;
  files: {path: string; lines: number}[];
};
export function verdict(total: number, allow?: boolean): 'ok' | 'warn' | 'fail';
export function report(
  numstat: string,
  allow?: boolean
): {lines: string[]; code: number};
