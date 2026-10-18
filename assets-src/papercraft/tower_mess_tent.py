
# tower_mess_tent.py - The Kitchen Mess Tent: a corrugated shipping box turned mess hall.
# Its long top flaps lean together as a roof held by a clothes peg, the end flaps are cut
# into gables, a striped straw is the chimney, a serving hatch is cut in the front with its
# flap folded down as a counter under a paper awning, and a crimped bottle-cap cauldron of
# Hearty Stew bubbles on matchstick legs over a paper flame. Parts: Base (all of that),
# Ladle (a teaspoon that stirs the pot) and Steam (tissue puffs rising from the pot).

MT_W, MT_D, MT_H = 1.10, 0.84, 0.72      # the box
MT_RIDGE = 1.22
MT_POT = Vector((0.55, -0.56, 0.34))       # the pot's rim centre
MT_POT_S = 1.2                            # the bottle cap, against the box


def build_mess_tent(c, at):
    KRAFT = lin("#c39566"); KRAFT_L = lin("#d3a878"); INK = lin("#2a2420"); DARK = lin("#3a2a20")
    WOOD = lin("#e3c79a"); STEEL = lin("#c9cdd3"); RED = lin("#c8392f"); WHITE = lin("#f6f2ea")
    YEL = lin("#efc23e"); CAP = lin("#c63a33"); CAP_IN = lin("#d8dade"); STEW = lin("#7a4424")
    CARROT = lin("#e8822e"); PEA = lin("#7ea23a"); FLAME = lin("#ff9a2e", 0.9); FLAME2 = lin("#ffd04a", 1.0)
    MATCH = lin("#e9d2a6"); HEAD = lin("#c83a2e"); CARD = lin("#f3ead6")
    W, Dp, H = MT_W / 2, MT_D / 2, MT_H

    b = Part("MessTent_Base")
    # the box: corrugated walls (the cut edges show the flutes), kraft faces with stamps
    def wall(poly, F, col=KRAFT):
        b.slab(poly, 0.03, col, shade(col, 0.85), M=F, edge_mat="PK_Corrugated")
    # front wall with the serving hatch cut out: four slabs round the hole
    HX0, HX1, HZ0, HZ1 = -0.30, 0.26, 0.30, 0.58
    Ff = frame((0, -Dp, 0), (1, 0, 0), (0, 0, 1))      # local z = -Y? (x cross z = -y)
    for poly in ([(-W, 0), (W, 0), (W, HZ0), (-W, HZ0)], [(-W, HZ1), (W, HZ1), (W, H), (-W, H)],
                 [(-W, HZ0), (HX0, HZ0), (HX0, HZ1), (-W, HZ1)], [(HX1, HZ0), (W, HZ0), (W, HZ1), (HX1, HZ1)]):
        wall(poly, Ff)
    # back and sides
    wall([(-W, 0), (W, 0), (W, H), (-W, H)], frame((0, Dp, 0), (1, 0, 0), (0, 0, 1)))
    for s in (-1, 1):
        g = [(-Dp, 0), (Dp, 0), (Dp, H), (0, MT_RIDGE - 0.04), (-Dp, H)]
        wall(g, frame((s * W - (0.03 if s > 0 else 0), 0, 0), (0, 1, 0), (0, 0, 1)) if False else
             frame((s * W - (0.0 if s < 0 else 0.03), 0, 0), (0, 1, 0), (0, 0, 1)))
    # the dark inside, seen through the hatch
    b.box((HX0, -Dp + 0.03, HZ0), (HX1, -Dp + 0.05, HZ1), DARK)
    # the hatch flap folded down as a counter, on two thread stays
    b.slab([(HX0, -0.26), (HX1, -0.26), (HX1, 0.0), (HX0, 0.0)], 0.03, KRAFT_L, shade(KRAFT_L, 0.85),
           M=Matrix.Translation((0, -Dp - 0.0, HZ0 - 0.03)), edge_mat="PK_Corrugated")
    for x in (HX0 + 0.02, HX1 - 0.02):
        b.tube([(x, -Dp - 0.25, HZ0), (x, -Dp - 0.01, HZ1 + 0.02)], 0.006, 4, WHITE, caps=False)
    # a folded menu card on the counter
    b.face([(-0.18, -Dp - 0.08, HZ0 + 0.001), (-0.02, -Dp - 0.08, HZ0 + 0.001), (-0.02, -Dp - 0.14, HZ0 + 0.1), (-0.18, -Dp - 0.14, HZ0 + 0.1)], CARD)
    b.face([(-0.18, -Dp - 0.20, HZ0 + 0.001), (-0.18, -Dp - 0.14, HZ0 + 0.1), (-0.02, -Dp - 0.14, HZ0 + 0.1), (-0.02, -Dp - 0.20, HZ0 + 0.001)], CARD)
    for k in range(3):
        z = HZ0 + 0.03 + 0.022 * k
        b.face([(-0.16, -Dp - 0.0805 - (z - HZ0) * 0.6 - 0.002, z), (-0.04 - 0.03 * (k == 1), -Dp - 0.0805 - (z - HZ0) * 0.6 - 0.002, z),
                (-0.04 - 0.03 * (k == 1), -Dp - 0.0805 - (z + 0.01 - HZ0) * 0.6 - 0.002, z + 0.01), (-0.16, -Dp - 0.0805 - (z + 0.01 - HZ0) * 0.6 - 0.002, z + 0.01)],
               RED if k == 0 else INK)
    # a striped paper awning over the hatch, pleated
    n = 7
    for k in range(n):
        x0 = HX0 - 0.06 + (HX1 - HX0 + 0.12) * k / n; x1 = HX0 - 0.06 + (HX1 - HX0 + 0.12) * (k + 1) / n
        col = YEL if k % 2 == 0 else WHITE
        q = [(x0, -Dp - 0.005, HZ1 + 0.10), (x1, -Dp - 0.005, HZ1 + 0.10), (x1, -Dp - 0.20, HZ1 + 0.0), (x0, -Dp - 0.20, HZ1 + 0.0)]
        b.face(q, col); b.face(list(reversed(q)), shade(col, 0.6))
        sc = [(x0, -Dp - 0.20, HZ1), (x1, -Dp - 0.20, HZ1), ((x0 + x1) / 2, -Dp - 0.205, HZ1 - 0.05)]
        b.face(sc, col); b.face(list(reversed(sc)), shade(col, 0.6))
    # printed stamps: an up-arrow pair and a stew-pot mark on the front, a red FRAGILE band
    def stamp(poly, x, z, col=INK):
        b.face([(x + px, -Dp - 0.031, z + pz) for px, pz in poly], col)
    arrow = [(0, 0.09), (-0.05, 0.04), (-0.018, 0.04), (-0.018, 0.0), (0.018, 0.0), (0.018, 0.04), (0.05, 0.04)]
    stamp([(p[0], p[1]) for p in reversed(arrow)], -0.48, 0.42)
    stamp([(p[0], p[1]) for p in reversed(arrow)], -0.38, 0.42)
    stamp([(-0.54, 0.14), (-0.54, 0.20), (0.54, 0.20), (0.54, 0.14)][::-1], 0.0, 0.0, RED)
    # roof: the two long flaps leaning together, and the clothes peg holding them
    for s in (-1, 1):
        q = [(-W - 0.04, s * (Dp + 0.03), H - 0.02), (W + 0.04, s * (Dp + 0.03), H - 0.02),
             (W + 0.04, s * 0.012, MT_RIDGE), (-W - 0.04, s * 0.012, MT_RIDGE)]
        if s > 0:
            q = list(reversed(q))
        F = q
        b.face(q, KRAFT_L)
        nrm = (Vector(q[1]) - Vector(q[0])).cross(Vector(q[2]) - Vector(q[0])).normalized() * 0.03
        b.face([Vector(v) - nrm for v in reversed(q)], shade(KRAFT, 0.7))
        # the corrugated cut edge along the eave
        e0, e1 = Vector(q[0]), Vector(q[1])
        b.face([e1, e0, e0 - nrm, e1 - nrm], KRAFT, "PK_Corrugated")
    # a strip of masking tape along the ridge
    b.face([(-W - 0.02, -0.07, MT_RIDGE - 0.02), (W + 0.02, -0.07, MT_RIDGE - 0.02), (W + 0.02, 0.0, MT_RIDGE + 0.012), (-W - 0.02, 0.0, MT_RIDGE + 0.012)], lin("#d2bd8f"))
    b.face([(-W - 0.02, 0.0, MT_RIDGE + 0.012), (W + 0.02, 0.0, MT_RIDGE + 0.012), (W + 0.02, 0.07, MT_RIDGE - 0.02), (-W - 0.02, 0.07, MT_RIDGE - 0.02)], lin("#d2bd8f"))
    PG = Matrix.Translation((-0.35, 0, MT_RIDGE - 0.02))
    for s in (-1, 1):
        b.box((-0.025, s * 0.02 - 0.012, -0.10), (0.025, s * 0.02 + 0.012, 0.20), WOOD, shade(WOOD, 0.85), mat="PK_WoodVC",
              M=PG @ Matrix.Rotation(math.radians(-s * 8), 4, "X"))
    b.tube([(-0.028, 0, 0.05), (0.028, 0, 0.05)], 0.03, 8, STEEL, "PK_MetalVC", M=None) if False else \
        b.tube([PG @ Vector((-0.03, 0, 0.06)), PG @ Vector((0.03, 0, 0.06))], 0.034, 8, STEEL, "PK_MetalVC")
    # a card sign hung from the left eave on thread: a bowl of stew
    SX, SY, SZ = -0.40, -Dp - 0.12, H - 0.18
    for x in (SX - 0.1, SX + 0.1):
        b.tube([(x, -Dp - 0.06, H + 0.02), (x, SY, SZ + 0.12)], 0.005, 4, WHITE, caps=False)
    Fs = frame((SX, SY, SZ - 0.06), (1, 0, 0), (0, 0, 1))
    b.slab([(-0.14, -0.02), (0.14, -0.02), (0.14, 0.18), (-0.14, 0.18)], 0.012, CARD, shade(CARD, 0.85), M=Fs)
    Fi = Fs @ Matrix.Translation((0, 0.0, 0.013))
    b.slab([(-0.09, 0.07), (0.09, 0.07)] + [(0.09 * math.cos(-a), 0.07 + 0.07 * math.sin(-a)) for a in [math.pi * k / 6 for k in range(1, 6)]] + [(-0.09, 0.07)][:0],
           0.002, RED, M=Fi)
    for k, dx in enumerate((-0.04, 0.0, 0.04)):
        b.slab([(dx - 0.008, 0.09), (dx + 0.008, 0.09), (dx + 0.012 * (k - 1) + 0.008, 0.15), (dx + 0.012 * (k - 1) - 0.008, 0.15)], 0.002, INK, M=Fi)
    # the straw chimney, red and white
    cx, cy = 0.36, 0.26
    zr = H + (MT_RIDGE - H) * (1 - (cy) / (Dp + 0.03)) - 0.05
    b.tube([(cx, cy, zr - 0.05), (cx, cy, MT_RIDGE + 0.42)], 0.045, 10, WHITE,
           colf=None, caps=False)
    b.lathe([(0.0455, zr - 0.05 + 0.0), (0.0455, MT_RIDGE + 0.42)], 10, RED, M=Matrix.Translation((cx, cy, 0)),
            colf=lambda j, i, a: RED if (i % 5) in (0, 1) else WHITE)
    b.disc(0.045, MT_RIDGE + 0.42, 10, DARK, r_in=0.035, M=Matrix.Translation((cx, cy, 0)))
    # the cauldron: a crimped bottle cap on three matchsticks over a paper flame
    P0 = MT_POT
    crimps = 21
    rr = [MT_POT_S * (0.17 if k % 2 == 0 else 0.185) for k in range(crimps * 2)]
    ring_lo = [P0 + Vector((rr[k] * math.cos(math.pi * k / crimps), rr[k] * math.sin(math.pi * k / crimps), -0.12)) for k in range(crimps * 2)]
    ring_hi = [P0 + Vector((rr[k] * 1.04 * math.cos(math.pi * k / crimps), rr[k] * 1.04 * math.sin(math.pi * k / crimps), 0.0)) for k in range(crimps * 2)]
    for k in range(crimps * 2):
        k2 = (k + 1) % (crimps * 2)
        b.face([ring_lo[k], ring_lo[k2], ring_hi[k2], ring_hi[k]], CAP, "PK_MetalVC")
        inner = [ring_hi[k] - (ring_hi[k] - P0).normalized() * 0.01, ring_hi[k2] - (ring_hi[k2] - P0).normalized() * 0.01]
        b.face([ring_hi[k], ring_hi[k2], inner[1], inner[0]], CAP_IN, "PK_MetalVC")
    b.disc(0.175 * MT_POT_S, P0.z - 0.12, 24, CAP, "PK_MetalVC", up=False, M=Matrix.Translation((P0.x, P0.y, 0)))
    b.disc(0.168 * MT_POT_S, P0.z - 0.025, 24, STEW, M=Matrix.Translation((P0.x, P0.y, 0)))
    for k, (dx, dy, col) in enumerate([(0.08, 0.04, CARROT), (-0.07, 0.09, PEA), (-0.09, -0.06, CARROT), (0.04, -0.1, PEA), (0.0, 0.01, CARROT), (0.12, -0.05, PEA)]):
        b.crumple((P0.x + dx, P0.y + dy, P0.z - 0.02), 0.032, col, seed=40 + k, segs=5, rings=3)
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        foot = P0 + Vector((0.23 * math.cos(a), 0.23 * math.sin(a), -P0.z))
        top = P0 + Vector((0.14 * math.cos(a), 0.14 * math.sin(a), -0.12))
        b.tube([foot, top + (top - foot).normalized() * 0.04], 0.014, 5, MATCH, "PK_WoodVC")
        b.sphere(top + (top - foot).normalized() * 0.05, 0.022, 6, 4, HEAD, sz=1.4)
    for k, (s, col) in enumerate(((1.0, FLAME), (0.6, FLAME2))):
        fl = [(-0.09 * s, 0), (-0.06 * s, 0.10 * s), (-0.025 * s, 0.07 * s), (0, 0.16 * s), (0.03 * s, 0.08 * s), (0.065 * s, 0.11 * s), (0.09 * s, 0)]
        for ang in (0.0, 90.0):
            F = Matrix.Translation(P0 + Vector((0, 0, -P0.z + 0.005 + 0.004 * k))) @ Matrix.Rotation(math.radians(ang), 4, "Z") @ \
                frame((0, -0.003 * k, 0), (1, 0, 0), (0, 0, 1))
            b.slab(fl, 0.003, col, col, M=F)
    base = rest(b.build(c, at))

    # ---------------- Ladle: a teaspoon in the pot, pivot on the pot's axis ----------------
    l = Part("MessTent_Ladle")
    # bowl in the stew on the far side, the handle leaning out over the near rim
    stem = [(0.11, 0.0, -0.05), (0.0, 0.0, 0.02), (-0.15, 0.0, 0.12), (-0.30, 0.0, 0.24), (-0.36, 0.0, 0.29)]
    l.tube(stem, [0.016, 0.014, 0.014, 0.018, 0.022], 6, STEEL, "PK_MetalVC")
    l.sphere((0.14, 0.0, -0.06), 0.07, 10, 6, STEEL, "PK_MetalVC", sx=0.8, sz=0.35)
    ladle = rest(l.build(c, P0, base))

    # ---------------- Steam: three tissue puffs over the pot ----------------
    s = Part("MessTent_Steam")
    puffs = [(0.0, 0.0, 0.0, 0.05), (0.05, 0.02, 0.03, 0.04), (-0.04, -0.01, 0.02, 0.035),
             (0.06, 0.0, 0.21, 0.07), (0.12, 0.03, 0.24, 0.05), (0.0, -0.02, 0.25, 0.055),
             (-0.02, 0.0, 0.43, 0.09), (0.08, 0.02, 0.47, 0.07), (-0.11, -0.02, 0.46, 0.065), (0.02, 0.0, 0.53, 0.06)]
    for k, (dx, dy, dz, r) in enumerate(puffs):
        s.crumple((dx, dy, dz), r, (0.97, 0.97, 0.97, 0.0), seed=60 + k, segs=7, rings=4)
    steam = rest(s.build(c, P0 + Vector((0, 0, 0.12)), base))
    return {"MessTent_Base": base, "MessTent_Ladle": ladle, "MessTent_Steam": steam}


