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
    'game.gold=5',
    'game.set("gold", 5)',
    'game.get("rng").next_float()',
    'game["gold"] = 5',
    'game.towers[0] = t',
    'game.towers[0].level = 3',
    'game.towers.append_array([t])',
    'game.towers.sort()',
    'game.towers.shuffle()',
    'game.events.pop_at(0)',
    'game.map.routes[0].append(c)',
    'game.map.tiles[0][1] = 2',
    'game.seed = 3',
    'game.call("set", "gold", 1)',
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
    'if game.gold == 5 and game.lives != 0:',
    'var first := game.towers[0]',
    'for cell in game.map.path:',
    'var tile := game.map.tiles[row][col]',
    'if game.towers.size() >= 3:',
    'var level_text := "level %d" % game.towers[0].level',
    'board.map_seed += 1',
  ])('allows %s', code => {
    expect(problems(code)).toEqual([]);
  });

  it('sees an assignment split with a line continuation', () => {
    expect(check('game.gold \\\n  = 5\n').length).toBeGreaterThan(0);
  });

  it('reports the file and line', () => {
    const errors = check('var a = 1\ngame.gold = 5\n', 'godot/render/x.gd');
    expect(errors[0]).toContain('godot/render/x.gd:2');
  });
});
