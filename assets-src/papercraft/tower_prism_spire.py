
# tower_prism_spire.py - The Prism Spire: a tube of rolled blue construction paper with a
# cut, flared crown, yellow paper bands and cut-out stars, on a folded hexagonal card plinth.
# Three bent paper-clip prongs hold a glass cat's-eye marble that channels the light.
# Parts: Base (plinth, tube, crown), Head (the paper-clip claw; turns slowly) and Marble
# (glass shell with a glowing vane; bobs, spins and pulses when it fires).

PS_TOP = 1.95       # top of the tube
PS_MARBLE = 2.40    # marble centre


def rolled_tube(p, z0, z1, r0, r1, col, edge, turns=1.06, segs=24, rows=4, grow=0.012):
    """A sheet rolled into a tube: the radius grows a little each turn so the outer edge
    overlaps, leaving a real seam; both sides drawn (the inside darker)."""
    n = int(segs * turns)
    def P(i, k, inner=False):
        a = math.tau * i / segs
        z = z0 + (z1 - z0) * k / rows
        r = (r0 + (r1 - r0) * k / rows) * (1.0 + grow * i / segs) - (0.004 if inner else 0.0)
        return Vector((r * math.cos(a - math.pi / 2), r * math.sin(a - math.pi / 2), z))
    for k in range(rows):
        for i in range(n):
            q = [P(i, k), P(i + 1, k), P(i + 1, k + 1), P(i, k + 1)]
            p.face(q, col, smooth=True)
            qi = [P(i + 1, k, True), P(i, k, True), P(i, k + 1, True), P(i + 1, k + 1, True)]
            p.face(qi, shade(col, 0.55), smooth=True)
    # the cut edge of the outer turn, and the top rim
    for k in range(rows):
        p.face([P(n, k, True), P(n, k), P(n, k + 1), P(n, k + 1, True)], edge)
    for i in range(n):
        p.face([P(i, rows), P(i + 1, rows), P(i + 1, rows, True), P(i, rows, True)], edge)