def anim_mess_tent():
    T = "mess_tent"
    CLIPS[T] = [("idle", 24, True), ("serve", 12, False)]
    track(T, "idle", "MessTent_Ladle", [(f, None, (0, 0, 360.0 * f / 24), None) for f in range(24)])
    # the puffs rise one spacing a loop and grow into the next one's size, so the loop is seamless
    track(T, "idle", "MessTent_Steam",
          [(f, (0, 0, 0.21 * (f % 12) / 12), (0, 0, 15 * f), tuple([1.0 + 0.3 * (f % 12) / 12] * 3)) for f in range(24)])
    track(T, "serve", "MessTent_Ladle", [
        (0, None, None, None), (1, (0, 0, 0.08), (-12, 0, 0), None), (2, (0, 0, 0.12), (-25, 0, 0), None),
        (3, (0, 0, 0.02), (8, 0, 0), None), (4, None, None, None)])
    track(T, "serve", "MessTent_Steam", [
        (0, None, None, None), (2, (0, 0, 0.05), None, (1.5, 1.5, 1.5)), (4, (0, 0, 0.15), None, (1.9, 1.9, 1.9)),
        (6, (0, 0, 0.25), None, (1.5, 1.5, 1.5)), (8, (0, 0, 0.1), None, (1.1, 1.1, 1.1)), (9, None, None, None)])
