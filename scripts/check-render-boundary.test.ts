import {describe, expect, it} from 'vitest';
// @ts-expect-error plain .mjs script without types
import {check} from './check-render-boundary.mjs';

const problems = (code: string): string[] => check(code) as string[];

describe('render boundary check', () => {
  it.each([
    'state.rng.next_float()',
    'game.route_rng.state = 1',
    'game.pending.append(command)',
    'game.pending = []',
    'game.gold = 999',
    'game.gold += 10',
    'game.lives -= 1',
    'game.towers.append(tower)',
    'game.events.clear()',
    'game.tick_count = 0',
  ])('rejects %s', code => {
    expect(problems(code).length).toBeGreaterThan(0);
  });

  it.each([
    'Game.submit(game, Command.launch_wave())',
    'var gold: int = game.gold',
    'if game.over == true:',
    'for tower in game.towers:',
    'label.text = "gold %d" % game.gold',
    'var routes := game.map.routes',
    '# game.gold = 5 only in a comment',
    'board.map_seed = 42',
    'var text := "game.rng.state = 1"',
  ])('allows %s', code => {
    expect(problems(code)).toEqual([]);
  });

  it('reports the file and line', () => {
    const errors = check('var a = 1\ngame.gold = 5\n', 'godot/render/x.gd');
    expect(errors[0]).toContain('godot/render/x.gd:2');
  });
});
