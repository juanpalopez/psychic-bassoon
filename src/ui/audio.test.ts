import {describe, expect, it} from 'vitest';
import {createAudio, soundFor} from './audio';
import type {AudioContextLike} from './audio';

function fakeContext() {
  const calls = {oscillators: 0, resumed: 0};
  const context: AudioContextLike = {
    currentTime: 0,
    destination: {},
    resume: () => {
      calls.resumed++;
      return Promise.resolve();
    },
    createGain: () => ({
      gain: {
        value: 0,
        setValueAtTime: () => undefined,
        exponentialRampToValueAtTime: () => undefined,
      },
      connect: () => undefined,
    }),
    createOscillator: () => {
      calls.oscillators++;
      return {
        type: 'square',
        frequency: {value: 0},
        connect: () => undefined,
        start: () => undefined,
        stop: () => undefined,
      };
    },
  };
  return {context, calls};
}

describe('createAudio', () => {
  it('makes no audio context and no sound before the first tap', () => {
    let made = 0;
    const {context, calls} = fakeContext();
    const audio = createAudio(
      () => {
        made++;
        return context;
      },
      () => 0
    );
    audio.play('kill');
    audio.play('wave');
    expect(made).toBe(0);
    expect(calls.oscillators).toBe(0);
    expect(audio.unlocked).toBe(false);
  });

  it('plays once the first tap has unlocked it', () => {
    const {context, calls} = fakeContext();
    const audio = createAudio(
      () => context,
      () => 0
    );
    audio.unlock();
    expect(audio.unlocked).toBe(true);
    expect(calls.resumed).toBe(1);
    audio.play('kill');
    expect(calls.oscillators).toBe(1);
  });

  it('keeps trying to resume a suspended context on later gestures', () => {
    const {context, calls} = fakeContext();
    const audio = createAudio(
      () => ({...context, state: 'suspended'}),
      () => 0
    );
    audio.unlock();
    audio.unlock();
    expect(calls.resumed).toBe(2);
  });

  it('stops resuming once the context is running', () => {
    const {context, calls} = fakeContext();
    const audio = createAudio(
      () => ({...context, state: 'running'}),
      () => 0
    );
    audio.unlock();
    audio.unlock();
    expect(calls.resumed).toBe(1);
  });

  it('creates the context only once however often it is unlocked', () => {
    let made = 0;
    const {context} = fakeContext();
    const audio = createAudio(
      () => {
        made++;
        return context;
      },
      () => 0
    );
    audio.unlock();
    audio.unlock();
    expect(made).toBe(1);
  });

  it('limits how often one sound can repeat', () => {
    let time = 0;
    const {context, calls} = fakeContext();
    const audio = createAudio(
      () => context,
      () => time
    );
    audio.unlock();
    for (let i = 0; i < 10; i++) audio.play('shot');
    expect(calls.oscillators).toBe(1);
    time = 1000;
    audio.play('shot');
    expect(calls.oscillators).toBe(2);
  });

  it('survives a browser with no audio support', () => {
    const audio = createAudio(
      () => {
        throw new Error('no audio');
      },
      () => 0
    );
    expect(() => audio.unlock()).not.toThrow();
    expect(() => audio.play('kill')).not.toThrow();
  });
});

describe('soundFor', () => {
  it('maps the events a player should hear', () => {
    expect(
      soundFor({
        type: 'enemyKilled',
        enemyId: 1,
        foe: 'raider',
        reward: 1,
        x: 0,
        y: 0,
      })
    ).toBe('kill');
    expect(soundFor({type: 'enemyLeaked', enemyId: 1, leak: 1})).toBe('leak');
    expect(soundFor({type: 'towerBuilt', towerId: 1})).toBe('build');
    expect(soundFor({type: 'waveLaunched', wave: 1, earlyBonus: 0})).toBe(
      'wave'
    );
    expect(soundFor({type: 'gameOver', wave: 3})).toBe('leak');
    expect(
      soundFor({type: 'enemySpawned', enemyId: 1, foe: 'raider', wave: 1})
    ).toBeUndefined();
  });
});
