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
    'game.buttons = 999',
    'game.buttons += 10',
    'game.kingdom_health -= 1',
    'game.towers.append(tower)',
    'game.events.clear()',
    'game.tick_count = 0',
    'game.buttons=5',
    'game.set("buttons", 5)',
    'game.get("rng").next_float()',
    'game["buttons"] = 5',
    'game.towers[0] = t',
    'game.towers[0].level = 3',
    'game.towers.append_array([t])',
    'game.towers.sort()',
    'game.towers.shuffle()',
    'game.events.pop_at(0)',
    'game.map.routes[0].append(c)',
    'game.map.tiles[0][1] = 2',
    'game.seed = 3',
    'game.call("set", "buttons", 1)',
    'game.buttons %= 2',
    'game.buttons **= 2',
    'game.buttons |= 2',
    'game.buttons &= 2',
    'game.buttons ^= 2',
    'game.buttons <<= 1',
    'game.buttons >>= 1',
    'game.towers[0].level <<= 1',
    'game.set(&"buttons", 1)',
    'game.set(StringName("buttons"), 1)',
    'game.set_indexed("buttons", 1)',
    'game.set_indexed(NodePath("buttons"), 1)',
    'game.call_deferred("set", "buttons", 1)',
    'game.call(&"set", "buttons", 1)',
    'game.set_deferred(&"buttons", 1)',
    'for p in game.get_property_list(): game.set(p.name, 0)',
    'my_game.towers.append(t)',
    'old_state.buttons = 3',
  ])('rejects %s', code => {
    expect(problems(code).length).toBeGreaterThan(0);
  });

  it.each([
    'Game.submit(game, Command.launch_wave())',
    'var held: int = game.buttons',
    'if game.over == true:',
    'for tower in game.towers:',
    'label.text = "Buttons %d" % game.buttons',
    'var routes := game.map.routes',
    '# game.buttons = 5 only in a comment',
    'board.map_seed = 42',
    'var text := "game.rng.state = 1"',
    'if game.buttons == 5 and game.kingdom_health != 0:',
    'var first := game.towers[0]',
    'for cell in game.map.path:',
    'var tile := game.map.tiles[row][col]',
    'if game.towers.size() >= 3:',
    'var level_text := "level %d" % game.towers[0].level',
    'board.map_seed += 1',
    'board.map = MapGen.generate(1)',
    'self.map = m',
    'noise.seed = 3',
    'particles.seed = 7',
    'agent.path = p',
    'player.wave = 3',
    'self.level = 2',
    'node.set("level", 3)',
    'foo.get("path")',
    'config["seed"] = 1',
    'stats["level"] += 1',
    'var d := {"buttons": 2}',
  ])('allows %s', code => {
    expect(problems(code)).toEqual([]);
  });

  it('sees a statement split inside an open bracket', () => {
    expect(check('game.towers[\n  0] = t\n').length).toBeGreaterThan(0);
    expect(check('game.map.tiles[\n  0][1] = 2\n').length).toBeGreaterThan(0);
    expect(check('game.buttons = (\n  5)\n').length).toBeGreaterThan(0);
    expect(check('var ok := compute(\n  game.buttons == 5)\n')).toEqual([]);
  });

  it('sees an assignment split with a line continuation', () => {
    expect(check('game.buttons \\\n  = 5\n').length).toBeGreaterThan(0);
  });

  it('reports the file and line', () => {
    const errors = check('var a = 1\ngame.buttons = 5\n', 'godot/render/x.gd');
    expect(errors[0]).toContain('godot/render/x.gd:2');
  });
});
