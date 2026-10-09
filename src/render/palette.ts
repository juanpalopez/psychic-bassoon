/**
 * Colours for 3D materials. Three.js cannot read CSS variables, so these
 * mirror `src/ui/tokens.css`; keep the two in step.
 */
export const PALETTE = {
  clear: 0x0f1216,
  ground: 0x11151b,
  plot: 0x1f2630,
  road: 0x4d5a6c,
  roadStripe: 0xf2b134,
  selection: 0xf2b134, // the accent colour
  spawn: 0xff8a3d,
  core: 0x5fd38a,
  towers: {
    ballista: 0x3ddbd9,
    catapult: 0xff8a3d,
    frostSpire: 0x9b8cff,
    stormSpire: 0xe8f06a,
  },
  foes: {
    scamp: 0xa8b4c2,
    raider: 0x8794a3,
    ironclad: 0x6b5a4a,
    warlord: 0xff4d5e,
  },
} as const;
