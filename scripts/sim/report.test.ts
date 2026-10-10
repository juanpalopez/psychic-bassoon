import {describe, expect, it} from 'vitest';
import type {GameMap} from '../../src/sim';
import {
  buildReport,
  formatMap,
  formatTable,
  parseArgs,
  summarizeWaves,
} from './report';
import type {WaveRow} from './report';

const ROUTE = [
  {col: 1, row: 0},
  {col: 1, row: 1},
  {col: 2, row: 1},
  {col: 2, row: 2},
];

const MAP: GameMap = {
  seed: 1,
  path: ROUTE,
  routes: [ROUTE],
  tiles: [
    ['plot', 'road', 'plot'],
    ['plot', 'road', 'road'],
    ['plot', 'plot', 'road'],
  ],
};

describe('formatMap', () => {
  it('draws road, spawn, heartstone and plots', () => {
    expect(formatMap(MAP)).toBe(['.S.', '.##', '..C'].join('\n'));
  });
});

describe('formatTable', () => {
  const rows: WaveRow[] = [
    {
      wave: 1,
      spawned: 7,
      killed: 7,
      leaked: 0,
      lives: 20,
      gold: 135,
      towers: 3,
    },
    {
      wave: 10,
      spawned: 22,
      killed: 20,
      leaked: 2,
      lives: 17,
      gold: 1042,
      towers: 12,
    },
  ];

  it('right-aligns every column under its header', () => {
    expect(formatTable(rows)).toBe(
      [
        'Wave  Spawned  Killed  Leaked  Lives  Gold  Towers',
        '   1        7       7       0     20   135       3',
        '  10       22      20       2     17  1042      12',
      ].join('\n')
    );
  });

  it('shows a dash for a wave that never finished', () => {
    const open: WaveRow = {
      wave: 3,
      spawned: 9,
      killed: 4,
      leaked: 0,
      lives: undefined,
      gold: undefined,
      towers: undefined,
    };
    expect(formatTable([open]).split('\n')[1]).toBe(
      '   3        9       4       0      -     -       -'
    );
  });
});

describe('parseArgs', () => {
  it('defaults to seed 42, 10 waves and speed 1', () => {
    expect(parseArgs([])).toEqual({seed: 42, waves: 10, speed: 1});
  });

  it('reads flags in both forms and skips a bare --', () => {
    expect(
      parseArgs(['--', '--seed', '7', '--waves=3', '--speed', '2'])
    ).toEqual({
      seed: 7,
      waves: 3,
      speed: 2,
    });
  });

  it.each([
    [['--seed', 'x']],
    [['--waves', '0']],
    [['--speed', '4']],
    [['--seed']],
    [['--nope', '1']],
    [['--seed', '1.5']],
  ])('rejects %j', argv => {
    expect(() => parseArgs(argv)).toThrow(Error);
  });
});

describe('summarizeWaves', () => {
  it('counts spawns, kills and leaks per wave', () => {
    const rows = summarizeWaves(
      [
        {tick: 1, event: {type: 'waveLaunched', wave: 1, earlyBonus: 0}},
        {
          tick: 2,
          event: {type: 'enemySpawned', enemyId: 5, foe: 'raider', wave: 1},
        },
        {
          tick: 2,
          event: {type: 'enemySpawned', enemyId: 6, foe: 'raider', wave: 1},
        },
        {
          tick: 3,
          event: {
            type: 'enemyKilled',
            enemyId: 5,
            foe: 'raider',
            reward: 6,
            x: 0,
            y: 0,
          },
        },
        {tick: 4, event: {type: 'enemyLeaked', enemyId: 6, leak: 1}},
        {tick: 5, event: {type: 'waveCleared', wave: 1, bonus: 17}},
      ],
      new Map([[1, {lives: 19, gold: 200, towers: 3}]])
    );
    expect(rows).toEqual([
      {
        wave: 1,
        spawned: 2,
        killed: 1,
        leaked: 1,
        lives: 19,
        gold: 200,
        towers: 3,
      },
    ]);
  });
});

describe('buildReport', () => {
  it('prints the same text twice for the same seed', () => {
    const args = {seed: 42, waves: 3, speed: 1};
    expect(buildReport(args)).toBe(buildReport(args));
  });

  it('prints the same results at any game speed', () => {
    const at = (speed: number) => buildReport({seed: 42, waves: 3, speed});
    expect(at(2)).toBe(at(1).replace('speed 1', 'speed 2'));
    expect(at(3)).toBe(at(1).replace('speed 1', 'speed 3'));
  });

  it('differs between seeds', () => {
    expect(buildReport({seed: 1, waves: 2, speed: 1})).not.toBe(
      buildReport({seed: 2, waves: 2, speed: 1})
    );
  });

  it('shows the map, the wave table and the result', () => {
    const text = buildReport({seed: 42, waves: 3, speed: 1});
    expect(text).toContain('seed 42');
    expect(text).toContain('S');
    expect(text).toContain('C');
    expect(text).toContain('Wave  Spawned');
    expect(text).toMatch(/Result: .*fingerprint [0-9a-f]{8}/);
    expect(text.split('\n').filter(l => /^\s+[123]\s/.test(l))).toHaveLength(3);
  });
});