def star(r_out, r_in, n=5):
    pts = []
    for k in range(2 * n):
        r = r_out if k % 2 == 0 else r_in
        a = math.pi / 2 + math.pi * k / n
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def build_prism_spire(c, at):
    BLUE = lin("#2f55b0"); BLUE_E = lin("#7f97d6"); GOLD = lin("#e8b53c"); GOLD_E = lin("#f5d58a")
    CARD = lin("#f1e6cc"); CARD_D = lin("#d9c9a6"); WHITE = lin("#f7f3ea"); DARK = lin("#16203c")
    WIRE = lin("#d8dce2"); GLOW1 = lin("#5fe3ff", 1.6); GLOW2 = lin("#ff8adb", 1.4)

    b = Part("PrismSpire_Base")
    # folded hexagonal card plinth: alternate facets lighter/darker like creased card
    hexa = [(0.62, 0.0), (0.62, 0.13), (0.52, 0.17), (0.40, 0.17)]
    b.lathe([(0.0, 0.0), (0.62, 0.0)], 6, CARD_D, a0=math.radians(30), smooth=False)
    b.lathe(hexa, 6, CARD, a0=math.radians(30), smooth=False,
            colf=lambda j, i, a: (CARD if i % 2 else CARD_D) if j < 2 else CARD)
    # the rolled tube, a little narrower at the top
    rolled_tube(b, 0.15, PS_TOP, 0.37, 0.31, BLUE, BLUE_E)
    # yellow paper bands, each with its own seam
    for (z, hgt, r) in ((0.32, 0.12, 0.372), (1.36, 0.10, 0.335), (1.80, 0.08, 0.322)):
        rolled_tube(b, z, z + hgt, r + 0.006, r + 0.004, GOLD, GOLD_E, turns=1.04, segs=24, rows=1, grow=0.008)
    # the crown: the top of the roll cut into points, folded outward
    pts = 10
    for k in range(pts):
        a0 = math.tau * k / pts; a1 = math.tau * (k + 1) / pts; am = (a0 + a1) / 2
        r = 0.318
        base0 = Vector((r * math.cos(a0), r * math.sin(a0), PS_TOP - 0.01))
        base1 = Vector((r * math.cos(a1), r * math.sin(a1), PS_TOP - 0.01))
        tip = Vector(((r + 0.07) * math.cos(am), (r + 0.07) * math.sin(am), PS_TOP + 0.17))
        b.face([base0, base1, tip], GOLD if k % 2 else BLUE)
        b.face([base1, base0, tip], shade(GOLD if k % 2 else BLUE, 0.6))
    # an arched window slit and cut-out stars
    def on_tube(ang, z, r):
        n = Vector((math.cos(ang), math.sin(ang), 0))
        return frame(n * r + Vector((0, 0, z)), (-math.sin(ang), math.cos(ang), 0), (0, 0, 1))
    slit = [(-0.05, -0.12), (0.05, -0.12), (0.05, 0.06)] + \
           [(0.05 * math.cos(math.pi * k / 6), 0.06 + 0.05 * math.sin(math.pi * k / 6)) for k in range(1, 6)] + [(-0.05, 0.06)]
    b.slab(slit, 0.004, DARK, DARK, M=on_tube(-math.pi / 2, 1.08, 0.343))
    for (ang, z, s) in ((-1.25, 0.72, 0.075), (-2.2, 1.0, 0.06), (-0.55, 1.12, 0.055), (2.6, 0.8, 0.07), (0.9, 0.6, 0.06)):
        r = 0.37 - 0.06 * (z - 0.15) / (PS_TOP - 0.15)
        b.slab(star(s, s * 0.45), 0.004, WHITE, CARD, M=on_tube(ang, z, r + 0.002))
    base = rest(b.build(c, at))

    # ---------------- Head: the paper-clip claw ----------------
    h = Part("PrismSpire_Head")
    h.lathe([(0.20, 0.0), (0.26, 0.0), (0.26, 0.04), (0.20, 0.04), (0.20, 0.0)], 18, GOLD, smooth=False)
    MZ = PS_MARBLE - PS_TOP
    for k in range(3):
        a = math.tau * k / 3 + 0.3
        pts = []
        # up from the collar, bowing out round the marble, curling in over its top
        for s in range(13):
            t = s / 12.0
            ang = math.radians(-80 + 150 * t)          # around the marble centre
            rad = 0.28 * math.cos(ang)
            z = MZ + 0.28 * math.sin(ang)
            if t < 0.25:                                 # the stem from the collar
                u = t / 0.25
                rad = 0.24 * (1 - u) + rad * u
                z = 0.03 * (1 - u) + z * u
            pts.append((rad * math.cos(a), rad * math.sin(a), z))
        h.tube(pts, 0.016, 5, WIRE, "PK_MetalVC")
        h.sphere(pts[-1], 0.022, 6, 4, WIRE, "PK_MetalVC")
    head = rest(h.build(c, (0, 0, PS_TOP), base))

    # ---------------- Marble ----------------
    m = Part("PrismSpire_Marble")
    m.sphere((0, 0, 0), 0.25, 14, 8, (1, 1, 1, 0), "PK_Glass")
    # the cat's-eye vane: a twisted ribbon through the middle, glowing
    rows = 6
    for k in range(rows):
        t0 = k / rows; t1 = (k + 1) / rows
        def V(t, side):
            z = -0.19 + 0.38 * t
            w = math.sqrt(max(0.0, 0.22 ** 2 - z * z)) * side
            tw = 1.6 * t
            return Vector((w * math.cos(tw), w * math.sin(tw), z))
        q = [V(t0, -1), V(t0, 1), V(t1, 1), V(t1, -1)]
        m.face(q, GLOW1 if k % 2 == 0 else mixc(GLOW1, GLOW2, 0.5))
        m.face(list(reversed(q)), GLOW2)
    marble = m.build(c, (0, 0, PS_MARBLE - PS_TOP), head)
    rest(marble)
    return {"PrismSpire_Base": base, "PrismSpire_Head": head, "PrismSpire_Marble": marble}


def anim_prism_spire():
    T = "prism_spire"
    CLIPS[T] = [("idle", 24, True), ("fire", 12, False)]
    track(T, "idle", "PrismSpire_Head", [(f, None, (0, 0, 360.0 * f / 48), None) for f in range(24)])
    track(T, "idle", "PrismSpire_Marble",
          [(f, (0, 0, 0.035 * math.sin(math.tau * f / 24)), (0, 0, -360.0 * f / 24), None) for f in range(24)])
    track(T, "fire", "PrismSpire_Marble", [
        (0, None, None, None), (1, (0, 0, 0.06), (0, 0, 45), (1.32, 1.32, 1.32)),
        (2, (0, 0, 0.08), (0, 0, 90), (1.22, 1.22, 1.22)), (3, (0, 0, 0.07), (0, 0, 130), (1.12, 1.12, 1.12)),
        (5, (0, 0, 0.04), (0, 0, 165), (1.04, 1.04, 1.04)), (8, None, (0, 0, 180), None)])
    track(T, "fire", "PrismSpire_Head", [(0, None, None, None), (1, None, (0, 0, -8), None), (3, None, None, None)])
