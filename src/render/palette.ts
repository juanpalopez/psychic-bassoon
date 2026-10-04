/**
 * Colours for 3D materials. Three.js cannot read CSS variables, so these
 * mirror `src/ui/tokens.css`; keep the two in step.
 */
export const PALETTE = {
  clear: 0x0f1216,
  ground: 0x11151b,
  plate: 0x1f2630,
  belt: 0x4d5a6c,
  beltStripe: 0xf2b134,
  spawn: 0xff8a3d,
  core: 0x5fd38a,
  towers: {
    welder: 0x3ddbd9,
    rivetMortar: 0xff8a3d,
    quenchCoil: 0x9b8cff,
    mainlineArc: 0xe8f06a,
  },
  robots: {
    skitter: 0xa8b4c2,
    hauler: 0x8794a3,
    smelter: 0x6b5a4a,
    overseer: 0xff4d5e,
  },
} as const;
