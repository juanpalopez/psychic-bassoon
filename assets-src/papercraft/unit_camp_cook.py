
# unit_camp_cook.py - The Camp Cook: a round chef folded from ruled recipe paper, in a
# gingham apron and a pleated paper toque, with a crinkled tin-foil ladle and a bottle-cap
# bowl of stew. Parts: Body (legs, recipe-paper body, apron, head, toque; pivot at the feet),
# LadleArm (his right, -X) and BowlArm (his left). Clips: idle (stirs his bowl), walk
# (a waddle), attack (a ladle bonk, looped), splash (Boiling Stew Splash), fall, rise.

CK_SHOULDER = 0.56


def build_camp_cook(c, at, name="CampCook", facing=0.0):
    PAPER = lin("#f5eedb"); RULE = lin("#7fa6d6"); MARGIN = lin("#e06a6a"); SHOE = lin("#2a221d"); TROUSER = lin("#3f4652")
    SKIN = lin("#f2c7a0"); CHEEK = lin("#ea9481"); INK = lin("#2a2420"); TASH = lin("#5a3a24")
    WHITE = lin("#fbfaf6"); PLEAT = lin("#ecebe5"); GING_R = lin("#d0473f"); GING_W = lin("#f6efe6")
    FOIL = lin("#dfe3e8"); CAP = lin("#c63a33"); STEW = lin("#7a4424"); CARROT = lin("#e8822e"); SCARF = lin("#d0473f")

    b = Part(name + "_Body")
    for s in (-1, 1):
        b.lathe([(0.0, 0.0), (0.06, 0.0), (0.06, 0.2), (0.0, 0.2)], 8, TROUSER, M=Matrix.Translation((s * 0.085, 0, 0)), smooth=False)
        b.sphere((s * 0.085, -0.04, 0.03), 0.065, 8, 4, SHOE, sy=1.5, sz=0.55)
    # the round body, folded from ruled recipe paper: blue rules, one red margin line
    prof = [(0.0, 0.17), (0.17, 0.18), (0.25, 0.25), (0.285, 0.33), (0.285, 0.43), (0.25, 0.52), (0.17, 0.585), (0.0, 0.60)]
    # split the outline so thin ruled lines run round it every few centimetres
    def r_at(z):
        for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
            if z0 <= z <= z1 and z1 > z0:
                return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        return 0.0
    zs = sorted(set([p[1] for p in prof] + [z + d for z in (0.27, 0.31, 0.35, 0.39, 0.43, 0.47, 0.51) for d in (0.0, 0.008)]))
    ruled = [(r_at(z), z) for z in zs]
    ruled[0] = (0.0, 0.17); ruled[-1] = (0.0, 0.60)
    lines = set(k for k, z in enumerate(zs[:-1]) if any(abs(z - l) < 1e-6 for l in (0.27, 0.31, 0.35, 0.39, 0.43, 0.47, 0.51)))
    def recipe(j, i, a):
        if i == 3:
            return MARGIN
        return RULE if j in lines else PAPER
    b.lathe(ruled, 10, PAPER, a0=math.radians(-90 + 18), colf=recipe, smooth=False)
    # gingham apron over the front, with a pocket
    rows, cols = 5, 4
    for r in range(rows):
        for k in range(cols):
            z0 = 0.22 + 0.06 * r; z1 = z0 + 0.06
            x0 = -0.16 + 0.08 * k; x1 = x0 + 0.08
            def y_at(x, z):
                rr = 0.285 if 0.33 <= z <= 0.43 else (0.25 + 0.035 * (1 - abs(z - 0.38) / 0.16))
                return -math.sqrt(max(rr * rr - x * x, 0.0)) - 0.012
            col = GING_R if (r + k) % 2 == 0 else GING_W
            b.face([(x0, y_at(x0, z0), z0), (x1, y_at(x1, z0), z0), (x1, y_at(x1, z1), z1), (x0, y_at(x0, z1), z1)], col)
    b.face([(-0.07, -0.30, 0.27), (0.07, -0.30, 0.27), (0.07, -0.30, 0.34), (-0.07, -0.30, 0.34)], WHITE)
    # a red neckerchief
    b.face([(-0.12, -0.16, 0.585), (0.12, -0.16, 0.585), (0.0, -0.21, 0.50)], SCARF)
    b.lathe([(0.16, 0.57), (0.14, 0.61), (0.0, 0.61)], 10, SCARF, smooth=False)
    # head: rosy cheeks, two dot eyes and a big curled moustache
    b.lathe([(0.0, 0.59), (0.10, 0.60), (0.125, 0.66), (0.125, 0.74), (0.10, 0.79), (0.0, 0.80)], 10, SKIN,
            a0=math.radians(-90 + 18), smooth=False)
    for s in (-1, 1):
        b.box((s * 0.042 - 0.012, -0.128, 0.715), (s * 0.042 + 0.012, -0.118, 0.742), INK)
        b.disc(0.022, 0.0, 8, CHEEK, M=Matrix.Translation((s * 0.075, -0.115, 0.675)) @ Matrix.Rotation(math.radians(90), 4, "X"))
        tash = [(0.0, 0.0), (0.06, -0.012), (0.10, 0.0), (0.115, 0.03), (0.095, 0.016), (0.05, 0.012), (0.0, 0.02)]
        b.slab([(s * x, y) for x, y in (tash if s > 0 else list(reversed(tash)))], 0.01, TASH,
               M=frame((0, -0.128, 0.675), (1, 0, 0), (0, 0, 1)) @ Matrix.Translation((0, 0, -0.005)))
    b.sphere((0.0, -0.135, 0.70), 0.026, 6, 4, CHEEK)
    # the pleated toque and its puff
    b.lathe([(0.115, 0.775), (0.13, 0.95)], 16, WHITE, colf=lambda j, i, a: PLEAT if i % 2 else WHITE, smooth=False)
    b.lathe([(0.12, 0.775), (0.12, 0.81)], 16, WHITE, smooth=False, M=Matrix.Scale(1.04, 4))
    b.crumple((0.0, 0.0, 1.0), 0.17, WHITE, seed=91, segs=9, rings=5)
    body = b.build(c, at)
    body.rotation_euler = (0, 0, math.radians(facing))
    rest(body)

    # ---------------- LadleArm: the tin-foil ladle (his right, -X) ----------------
    a = Part(name + "_LadleArm")
    a.tube([(0, 0, 0.0), (-0.03, -0.02, -0.12), (-0.03, -0.06, -0.2)], [0.055, 0.05, 0.045], 8, PAPER, smooth=False)
    a.sphere((-0.03, -0.08, -0.23), 0.045, 8, 5, SKIN)
    # crinkled foil: a handle and a deep bowl, faceted
    hand = Vector((-0.03, -0.09, -0.23))
    tip = hand + Vector((0.0, -0.16, 0.36))
    a.tube([hand + Vector((0, 0.05, -0.08)), hand, hand.lerp(tip, 0.5) + Vector((0.01, 0, 0)), tip], 0.016, 5, FOIL, "PK_MetalVC", smooth=False)
    bowl = tip + Vector((0.0, -0.05, -0.02))
    a.crumple(bowl, 0.075, FOIL, seed=93, segs=8, rings=4, mat="PK_MetalVC")
    ladle = a.build(c, (-0.27, 0.0, CK_SHOULDER), body)
    rest(ladle)

    # ---------------- BowlArm: a bottle-cap bowl of stew (his left) ----------------
    w = Part(name + "_BowlArm")
    w.tube([(0, 0, 0.0), (0.03, -0.04, -0.1), (0.02, -0.12, -0.16)], [0.055, 0.05, 0.045], 8, PAPER, smooth=False)
    w.sphere((0.02, -0.14, -0.17), 0.045, 8, 5, SKIN)
    P0 = Vector((0.02, -0.17, -0.11))
    w.lathe([(0.0, -0.06), (0.09, -0.06), (0.105, 0.0), (0.095, 0.0), (0.085, -0.045), (0.0, -0.045)], 14, CAP, "PK_MetalVC",
            M=Matrix.Translation(P0), smooth=False,
            colf=lambda j, i, aa: lin("#d8dade") if j >= 3 else CAP)
    w.disc(0.086, -0.012, 12, STEW, M=Matrix.Translation(P0))
    w.crumple(P0 + Vector((0.03, 0.01, -0.005)), 0.02, CARROT, seed=95, segs=5, rings=3)
    bowlarm = w.build(c, (0.27, 0.0, CK_SHOULDER), body)
    rest(bowlarm)
    return {name + "_Body": body, name + "_LadleArm": ladle, name + "_BowlArm": bowlarm}


