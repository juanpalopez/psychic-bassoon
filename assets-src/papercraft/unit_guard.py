
# unit_guard.py - A guard of the Guard Tent: a paper-craft soldier in a tunic folded from the
# tent's striped paper, a folded-newspaper hat, a cardboard sword wrapped in foil and a
# bottle-cap shield. Parts: Body (legs, tunic, head, hat; pivot at the feet, so it can fall
# over and spring back), SwordArm and ShieldArm (pivots at the shoulders).
# Clips: idle (loop), strike (loop while a foe is held), fall, rise.

GD_SHOULDER = 0.50


def build_guard(c, at, name="Guard", facing=0.0):
    RED = lin("#c23b3b"); CREAM = lin("#f1e4c6"); TROUSER = lin("#4d3b2e"); BOOT = lin("#1f1a17")
    SKIN = lin("#f0c8a0"); CHEEK = lin("#e79a86"); INK = lin("#2a2420"); NEWS = lin("#e2dccb")
    PRINT = lin("#8e8a82"); BELT = lin("#6b4a2c"); BUCKLE = lin("#e2b23a"); FOIL = lin("#d7dbe0")
    CARD = lin("#a98b66"); CAP = lin("#2f63a8"); CAP_IN = lin("#f3f0e8"); PICK = lin("#f0dcae")

    b = Part(name + "_Body")
    # legs: folded card strips, boots folded forward
    for s in (-1, 1):
        b.box((s * 0.065 - 0.035, -0.03, 0.03), (s * 0.065 + 0.035, 0.03, 0.27), TROUSER)
        b.box((s * 0.065 - 0.04, -0.08, 0.0), (s * 0.065 + 0.04, 0.04, 0.045), BOOT)
    # the tunic: a six-sided fold in the tent's stripes, flared at the hem
    stripes = lambda j, i, a: (RED if i % 2 == 0 else CREAM) if j != 1 else BELT
    b.lathe([(0.17, 0.22), (0.15, 0.32), (0.145, 0.355), (0.12, 0.54), (0.06, 0.575), (0.0, 0.575)], 12, RED,
            a0=math.radians(-90), colf=stripes, smooth=False)
    b.lathe([(0.0, 0.22), (0.17, 0.22)], 12, shade(RED, 0.5), a0=math.radians(-90), smooth=False)
    b.box((-0.03, -0.155, 0.32), (0.03, -0.14, 0.355), BUCKLE)
    # head: an eight-sided paper cylinder with a drawn face
    b.lathe([(0.0, 0.56), (0.095, 0.57), (0.1, 0.62), (0.1, 0.70), (0.08, 0.74), (0.0, 0.745)], 8, SKIN,
            a0=math.radians(-90 + 22.5), smooth=False)
    for s in (-1, 1):
        b.box((s * 0.035 - 0.012, -0.104, 0.665), (s * 0.035 + 0.012, -0.096, 0.69), INK)
        b.disc(0.016, 0.0, 8, CHEEK, M=Matrix.Translation((s * 0.058, -0.097, 0.635)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    b.box((-0.025, -0.104, 0.625), (0.025, -0.096, 0.632), INK)
    # the folded newspaper hat across the head, front-to-back like a paper boat
    HZ = 0.70
    hat = [(-0.18, 0.0), (0.18, 0.0), (0.0, 0.16)]
    for y, col in ((-0.075, NEWS), (0.045, NEWS)):
        b.slab(hat, 0.03, col, shade(col, 0.85), M=frame((0, y, HZ), (1, 0, 0), (0, 0, 1)) @ Matrix.Translation((0, 0, 0)))
    b.box((-0.185, -0.085, HZ - 0.005), (0.185, 0.085, HZ + 0.04), NEWS, shade(NEWS, 0.8))
    for k in range(3):
        z = HZ + 0.055 + 0.024 * k
        w = 0.135 * (1 - (z - HZ) / 0.16)
        b.box((-w, -0.077, z), (w * (0.6 if k % 2 else 1.0), -0.075, z + 0.008), PRINT)
    b.sphere((0.0, -0.015, HZ + 0.17), 0.022, 6, 4, RED)
    body = b.build(c, at)
    body.rotation_euler = (0, 0, math.radians(facing))
    rest(body)

    # ---------------- SwordArm (the guard's right, -X) ----------------
    a = Part(name + "_SwordArm")
    a.box((-0.04, -0.035, -0.17), (0.035, 0.035, 0.02), RED, shade(RED, 0.8))
    a.box((-0.035, -0.04, -0.21), (0.03, 0.03, -0.17), SKIN)
    # the sword, held forward and a little up: card blade wrapped in foil, toothpick guard
    S = Matrix.Translation((0.0, -0.01, -0.19)) @ Matrix.Rotation(math.radians(120), 4, "X")
    blade = [(-0.022, 0.05), (0.022, 0.05), (0.022, 0.33), (0.0, 0.37), (-0.022, 0.33)]
    a.slab(blade, 0.012, FOIL, shade(FOIL, 0.8), "PK_MetalVC", M=S @ frame((0, 0, -0.006), (1, 0, 0), (0, 1, 0)))
    a.tube([S @ Vector((-0.06, 0.05, 0)), S @ Vector((0.06, 0.05, 0))], 0.011, 5, PICK, "PK_WoodVC")
    a.tube([S @ Vector((0, -0.04, 0)), S @ Vector((0, 0.05, 0))], 0.014, 5, BELT)
    a.sphere(S @ Vector((0, -0.05, 0)), 0.02, 6, 4, BUCKLE)
    sword = a.build(c, (-0.165, 0.0, GD_SHOULDER), body)
    rest(sword)

    # ---------------- ShieldArm (+X): a bottle-cap shield held in front ----------------
    h = Part(name + "_ShieldArm")
    h.box((-0.035, -0.035, -0.17), (0.04, 0.035, 0.02), RED, shade(RED, 0.8))
    h.box((-0.03, -0.04, -0.21), (0.035, 0.03, -0.17), SKIN)
    Fm = Matrix.Translation((0.03, -0.08, -0.14)) @ Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Rotation(math.radians(-15), 4, "Y")
    crimps = 18
    for k in range(crimps * 2):
        r0 = 0.13 if k % 2 == 0 else 0.14; r1 = 0.13 if (k + 1) % 2 == 0 else 0.14
        a0 = math.pi * k / crimps; a1 = math.pi * (k + 1) / crimps
        p0 = Vector((r0 * math.cos(a0), r0 * math.sin(a0), 0)); p1 = Vector((r1 * math.cos(a1), r1 * math.sin(a1), 0))
        h.face([Fm @ p0, Fm @ p1, Fm @ (p1 + Vector((0, 0, 0.04))), Fm @ (p0 + Vector((0, 0, 0.04)))], CAP, "PK_MetalVC")
    # the cap's face (the outside of the cap is the guard's front) with a cream star
    h.disc(0.135, 0.04, 18, CAP, "PK_MetalVC", up=True, M=Fm)
    h.disc(0.135, 0.0, 18, CAP_IN, "PK_MetalVC", up=False, M=Fm)
    h.slab([(p[0] * 0.75, p[1] * 0.75) for p in [(0.0, 0.1), (-0.03, 0.03), (-0.1, 0.03), (-0.045, -0.015), (-0.065, -0.085), (0.0, -0.04),
                                                  (0.065, -0.085), (0.045, -0.015), (0.1, 0.03), (0.03, 0.03)]],
           0.003, CAP_IN, M=Fm @ Matrix.Translation((0, 0, 0.041)))
    shield = h.build(c, (0.165, 0.0, GD_SHOULDER), body)
    rest(shield)
    return {name + "_Body": body, name + "_SwordArm": sword, name + "_ShieldArm": shield}


def anim_guard(name="Guard", key="guard"):
    B, S, H = name + "_Body", name + "_SwordArm", name + "_ShieldArm"
    CLIPS[key] = [("idle", 24, True), ("strike", 8, True), ("fall", 12, False), ("rise", 8, False)]
    track(key, "idle", B, [(f, (0, 0, 0.012 * abs(math.sin(math.tau * f / 24))), (0, 2.5 * math.sin(math.tau * f / 24), 0), None) for f in range(24)])
    track(key, "idle", S, [(f, None, (6 * math.sin(math.tau * f / 24 + 1), 0, 0), None) for f in range(24)])
    track(key, "idle", H, [(f, None, (-4 * math.sin(math.tau * f / 24), 0, 0), None) for f in range(24)])
    sk = [(0, None, None, None), (1, None, (-55, 0, 0), None), (2, None, (-80, 0, -10), None), (3, None, (45, 0, 10), None),
          (4, None, (35, 0, 6), None), (6, None, (10, 0, 0), None), (7, None, None, None)]
    bk = [(0, None, None, None), (2, (0, 0.02, 0), (-4, 0, 0), None), (3, (0, -0.07, 0), (10, 0, 0), None),
          (4, (0, -0.05, 0), (7, 0, 0), None), (6, (0, -0.01, 0), (2, 0, 0), None), (7, None, None, None)]
    hk = [(0, None, None, None), (2, None, (-10, 0, 0), None), (3, None, (14, 0, 0), None), (6, None, None, None)]
    track(key, "strike", S, sk); track(key, "strike", B, bk); track(key, "strike", H, hk)
    # fall: knocked flat on its back like a cut-out, a little bounce, arms flung out
    track(key, "fall", B, [(0, None, None, None), (1, (0, 0.03, 0.02), (-25, 0, 0), None), (2, (0, 0.06, 0.0), (-60, 0, 0), None),
                           (3, (0, 0.08, 0.0), (-88, 0, 0), None), (4, (0, 0.08, 0.03), (-80, 0, 0), None),
                           (5, (0, 0.08, 0.0), (-89, 0, 0), None), (11, (0, 0.08, 0.0), (-89, 0, 0), None)])
    track(key, "fall", S, [(0, None, None, None), (2, None, (-40, 0, -30), None), (4, None, (-70, 0, -60), None), (11, None, (-70, 0, -60), None)])
    track(key, "fall", H, [(0, None, None, None), (2, None, (-30, 0, 30), None), (4, None, (-60, 0, 50), None), (11, None, (-60, 0, 50), None)])
    # rise: springs back up from flat, overshoots, settles with a squash
    track(key, "rise", B, [(0, (0, 0.08, 0.0), (-89, 0, 0), None), (1, (0, 0.06, 0.0), (-60, 0, 0), None), (2, (0, 0.02, 0.03), (-15, 0, 0), None),
                           (3, (0, 0.0, 0.06), (8, 0, 0), (0.95, 0.95, 1.08)), (4, None, (-3, 0, 0), (1.06, 1.06, 0.9)), (6, None, None, None)])
    track(key, "rise", S, [(0, None, (-70, 0, -60), None), (2, None, (-30, 0, -20), None), (4, None, (-60, 0, 0), None), (6, None, None, None)])
    track(key, "rise", H, [(0, None, (-60, 0, 50), None), (2, None, (-20, 0, 20), None), (4, None, None, None)])