def anim_camp_cook(name="CampCook", key="camp_cook"):
    B, L, W = name + "_Body", name + "_LadleArm", name + "_BowlArm"
    CLIPS[key] = [("idle", 24, True), ("walk", 12, True), ("walk2", 12, True), ("attack", 8, True), ("splash", 12, False),
                  ("fall", 12, False), ("rise", 8, False)]
    # idle: stirs the bowl with little circles of the ladle, a contented sway
    track(key, "idle", L, [(f, None, (25 + 10 * math.cos(math.tau * f / 8), 0, 30 + 12 * math.sin(math.tau * f / 8)), None) for f in range(24)])
    track(key, "idle", W, [(f, None, (8, 0, -12), None) for f in range(1)])
    track(key, "idle", B, [(f, None, (0, 3 * math.sin(math.tau * f / 24), 0), (1, 1, 1 + 0.015 * math.sin(math.tau * f / 12))) for f in range(24)])
    # walk: a waddle - rocks side to side and hops a little each step
    wk = []
    for f in range(12):
        ph = math.tau * f / 12
        wk.append((f, (0, 0, 0.03 * abs(math.sin(ph))), (0, 8 * math.sin(ph), 4 * math.sin(ph)), None))
    for clip in ("walk", "walk2"):
        track(key, clip, B, wk)
        track(key, clip, L, [(f, None, (-25 * math.sin(math.tau * f / 12), 0, 0), None) for f in range(12)])
        track(key, clip, W, [(f, None, (25 * math.sin(math.tau * f / 12), 0, 0), None) for f in range(12)])
    # attack: a ladle bonk over the head
    track(key, "attack", L, [(0, None, None, None), (1, None, (-70, 0, 10), None), (2, None, (-120, 0, 15), None),
                             (3, None, (40, 0, 0), None), (4, None, (30, 0, 0), None), (6, None, (5, 0, 0), None), (7, None, None, None)])
    track(key, "attack", B, [(0, None, None, None), (2, (0, 0.02, 0), (-5, 0, 0), None), (3, (0, -0.05, 0), (9, 0, 0), (1.05, 1.05, 0.95)),
                             (5, None, (3, 0, 0), None), (7, None, None, None)])
    track(key, "attack", W, [(0, None, None, None)])
    # splash: scoops from the bowl, winds up and flings the stew forward
    track(key, "splash", L, [(0, None, None, None), (1, None, (20, 0, 50), None), (2, None, (35, 0, 70), None),
                             (4, None, (-130, 0, 10), None), (5, None, (-150, 0, 5), None), (6, None, (60, 0, -5), None),
                             (7, None, (75, 0, -5), None), (9, None, (30, 0, 0), None), (11, None, None, None)])
    track(key, "splash", W, [(0, None, None, None), (1, None, (-20, 0, -30), None), (3, None, (-10, 0, -15), None), (6, None, None, None)])
    track(key, "splash", B, [(0, None, None, None), (3, (0, 0.04, 0), (-8, 0, 12), None), (5, (0, 0.05, 0.02), (-12, 0, 15), None),
                             (6, (0, -0.06, 0), (12, 0, -10), (1.06, 1.06, 0.93)), (8, (0, -0.03, 0), (5, 0, -4), None), (11, None, None, None)])
    # fall and rise, like the guards: flat on his back, then bounces up
    track(key, "fall", B, [(0, None, None, None), (1, (0, 0.03, 0.02), (-20, 0, 0), None), (2, (0, 0.08, 0.0), (-55, 0, 0), None),
                           (3, (0, 0.12, 0.0), (-86, 0, 0), None), (4, (0, 0.12, 0.04), (-76, 0, 0), None), (5, (0, 0.12, 0.0), (-88, 0, 0), None),
                           (11, (0, 0.12, 0.0), (-88, 0, 0), None)])
    track(key, "fall", L, [(0, None, None, None), (2, None, (-60, 0, 40), None), (4, None, (-90, 0, 70), None), (11, None, (-90, 0, 70), None)])
    track(key, "fall", W, [(0, None, None, None), (2, None, (-60, 0, -40), None), (4, None, (-90, 0, -70), None), (11, None, (-90, 0, -70), None)])
    track(key, "rise", B, [(0, (0, 0.12, 0.0), (-88, 0, 0), None), (1, (0, 0.09, 0.0), (-55, 0, 0), None), (2, (0, 0.03, 0.04), (-12, 0, 0), None),
                           (3, (0, 0.0, 0.07), (7, 0, 0), (0.95, 0.95, 1.08)), (4, None, (-2, 0, 0), (1.07, 1.07, 0.9)), (6, None, None, None)])
    track(key, "rise", L, [(0, None, (-90, 0, 70), None), (2, None, (-40, 0, 30), None), (4, None, None, None)])
    track(key, "rise", W, [(0, None, (-90, 0, -70), None), (2, None, (-40, 0, -30), None), (4, None, None, None)])
